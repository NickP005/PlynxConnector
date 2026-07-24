import Foundation

public actor Connector {
    
    // MARK: - Properties
    
    private let host: String
    private let port: UInt16
    private let useSSL: Bool
    private var socket: PlynxSocket?
    
    private var messageId: UInt16 = 0
    private var pendingResponses: [UInt16: CheckedContinuation<Event, Error>] = [:]
    private var pendingDataResponses: [UInt16: PendingDataRequest] = [:]

    /// Pending data request: keeps the expected command so that unrelated
    /// frames with a colliding messageId (e.g. forwarded HARDWARE pushes)
    /// don't get returned as the response.
    private struct PendingDataRequest {
        let expectedCommand: CommandCode
        let continuation: CheckedContinuation<BlynkMessage, Error>
    }
    
    private(set) public var authenticated: Bool = false
    
    private(set) public var socketConnected: Bool = false
    
    private var pingTask: Task<Void, Never>?
    private var messageHandlerTask: Task<Void, Never>?
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var storedEmail: String?
    private var storedPassword: String?
    private var storedAppName: String?
    private var storedShareToken: String?
    
    private(set) public var activeDashboardId: Int?
    
    private var eventsContinuation: AsyncStream<Event>.Continuation?
    
    public nonisolated let events: AsyncStream<Event>
    
    public static let defaultPort: UInt16 = 9443
    
    public var responseTimeout: TimeInterval = 10.0
    
    public var pingInterval: TimeInterval = 10.0
    
    // MARK: - Callbacks
    
    public var onVirtualPinUpdate: ((Int, Int, Int, [String]) -> Void)?
    public var onDigitalPinUpdate: ((Int, Int, Int, Int) -> Void)?
    public var onAnalogPinUpdate: ((Int, Int, Int, Int) -> Void)?
    public var onWidgetPropertyChanged: ((Int, Int, Int, WidgetProperty, String) -> Void)?
    public var onHardwareConnected: ((Int, Int) -> Void)?
    public var onHardwareDisconnected: ((Int, Int) -> Void)?
    public var onConnectionStateChanged: ((Bool, Bool) -> Void)?
    public var onHardwareMessage: ((Int, Int, String) -> Void)?
    
    // MARK: - Initialization
    
    public init(host: String, port: UInt16 = defaultPort, useSSL: Bool = true) {
        self.host = host
        self.port = port
        self.useSSL = useSSL
        
        var continuation: AsyncStream<Event>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
    }
    
    deinit {
        eventsContinuation?.finish()
    }
    
    // MARK: - Connection
    
    public func connect(email: String, password: String, appName: String = "Blynk") async throws {
        storedEmail = email
        storedPassword = password
        storedAppName = appName
        storedShareToken = nil
        
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        startMessageHandler()
        
        eventsContinuation?.yield(.connected)
        onConnectionStateChanged?(true, false)
        
        let response = try await send(.login(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.loginSuccess)
                onConnectionStateChanged?(true, true)
                startPingTimer()
            } else {
                authenticated = false
                eventsContinuation?.yield(.loginFailed(code))
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    public func connectWithShareToken(_ token: String) async throws {
        storedShareToken = token
        storedEmail = nil
        storedPassword = nil
        storedAppName = nil
        
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        
        startMessageHandler()
        
        eventsContinuation?.yield(.connected)
        
        let response = try await send(.shareLogin(token: token))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                socketConnected = true
                onConnectionStateChanged?(true, true)
                eventsContinuation?.yield(.loginSuccess)
                startPingTimer()
            } else {
                authenticated = false
                eventsContinuation?.yield(.loginFailed(code))
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    public func register(email: String, password: String, appName: String = "Blynk") async throws {
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        startMessageHandler()
        
        let response = try await send(.register(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                await disconnect()
                eventsContinuation?.yield(.registered)
            } else if code == .userAlreadyRegistered {
                await disconnect()
                throw PlynxError.authenticationFailed(code)
            } else {
                await disconnect()
                throw PlynxError.serverError(code)
            }
        }
    }
    
    public func requestPasswordReset(email: String, appName: String = "Blynk") async throws {
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        startMessageHandler()
        
        let response = try await send(.resetPasswordStart(email: email, appName: appName))
        
        await disconnect()
        
        if case .response(_, let code) = response {
            if code != .ok {
                throw PlynxError.serverError(code)
            }
        }
    }
    
    public func disconnect() async {
        pingTask?.cancel()
        pingTask = nil
        messageHandlerTask?.cancel()
        messageHandlerTask = nil
        
        await socket?.disconnect()
        socket = nil
        
        let wasAuthenticated = authenticated
        let wasConnected = socketConnected
        
        authenticated = false
        socketConnected = false
        activeDashboardId = nil
        
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingResponses.removeAll()

        for (_, pending) in pendingDataResponses {
            pending.continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingDataResponses.removeAll()

        eventsContinuation?.yield(.disconnected(nil))
        
        if wasConnected || wasAuthenticated {
            onConnectionStateChanged?(false, false)
        }
    }
    
    public var isConnected: Bool {
        get async {
            guard let socket = socket else { return false }
            return await socket.isConnected && authenticated
        }
    }
    
    // MARK: - Sending Actions
    
    @discardableResult
    public func send(_ action: Action) async throws -> Event {
        guard let socket = socket else {
            throw PlynxError.notConnected
        }
        
        messageId = messageId &+ 1
        let msgId = messageId
        
        let message: BlynkMessage
        do {
            message = try action.toMessage(messageId: msgId, encoder: encoder)
        } catch {
            throw PlynxError.encodingError(error)
        }
        
        try await socket.send(message)
        
        return try await withTimeout(seconds: responseTimeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Event, Error>) in
                Task {
                    await self.registerPendingResponse(msgId: msgId, continuation: continuation)
                }
            }
        }
    }
    
    private func registerPendingResponse(msgId: UInt16, continuation: CheckedContinuation<Event, Error>) {
        pendingResponses[msgId] = continuation
    }
    
    func registerPendingDataResponse(msgId: UInt16, expecting expectedCommand: CommandCode, continuation: CheckedContinuation<BlynkMessage, Error>) {
        pendingDataResponses[msgId] = PendingDataRequest(expectedCommand: expectedCommand, continuation: continuation)
    }

    var pendingDataResponseCount: Int {
        pendingDataResponses.count
    }

    private func sendForData(_ action: Action, expecting expectedCommand: CommandCode) async throws -> BlynkMessage {
        guard let socket = socket else {
            throw PlynxError.notConnected
        }
        
        messageId = messageId &+ 1
        let msgId = messageId
        
        let message: BlynkMessage
        do {
            message = try action.toMessage(messageId: msgId, encoder: encoder)
        } catch {
            throw PlynxError.encodingError(error)
        }
        
        try await socket.send(message)
        
        return try await withTimeout(seconds: responseTimeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BlynkMessage, Error>) in
                Task {
                    await self.registerPendingDataResponse(msgId: msgId, expecting: expectedCommand, continuation: continuation)
                }
            }
        }
    }
    
    // MARK: - Message Handling
    
    private func startMessageHandler() {
        guard let socket = socket else { return }
        
        messageHandlerTask = Task { [weak self] in
            for await parsedMessage in socket.messages {
                guard let self = self else { break }
                await self.handleMessage(parsedMessage)
            }
            
            guard let self = self else { return }
            await self.handleSocketDisconnected()
        }
    }
    
    private func handleSocketDisconnected() {
        let wasAuthenticated = authenticated
        let wasConnected = socketConnected
        
        socketConnected = false
        authenticated = false
        
        eventsContinuation?.yield(.disconnected(nil))
        
        if wasConnected || wasAuthenticated {
            onConnectionStateChanged?(false, false)
        }
        
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingResponses.removeAll()
        
        for (_, pending) in pendingDataResponses {
            pending.continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingDataResponses.removeAll()
        
        if wasAuthenticated && (storedEmail != nil || storedShareToken != nil) {
            Task {
                await self.startAutoReconnect()
            }
        }
    }
    
    // MARK: - Auto Reconnection
    
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt: Int = 0
    private let maxReconnectAttempts: Int = 10
    private let baseReconnectDelay: TimeInterval = 2.0
    private let maxReconnectDelay: TimeInterval = 30.0
    
    private func startAutoReconnect() async {
        reconnectTask?.cancel()
        reconnectAttempt = 0
        
        while reconnectAttempt < maxReconnectAttempts {
            reconnectAttempt += 1
            
            let delay = min(baseReconnectDelay * pow(1.5, Double(reconnectAttempt - 1)), maxReconnectDelay)
            
            eventsContinuation?.yield(.reconnecting(attempt: reconnectAttempt))
            
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            
            do {
                if let email = storedEmail, let password = storedPassword, let appName = storedAppName {
                    try await reconnectWithCredentials(email: email, password: password, appName: appName)
                    reconnectAttempt = 0
                    return
                } else if let token = storedShareToken {
                    try await reconnectWithShareToken(token)
                    reconnectAttempt = 0
                    return
                } else {
                    return
                }
            } catch let error as PlynxError {
                if case .authenticationFailed(let code) = error {
                    if code == .userNotRegistered || code == .invalidToken {
                        eventsContinuation?.yield(.loginFailed(code))
                        return
                    }
                }
            } catch {
            }
        }
    }
    
    private func reconnectWithCredentials(email: String, password: String, appName: String) async throws {
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        startMessageHandler()
        
        let response = try await send(.login(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.reconnected)
                onConnectionStateChanged?(true, true)
                startPingTimer()
            } else {
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    private func reconnectWithShareToken(_ token: String) async throws {
        let sock = PlynxSocket(host: host, port: port, useSSL: useSSL)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        startMessageHandler()
        
        let response = try await send(.shareLogin(token: token))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.reconnected)
                onConnectionStateChanged?(true, true)
                startPingTimer()
            } else {
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    public func stopReconnecting() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }
    
    func handleMessage(_ parsedMessage: ParsedMessage) {
        if case .response(let response) = parsedMessage {
            if let continuation = pendingResponses.removeValue(forKey: response.messageId) {
                let event = Event.response(messageId: response.messageId, code: response.code)
                continuation.resume(returning: event)
                return
            }

            // Una .response per una richiesta dati pendente è un errore del server
            // (es. noData per loadProfile): fail fast invece del timeout generico
            if let pending = pendingDataResponses.removeValue(forKey: response.messageId) {
                let error: PlynxError = response.code == .ok ? .unexpectedResponse : .serverError(response.code)
                pending.continuation.resume(throwing: error)
                return
            }
        }

        if case .command(let message) = parsedMessage {
            if let pending = pendingDataResponses[message.messageId],
               pending.expectedCommand == message.command {
                pendingDataResponses.removeValue(forKey: message.messageId)
                pending.continuation.resume(returning: message)
                return
            }
            // Comando diverso da quello atteso con stesso msgId (es. push HARDWARE
            // inoltrato dal server): lascialo cadere nel normale event path

            if message.command == .getShareToken || message.command == .refreshShareToken {
                if let continuation = pendingResponses.removeValue(forKey: message.messageId) {
                    let token = message.body
                    let event = Event.shareToken(token)
                    continuation.resume(returning: event)
                    return
                }
            }
            
            if message.command == .createDevice {
                if let continuation = pendingResponses.removeValue(forKey: message.messageId) {
                    let event = Event.response(messageId: message.messageId, code: .ok)
                    continuation.resume(returning: event)
                    return
                }
            }
        }
        
        if let event = Event.from(message: parsedMessage, decoder: decoder) {
            switch event {
            case .response(let msgId, _):
                if let continuation = pendingResponses.removeValue(forKey: msgId) {
                    continuation.resume(returning: event)
                    return
                }
            default:
                break
            }
            
            invokeCallbacks(for: event)
            eventsContinuation?.yield(event)
        }
    }
    
    private func invokeCallbacks(for event: Event) {
        switch event {
        case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
            onVirtualPinUpdate?(dashId, deviceId, pin, values)
            onHardwareMessage?(dashId, deviceId, "vw\0\(pin)\0\(values.joined(separator: "\0"))")
            
        case .digitalPinUpdate(let dashId, let deviceId, let pin, let value):
            onDigitalPinUpdate?(dashId, deviceId, pin, value)
            onHardwareMessage?(dashId, deviceId, "dw\0\(pin)\0\(value)")
            
        case .analogPinUpdate(let dashId, let deviceId, let pin, let value):
            onAnalogPinUpdate?(dashId, deviceId, pin, value)
            onHardwareMessage?(dashId, deviceId, "aw\0\(pin)\0\(value)")
            
        case .hardwareMessage(let dashId, let deviceId, let body):
            onHardwareMessage?(dashId, deviceId, body)
            
        case .widgetPropertyChanged(let dashId, let deviceId, let pin, let property, let value):
            onWidgetPropertyChanged?(dashId, deviceId, pin, property, value)
            
        case .hardwareConnected(let dashId, let deviceId):
            onHardwareConnected?(dashId, deviceId)
            
        case .hardwareDisconnected(let dashId, let deviceId):
            onHardwareDisconnected?(dashId, deviceId)
            
        case .disconnected:
            let wasConnected = socketConnected
            socketConnected = false
            authenticated = false
            if wasConnected {
                onConnectionStateChanged?(false, false)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Ping Timer
    
    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pingInterval ?? 10.0) * 1_000_000_000)
                
                guard !Task.isCancelled, let self = self else { break }
                
                do {
                    _ = try await self.send(.ping)
                } catch {
                }
            }
        }
    }
    
    // MARK: - Reconnection Handling
    
    private func handleReconnection() async {
        guard authenticated else { return }
        
        socketConnected = false
        authenticated = false
        onConnectionStateChanged?(false, false)
        
        eventsContinuation?.yield(.reconnecting(attempt: await socket?.currentReconnectAttempt ?? 0))
        
        if let email = storedEmail, let password = storedPassword, let appName = storedAppName {
            do {
                let response = try await send(.login(email: email, password: password, appName: appName))
                if case .response(_, let code) = response, code == .ok {
                    socketConnected = true
                    authenticated = true
                    onConnectionStateChanged?(true, true)
                    eventsContinuation?.yield(.reconnected)
                    startPingTimer()
                }
            } catch {
            }
        } else if let token = storedShareToken {
            do {
                let response = try await send(.shareLogin(token: token))
                if case .response(_, let code) = response, code == .ok {
                    socketConnected = true
                    authenticated = true
                    onConnectionStateChanged?(true, true)
                    eventsContinuation?.yield(.reconnected)
                    startPingTimer()
                }
            } catch {
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Warnings raised during the last `loadProfile()` decode
    /// (widgets/devices/dashboards or fields dropped by lossy decoding).
    private(set) public var lastProfileDecodeWarnings: [String] = []

    /// Capability handshake: versione e feature opzionali del server.
    /// Sui server legacy il comando cade nel vuoto: il timeout va
    /// interpretato dal chiamante come "server legacy".
    public func getServerInfo() async throws -> ServerInfo {
        let response = try await sendForData(.getServerInfo, expecting: .getServerInfo)
        guard response.command == .getServerInfo,
              let data = response.body.data(using: .utf8) else {
            throw PlynxError.unexpectedResponse
        }
        do {
            return try JSONDecoder().decode(ServerInfo.self, from: data)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    /// Plynx linked devices: collega la scheda (ownerDashId, ownerDeviceId)
    /// nel progetto target. Ritorna il device alias creato dal server.
    public func linkDevice(targetDashId: Int, ownerDashId: Int, ownerDeviceId: Int) async throws -> Device {
        let response = try await sendForData(
            .linkDevice(targetDashId: targetDashId, ownerDashId: ownerDashId, ownerDeviceId: ownerDeviceId),
            expecting: .linkDevice)
        guard response.command == .linkDevice,
              let data = response.body.data(using: .utf8) else {
            throw PlynxError.unexpectedResponse
        }
        do {
            return try decoder.decode(Device.self, from: data)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    // MARK: - Project sharing (clone)

    /// Genera un codice di clonazione per un progetto: il server ne fa una copia
    /// "template" (senza token/segreti né valori dei widget) e ritorna un codice
    /// condivisibile. Chi ha il codice può importare il progetto con
    /// `importProject(cloneCode:)`.
    public func getCloneCode(dashId: Int) async throws -> String {
        let response = try await sendForData(.getCloneCode(dashId: dashId),
                                             expecting: .getCloneCode)
        guard response.command == .getCloneCode else {
            throw PlynxError.unexpectedResponse
        }
        let code = response.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw PlynxError.unexpectedResponse }
        return code
    }

    /// Importa un progetto da un codice di clonazione: il server crea una nuova
    /// dashboard nel profilo dell'utente rigenerando i token dei device, e
    /// ritorna la dashboard creata (gzip). Il chiamante di norma ricarica poi
    /// il profilo per averla in lista.
    public func importProject(cloneCode: String) async throws -> DashBoard {
        let response = try await sendForData(
            .getProjectByCloneCode(code: cloneCode, create: true),
            expecting: .getProjectByCloneCode)
        guard response.command == .getProjectByCloneCode,
              let rawData = response.rawData, !rawData.isEmpty else {
            throw PlynxError.unexpectedResponse
        }
        let decompressed: Data
        do {
            decompressed = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }
        do {
            return try decoder.decode(DashBoard.self, from: decompressed)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    // MARK: - Published projects (entità persistente, mirror vivo)

    /// Pubblica un progetto: ritorna (publishedId stabile, versione corrente).
    /// Ripubblicare lo stesso progetto riusa l'id e incrementa la versione.
    public func publishProject(dashId: Int) async throws -> (id: String, version: Int) {
        let response = try await sendForData(.publishProject(dashId: dashId),
                                             expecting: .publishProject)
        guard response.command == .publishProject else {
            throw PlynxError.unexpectedResponse
        }
        let parts = response.bodyParts
        guard let id = parts.first, !id.isEmpty else { throw PlynxError.unexpectedResponse }
        let version = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        return (id, version)
    }

    /// Scarica un progetto pubblicato dato il suo ID pubblico: ritorna versione
    /// + template (dashboard senza token). Usato sia al primo download sia dal
    /// mirror vivo per controllare se è uscita una versione nuova.
    /// countsAsDownload: passa false per un fetch di sola anteprima (la pagina
    /// dettaglio del catalogo) così il server non lo conta come download.
    public func getPublishedProject(publishedId: String,
                                    countsAsDownload: Bool = true) async throws -> PublishedProject {
        let response = try await sendForData(.getPublishedProject(publishedId: publishedId,
                                                                  countsAsDownload: countsAsDownload),
                                             expecting: .getPublishedProject)
        guard response.command == .getPublishedProject,
              let rawData = response.rawData, !rawData.isEmpty else {
            throw PlynxError.unexpectedResponse
        }
        let decompressed: Data
        do {
            decompressed = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }
        do {
            return try decoder.decode(PublishedProject.self, from: decompressed)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    // MARK: - Public catalog (scoperta progetti altrui, Slice 4)

    /// Elenca (o rimuove) un proprio progetto pubblicato nel catalogo pubblico.
    /// Denormalizza lo `username` autore + una `description` sulla card. Il
    /// server verifica la proprietà: si può (dis)elencare solo un progetto che
    /// si è pubblicato. Ritorna l'Event di conferma.
    @discardableResult
    public func setProjectPublic(publishedId: String, isPublic: Bool,
                                 username: String, description: String) async throws -> Event {
        try await send(.setProjectPublic(publishedId: publishedId, isPublic: isPublic,
                                         username: username, description: description))
    }

    /// Sfoglia o cerca il catalogo pubblico. `query` nil/vuota = progetti più
    /// recenti; valorizzata = ricerca per nome/autore/descrizione. Ritorna card
    /// leggere (senza template): il progetto scelto si scarica poi per id con
    /// `getPublishedProject(publishedId:)`.
    public func listPublicProjects(query: String? = nil,
                                   offset: Int = 0,
                                   limit: Int = 30) async throws -> [PublicCatalogEntry] {
        let response = try await sendForData(
            .listPublicProjects(query: query, offset: offset, limit: limit),
            expecting: .listPublicProjects)
        guard response.command == .listPublicProjects,
              let rawData = response.rawData, !rawData.isEmpty else {
            throw PlynxError.unexpectedResponse
        }
        let decompressed: Data
        do {
            decompressed = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }
        do {
            return try decoder.decode([PublicCatalogEntry].self, from: decompressed)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    /// Legge lo stato di listing del PROPRIO progetto pubblicato: se è in
    /// catalogo, con username e descrizione salvati sulla riga. Owner-guarded
    /// lato server: id sconosciuto o altrui → errore (il chiamante tiene i
    /// default "non elencato").
    public func getProjectPublic(publishedId: String) async throws -> PublicListingState {
        let response = try await sendForData(
            .getProjectPublic(publishedId: publishedId),
            expecting: .getProjectPublic)
        guard response.command == .getProjectPublic,
              let rawData = response.rawData, !rawData.isEmpty else {
            throw PlynxError.unexpectedResponse
        }
        let decompressed: Data
        do {
            decompressed = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }
        do {
            return try decoder.decode(PublicListingState.self, from: decompressed)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    /// Commenta un progetto elencato nel catalogo pubblico. Il server rifiuta
    /// (errore) se il progetto non esiste o non è più elencato.
    @discardableResult
    public func postProjectComment(publishedId: String, username: String,
                                   body: String) async throws -> Event {
        try await send(.postProjectComment(publishedId: publishedId,
                                           username: username, body: body))
    }

    /// Elenca i commenti di un progetto del catalogo, più recenti prima.
    /// `canDelete` è per-chiamante (proprio commento o proprio progetto).
    public func listProjectComments(publishedId: String,
                                    offset: Int = 0,
                                    limit: Int = 50) async throws -> [ProjectComment] {
        let response = try await sendForData(
            .listProjectComments(publishedId: publishedId, offset: offset, limit: limit),
            expecting: .listProjectComments)
        guard response.command == .listProjectComments,
              let rawData = response.rawData, !rawData.isEmpty else {
            throw PlynxError.unexpectedResponse
        }
        let decompressed: Data
        do {
            decompressed = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }
        do {
            return try decoder.decode([ProjectComment].self, from: decompressed)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }

    /// Cancella un commento: consentito all'autore o al proprietario del
    /// progetto commentato (guard lato server).
    @discardableResult
    public func deleteProjectComment(commentId: String) async throws -> Event {
        try await send(.deleteProjectComment(commentId: commentId))
    }

    // MARK: - Public catalog ratings (Slice 4d)

    /// Vota un progetto del catalogo con `stars` (1..5). Rivotare sostituisce il
    /// voto. Il server rifiuta (serverError) se il progetto non è elencato o se
    /// sei tu il proprietario (niente auto-voto).
    @discardableResult
    public func rateProject(publishedId: String, stars: Int) async throws -> Event {
        try await send(.rateProject(publishedId: publishedId, stars: stars))
    }

    /// Legge il riepilogo voti di un progetto: (mio voto 0..5, media, conteggio).
    /// Reply data-frame testo plain "myStars\0avg\0count".
    public func getProjectRating(publishedId: String) async throws -> ProjectRating {
        let response = try await sendForData(.getProjectRating(publishedId: publishedId),
                                             expecting: .getProjectRating)
        guard response.command == .getProjectRating else {
            throw PlynxError.unexpectedResponse
        }
        let parts = response.bodyParts
        let mine = parts.count > 0 ? (Int(parts[0]) ?? 0) : 0
        let avg = parts.count > 1 ? (Double(parts[1]) ?? 0) : 0
        let count = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
        return ProjectRating(myStars: mine, average: avg, count: count)
    }

    public func loadProfile() async throws -> Profile {
        let response = try await sendForData(.loadProfile(dashId: nil, published: false), expecting: .loadProfileGzipped)

        guard response.command == .loadProfileGzipped else {
            throw PlynxError.unexpectedResponse
        }

        guard let rawData = response.rawData, !rawData.isEmpty else {
            lastProfileDecodeWarnings = []
            return Profile()
        }

        let decompressedData: Data
        do {
            decompressedData = try GzipHelper.decompress(rawData)
        } catch {
            throw PlynxError.decodingError(error)
        }

        let warnings = DecodeWarnings()
        decoder.userInfo[DecodeWarnings.userInfoKey] = warnings
        defer { lastProfileDecodeWarnings = warnings.warnings }

        do {
            return try decoder.decode(Profile.self, from: decompressedData)
        } catch {
            throw PlynxError.decodingError(error)
        }
    }
    
    @discardableResult
    public func writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String) async throws -> Event {
        return try await send(.writeVirtualPin(dashId: dashId, deviceId: deviceId, pin: pin, value: value))
    }
    
    @discardableResult
    public func activateDashboard(_ dashId: Int) async throws -> Event {
        let result = try await send(.activateDashboard(dashId: dashId))
        if case .response(_, let code) = result, code == .ok {
            activeDashboardId = dashId
        }
        return result
    }
    
    @discardableResult
    public func deactivateAllDashboards() async throws -> Event {
        let result = try await send(.deactivateDashboard(dashId: nil))
        if case .response(_, let code) = result, code == .ok {
            activeDashboardId = nil
        }
        return result
    }
    
    public func requestGraphData(
        dashId: Int,
        widgetId: Int,
        targetId: Int? = nil,
        period: GraphPeriod,
        page: Int? = nil
    ) async throws -> Data? {
        let action = Action.getEnhancedGraphData(
            dashId: dashId,
            widgetId: widgetId,
            targetId: targetId,
            period: period,
            page: page
        )
        
        let response = try await sendForData(action, expecting: .getEnhancedGraphData)

        if response.command == .getEnhancedGraphData {
            guard let rawData = response.rawData, !rawData.isEmpty else {
                return nil
            }
            return rawData
        }
        
        return nil
    }
    
    public func requestParsedGraphData(
        dashId: Int,
        widgetId: Int,
        targetId: Int? = nil,
        period: GraphPeriod,
        page: Int? = nil
    ) async throws -> [GraphStreamData] {
        guard let rawData = try await requestGraphData(
            dashId: dashId,
            widgetId: widgetId,
            targetId: targetId,
            period: period,
            page: page
        ) else {
            return []
        }
        
        return try GraphDataParser.parse(compressedData: rawData)
    }
}

// MARK: - Timeout Helper

private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw PlynxError.timeout
        }
        
        guard let result = try await group.next() else {
            throw PlynxError.timeout
        }
        group.cancelAll()
        return result
    }
}
