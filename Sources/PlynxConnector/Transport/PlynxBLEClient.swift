//
//  PlynxBLEClient.swift
//  PlynxConnector
//
//  Direct BLE connection to a Plynx board (no WiFi, no server). The phone is the
//  CoreBluetooth central and plays the "app" role of the Plynx protocol:
//  it opens the connection, sends LOGIN with the 32-char auth token, then reads
//  and writes virtual pins directly over the GATT characteristics.
//
//  Wire contract (from the Plynx Arduino library, PlynxSimpleEsp32_BLE.h):
//   - Service   713D0000-503E-4C75-BA94-3148F18D941E  (advertised, name "Plynx")
//   - RX (write, phone -> device)   713D0003-503E-4C75-BA94-3148F18D941E
//   - TX (notify, device -> phone)  713D0002-503E-4C75-BA94-3148F18D941E
//   - Frames use the HARDWARE 5-byte header (see HardwareMessageParser).
//   - On connect the device is silent; the phone sends LOGIN(2) first.
//   - The device sends PING(6) when idle; the phone must answer RESPONSE(200).
//
//  This runs entirely on its own serial queue; all state is touched only there.
//  Beta: needs testing on real hardware.
//

#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth

// MARK: - Public types

public struct BLEDiscoveredDevice: Identifiable, Sendable, Hashable {
    public let id: UUID          // CBPeripheral.identifier
    public let name: String
    public let rssi: Int
}

public enum BLEClientState: Sendable, Equatable {
    case poweredOff
    case unauthorized
    case unsupported
    case idle            // powered on, not doing anything
    case scanning
    case connecting
    case authenticating  // connected, login sent, waiting for the device
    case connected       // logged in, pins flowing
    case disconnected
    case failed(String)
}

public enum BLEClientEvent: Sendable {
    case stateChanged(BLEClientState)
    case discovered([BLEDiscoveredDevice])
    case loginResult(success: Bool)
    /// A pin update pushed by the device: command is "vw"/"aw"/"dw", then pin and value(s).
    case pinUpdate(command: String, pin: Int, values: [String])
}

// MARK: - Client

public final class PlynxBLEClient: NSObject, @unchecked Sendable {

    public static let serviceUUID = CBUUID(string: "713D0000-503E-4C75-BA94-3148F18D941E")
    public static let rxUUID = CBUUID(string: "713D0003-503E-4C75-BA94-3148F18D941E") // write
    public static let txUUID = CBUUID(string: "713D0002-503E-4C75-BA94-3148F18D941E") // notify

    /// Stream of client events (state, discovered devices, login result, pin updates).
    public let events: AsyncStream<BLEClientEvent>
    private var continuation: AsyncStream<BLEClientEvent>.Continuation?

    private let queue = DispatchQueue(label: "cc.plynx.ble", qos: .userInitiated)
    private var central: CBCentralManager!

    private var peripheral: CBPeripheral?
    private var rxChar: CBCharacteristic?
    private var txChar: CBCharacteristic?

    private let parser = HardwareMessageParser()
    private var msgIdCounter: UInt16 = 0
    private var loginMsgId: UInt16 = 0
    private var pendingToken: String?
    private var loggedIn = false

    private var discovered: [UUID: BLEDiscoveredDevice] = [:]

    // Outbound write queue (chunked to the negotiated MTU).
    private var outbound: [Data] = []
    private var awaitingWriteResponse = false

    /// The caller asked to scan; retried automatically once the central powers on.
    private var wantsScan = false

    /// The caller asked to connect before the central was ready; replayed once
    /// it powers on (see `connect(deviceId:token:)`).
    private var pendingConnect: (deviceId: UUID, token: String)?

    /// Stable reason strings carried inside `.failed`. They are shown to the
    /// user (BLEConnectSheet, AddBoardFlowView) AND compared against by the
    /// App Intents layer to tell "iOS no longer knows this peripheral" from
    /// "the board did not answer" — two different problems with two different
    /// things for the user to do. Compare with these constants, never with a
    /// literal typed by hand.
    public static let peripheralUnknownMessage = "Device not found. Scan again."
    public static let connectionTimedOutMessage = "Bluetooth connection timed out"

    /// Must a connect request wait for the central to power on?
    ///
    /// Pure on purpose: `CBCentralManager` cannot be instantiated in a unit
    /// test, but THIS is the rule that broke — any state other than
    /// `.poweredOn` makes `retrievePeripherals` answer with an empty array,
    /// and a perfectly good board comes back as "device not found".
    public static func shouldDeferConnect(centralState: CBManagerState) -> Bool {
        centralState != .poweredOn
    }

    /// Bumped on every connect/disconnect so a stale connect-timeout closure
    /// (CoreBluetooth has no built-in connect timeout) knows it's superseded.
    private var connectGeneration = 0
    /// How long to wait for LOGIN to complete before failing a connect cleanly.
    private let connectTimeout: TimeInterval = 12

    public override init() {
        var cont: AsyncStream<BLEClientEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { cont = $0 }
        super.init()
        continuation = cont
        central = CBCentralManager(delegate: self, queue: queue)
    }

    // MARK: - Public API (all thread-safe via the serial queue)

    public func startScan() {
        queue.async { [weak self] in
            guard let self else { return }
            self.wantsScan = true
            self.discovered.removeAll()
            self.tryStartScan()
        }
    }

    public func stopScan() {
        queue.async { [weak self] in
            guard let self else { return }
            self.wantsScan = false
            if self.central.isScanning { self.central.stopScan() }
        }
    }

    /// Connect to a known peripheral (by identifier) and log in with its auth
    /// token. Works after relaunch without a rescan via retrievePeripherals.
    ///
    /// ⚠️ If the central is not `.poweredOn` yet the request is PARKED and
    /// replayed from `centralManagerDidUpdateState`, exactly like `wantsScan`
    /// does for scanning. Without this, a connect issued in the same instant
    /// the client is created — which is what happens in a process the system
    /// just launched to run an App Intent — reaches `retrievePeripherals`
    /// before CoreBluetooth is ready, gets an empty array back and fails with
    /// "device not found" on a board that is perfectly fine. It would then
    /// work on the second try: the classic signature of that race.
    public func connect(deviceId: UUID, token: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.wantsScan = false
            guard !Self.shouldDeferConnect(centralState: self.central.state) else {
                self.pendingConnect = (deviceId: deviceId, token: token)
                // Il tentativo è cominciato davvero: chi aspetta deve poterlo
                // distinguere dallo stato di partenza.
                self.emit(.stateChanged(.connecting))
                return
            }
            self.performConnect(deviceId: deviceId, token: token)
        }
    }

    /// Il vero connect: si chiama SOLO col central `.poweredOn` e già sulla
    /// coda del client.
    private func performConnect(deviceId: UUID, token: String) {
        if self.central.isScanning { self.central.stopScan() }
        // Chiudi un'eventuale connessione precedente a un peripheral diverso:
        // altrimenti resterebbe viva e sporcherebbe il parser condiviso.
        if let old = self.peripheral, old.identifier != deviceId {
            self.central.cancelPeripheralConnection(old)
            self.rxChar = nil
            self.txChar = nil
        }
        self.pendingToken = token
        self.loggedIn = false
        let known = self.central.retrievePeripherals(withIdentifiers: [deviceId])
        guard let target = known.first else {
            self.emit(.stateChanged(.failed(Self.peripheralUnknownMessage)))
            return
        }
        self.peripheral = target
        target.delegate = self
        self.emit(.stateChanged(.connecting))
        self.central.connect(target, options: nil)

        // CoreBluetooth non ha un timeout di connessione: se il device è
        // spento o fuori portata resterebbe "connecting" per sempre e (lato
        // app) bloccherebbe le scritture su una rotta morta. Diamo un limite
        // e poi falliamo pulito, così la UI lo mostra e i widget tornano a
        // passare dal server.
        self.connectGeneration &+= 1
        let generation = self.connectGeneration
        self.queue.asyncAfter(deadline: .now() + self.connectTimeout) { [weak self] in
            guard let self, self.connectGeneration == generation, !self.loggedIn else { return }
            self.central.cancelPeripheralConnection(target)
            self.peripheral = nil
            self.rxChar = nil
            self.txChar = nil
            self.emit(.stateChanged(.failed(Self.connectionTimedOutMessage)))
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.connectGeneration &+= 1   // invalida un eventuale timeout pendente
            self.pendingConnect = nil      // e una richiesta ancora parcheggiata
            self.parser.reset()
            self.outbound.removeAll()
            self.loggedIn = false
            if let p = self.peripheral {
                self.central.cancelPeripheralConnection(p)
            }
        }
    }

    public func writeVirtualPin(_ pin: Int, value: String) {
        sendHardware(["vw", String(pin), value])
    }

    public func writeDigitalPin(_ pin: Int, value: String) {
        sendHardware(["dw", String(pin), value])
    }

    public func writeAnalogPin(_ pin: Int, value: String) {
        sendHardware(["aw", String(pin), value])
    }

    /// Ask the device to report a virtual pin (it answers with a "vw" push).
    public func syncVirtualPin(_ pin: Int) {
        sendHardware(["vr", String(pin)])
    }

    // MARK: - Internal helpers (queue-isolated)

    private func tryStartScan() {
        guard wantsScan else { return }
        guard central.state == .poweredOn else {
            // Not ready yet: report the state, retry when the central powers on.
            emit(.stateChanged(mapState(central.state)))
            return
        }
        emit(.stateChanged(.scanning))
        central.scanForPeripherals(withServices: [Self.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func sendHardware(_ parts: [String]) {
        queue.async { [weak self] in
            guard let self, self.loggedIn else { return }
            let msg = BlynkMessage(command: .hardware, messageId: self.nextMsgId(), bodyParts: parts)
            self.enqueue(msg.serializeForHardware())
        }
    }

    private func nextMsgId() -> UInt16 {
        msgIdCounter &+= 1
        if msgIdCounter == 0 { msgIdCounter = 1 } // 0 is reserved / rejected by firmware
        return msgIdCounter
    }

    private func sendLogin() {
        guard let token = pendingToken else { return }
        loginMsgId = nextMsgId()
        emit(.stateChanged(.authenticating))
        let msg = BlynkMessage(command: .login, messageId: loginMsgId, body: token)
        enqueue(msg.serializeForHardware())
    }

    /// Build a RESPONSE frame (5-byte header, length field = status code, no body).
    private func responseFrame(messageId: UInt16, status: Int) -> Data {
        var d = Data()
        d.append(CommandCode.response.rawValue)
        d.append(UInt8((messageId >> 8) & 0xFF))
        d.append(UInt8(messageId & 0xFF))
        let s = UInt16(truncatingIfNeeded: status)
        d.append(UInt8((s >> 8) & 0xFF))
        d.append(UInt8(s & 0xFF))
        return d
    }

    private func handle(_ parsed: ParsedMessage) {
        switch parsed {
        case .response(let response):
            // loginMsgId=0 = login già risolto: evita che un RESPONSE hardware
            // col msgId riavvolto (dopo ~65k scritture) sia scambiato per login.
            if loginMsgId != 0, response.messageId == loginMsgId {
                let ok = response.code.isSuccess
                loggedIn = ok
                loginMsgId = 0
                emit(.loginResult(success: ok))
                emit(.stateChanged(ok ? .connected : .failed("Invalid auth token")))
            }
        case .command(let message):
            switch message.command {
            case .ping:
                // Keep-alive: the device pings when idle; answer or it resets us.
                enqueue(responseFrame(messageId: message.messageId, status: ResponseCode.ok.rawValue))
            case .hardware:
                let parts = message.bodyParts
                guard parts.count >= 2 else { return }
                let cmd = parts[0]
                guard cmd == "vw" || cmd == "aw" || cmd == "dw" else { return }
                let pin = Int(parts[1]) ?? -1
                let values = parts.count > 2 ? Array(parts[2...]) : []
                emit(.pinUpdate(command: cmd, pin: pin, values: values))
            default:
                // blynkInternal (blnkinf/rtc/meta), hardwareSync, etc. — ignored for MVP.
                break
            }
        }
    }

    // MARK: - Write pump (MTU chunking)

    private var writeType: CBCharacteristicWriteType {
        if let props = rxChar?.properties, props.contains(.writeWithoutResponse) {
            return .withoutResponse
        }
        return .withResponse
    }

    private func enqueue(_ frame: Data) {
        guard let peripheral else { return }
        let type = writeType
        let maxLen = max(20, peripheral.maximumWriteValueLength(for: type))
        var offset = 0
        while offset < frame.count {
            let end = min(offset + maxLen, frame.count)
            outbound.append(frame.subdata(in: offset..<end))
            offset = end
        }
        pump()
    }

    private func pump() {
        guard let peripheral, let rx = rxChar, !outbound.isEmpty else { return }
        let type = writeType
        if type == .withoutResponse {
            while !outbound.isEmpty, peripheral.canSendWriteWithoutResponse {
                let chunk = outbound.removeFirst()
                peripheral.writeValue(chunk, for: rx, type: .withoutResponse)
            }
        } else {
            guard !awaitingWriteResponse else { return }
            let chunk = outbound.removeFirst()
            awaitingWriteResponse = true
            peripheral.writeValue(chunk, for: rx, type: .withResponse)
        }
    }

    // MARK: - Emit / state mapping

    private func emit(_ event: BLEClientEvent) {
        continuation?.yield(event)
    }

    private func mapState(_ state: CBManagerState) -> BLEClientState {
        switch state {
        case .poweredOn: return .idle
        case .poweredOff: return .poweredOff
        case .unauthorized: return .unauthorized
        case .unsupported: return .unsupported
        default: return .idle
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension PlynxBLEClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Una connessione parcheggiata perché il central non era pronto
            // riparte adesso: è il momento in cui `retrievePeripherals` può
            // davvero rispondere.
            if let pending = pendingConnect {
                pendingConnect = nil
                performConnect(deviceId: pending.deviceId, token: pending.token)
                return
            }
            if wantsScan {
                tryStartScan()
                return
            }
        } else if pendingConnect != nil {
            // Acceso non lo sarà: la richiesta parcheggiata non partirà mai, e
            // lo stato mappato qui sotto (spento / negato / non supportato)
            // dice già il perché.
            pendingConnect = nil
        }
        emit(.stateChanged(mapState(central.state)))
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name ?? "Plynx device"
        discovered[peripheral.identifier] = BLEDiscoveredDevice(
            id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        emit(.discovered(discovered.values.sorted { $0.rssi > $1.rssi }))
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        parser.reset()
        outbound.removeAll()
        awaitingWriteResponse = false
        peripheral.discoverServices([Self.serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        emit(.stateChanged(.failed(error?.localizedDescription ?? "Connection failed")))
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Ignora il disconnect di un peripheral vecchio/cancellato: solo quello
        // corrente cambia lo stato della sessione.
        guard peripheral == self.peripheral else { return }
        connectGeneration &+= 1   // invalida un eventuale timeout pendente
        loggedIn = false
        rxChar = nil
        txChar = nil
        emit(.stateChanged(.disconnected))
    }
}

// MARK: - CBPeripheralDelegate

extension PlynxBLEClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            emit(.stateChanged(.failed("Plynx service not found on device")))
            return
        }
        peripheral.discoverCharacteristics([Self.rxUUID, Self.txUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == self.peripheral else { return }
        for char in service.characteristics ?? [] {
            if char.uuid == Self.rxUUID { rxChar = char }
            if char.uuid == Self.txUUID { txChar = char }
        }
        guard let tx = txChar, rxChar != nil else {
            emit(.stateChanged(.failed("Plynx characteristics not found")))
            return
        }
        peripheral.setNotifyValue(true, for: tx)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard characteristic.uuid == Self.txUUID, characteristic.isNotifying else { return }
        // Notifications live and RX is ready: the device is silent, so we log in first.
        sendLogin()
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard characteristic.uuid == Self.txUUID, let value = characteristic.value else { return }
        parser.append(value)
        for parsed in parser.parseAll() {
            handle(parsed)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral else { return }
        awaitingWriteResponse = false
        pump()
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        pump()
    }
}
#endif
