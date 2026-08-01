# PlynxConnector

PlynxConnector is a Swift package that implements the communication protocol used by the Plynx apps. It covers the transport (TCP over TLS to a Plynx server, or Bluetooth LE straight to a board), the binary framing, the command and event vocabulary, and the data models for projects, devices and widgets.

It is the networking layer of the Plynx iOS app, packaged so the same code can be reused across Apple platforms.

## What it provides

- **Server transport** — TCP socket with TLS, keepalive, ping and automatic reconnection.
- **Direct BLE transport** — talk to a Plynx board over CoreBluetooth, without a server or Wi-Fi.
- **Typed protocol layer** — commands, server response codes and events as Swift enums, with framing and gzip handled internally.
- **Data models** — `DashBoard`, `Device`, `Widget`, `Tag`, `TileTemplate`, `Report`, `EventorRule`, plus sharing and catalog types. All `Codable`, and tolerant of unknown or malformed fields (dropped items are reported in `lastProfileDecodeWarnings`).
- **async/await API** — `send(_:)` returns the matching server response; live updates arrive on an `AsyncStream` of events.
- **No third-party dependencies** — Foundation, Network and CoreBluetooth only.

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.5+
- Xcode 13+

## Installation

### Swift Package Manager

In Xcode: File → Add Package Dependencies, then enter `https://github.com/NickP005/PlynxConnector.git` and pick a version.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NickP005/PlynxConnector.git", from: "2.6.0")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: ["PlynxConnector"]
)
```

### CocoaPods

```ruby
pod 'PlynxConnector', :git => 'https://github.com/NickP005/PlynxConnector.git', :tag => '2.6.0'
```

### Manual

Drag `Sources/PlynxConnector` into your Xcode project. There is nothing else to link beyond the system frameworks.

## Quick start

The module is `PlynxConnector`; the main type is the actor `Connector`.

```swift
import PlynxConnector

let plynx = Connector(host: "192.168.1.100", port: 9443)

Task {
    do {
        try await plynx.connect(email: "user@example.com", password: "secret", appName: "MyApp")

        // A project must be activated before hardware commands reach the device
        _ = try await plynx.activateDashboard(1)

        _ = try await plynx.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255")
    } catch {
        print("Plynx error: \(error)")
    }
}
```

## Events

Everything the server pushes arrives on `events`, an `AsyncStream<Event>`:

```swift
Task {
    for await event in plynx.events {
        switch event {
        case .connected:
            print("Socket up")

        case .loginSuccess:
            print("Authenticated")

        case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
            print("Project \(dashId), device \(deviceId): V\(pin) = \(values)")

        case .hardwareConnected(let dashId, let deviceId):
            print("Device \(deviceId) of project \(dashId) is online")

        case .hardwareDisconnected(_, let deviceId):
            print("Device \(deviceId) went offline")

        case .disconnected(let error):
            print("Disconnected: \(error?.localizedDescription ?? "no reason given")")

        case .reconnecting(let attempt):
            print("Reconnecting, attempt \(attempt)")

        default:
            break
        }
    }
}
```

## Connection state

`Connector` is an actor, so its state is read with `await`:

```swift
if await plynx.socketConnected { /* transport is up */ }
if await plynx.authenticated { /* login accepted */ }
if let dashId = await plynx.activeDashboardId { /* project currently active */ }
if await plynx.isConnected { /* connected and authenticated */ }
```

## Callbacks

Besides the event stream, the connector exposes callback properties for code running inside its isolation domain:

```swift
var onVirtualPinUpdate: ((Int, Int, Int, [String]) -> Void)?     // dashId, deviceId, pin, values
var onDigitalPinUpdate: ((Int, Int, Int, Int) -> Void)?          // dashId, deviceId, pin, value
var onAnalogPinUpdate: ((Int, Int, Int, Int) -> Void)?           // dashId, deviceId, pin, value
var onWidgetPropertyChanged: ((Int, Int, Int, WidgetProperty, String) -> Void)?
var onHardwareConnected: ((Int, Int) -> Void)?                   // dashId, deviceId
var onHardwareDisconnected: ((Int, Int) -> Void)?                // dashId, deviceId
var onConnectionStateChanged: ((Bool, Bool) -> Void)?            // connected, authenticated
var onHardwareMessage: ((Int, Int, String) -> Void)?             // dashId, deviceId, raw body
```

From outside the actor, use `events`.

## Commands

Every command is an `Action` case passed to `send(_:)`; the frequent ones also have convenience methods.

### Account

```swift
try await plynx.connect(email: "user@example.com", password: "secret", appName: "MyApp")
try await plynx.connectWithShareToken("abc123")
try await plynx.register(email: "new@example.com", password: "secret", appName: "MyApp")
try await plynx.requestPasswordReset(email: "user@example.com", appName: "MyApp")

_ = try await plynx.send(.logout(uid: nil))
```

### Projects

```swift
let profile = try await plynx.loadProfile()          // all projects and apps

let project = DashBoard(id: 0, name: "Greenhouse")
_ = try await plynx.send(.createDashboard(dashboard: project, generateToken: true))

_ = try await plynx.activateDashboard(1)
_ = try await plynx.send(.deactivateDashboard(dashId: 1))
_ = try await plynx.send(.deleteDashboard(dashId: 1))
```

### Devices

```swift
let device = Device(id: 0, name: "Greenhouse ESP", boardType: .ESP8266)
_ = try await plynx.send(.createDevice(dashId: 1, device: device))

_ = try await plynx.send(.getDevices(dashId: 1))
_ = try await plynx.send(.getDevice(dashId: 1, deviceId: 0))
_ = try await plynx.send(.updateDevice(dashId: 1, device: device))
_ = try await plynx.send(.deleteDevice(dashId: 1, deviceId: 0))
_ = try await plynx.send(.refreshToken(dashId: 1, deviceId: 0))
```

### Widgets

```swift
var button = Widget(id: 0, type: .button)
button.x = 0
button.y = 0
button.width = 2
button.height = 1
button.pin = 1
button.pinType = .virtual

_ = try await plynx.send(.createWidget(dashId: 1, widget: button, tileId: nil))

button.label = "Pump"
_ = try await plynx.send(.updateWidget(dashId: 1, widget: button))
_ = try await plynx.send(.deleteWidget(dashId: 1, widgetId: button.id))

_ = try await plynx.send(.setWidgetProperty(dashId: 1, deviceId: 0, pin: 1, property: .label, value: "Pump"))
```

### Hardware

```swift
_ = try await plynx.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255")
_ = try await plynx.send(.readVirtualPin(dashId: 1, deviceId: 0, pin: 1))

// Raw command, fields separated by NUL
_ = try await plynx.send(.hardware(dashId: 1, deviceId: 0, body: "vw\u{0}1\u{0}255"))

_ = try await plynx.send(.hardwareSync(dashId: 1, target: nil))
_ = try await plynx.send(.appSync(dashId: 1, widgetIds: nil))
```

### Tags

```swift
let tag = Tag(id: 100000, name: "Living room", deviceIds: [0, 1])
_ = try await plynx.send(.createTag(dashId: 1, tag: tag))
_ = try await plynx.send(.getTags(dashId: 1))
_ = try await plynx.send(.updateTag(dashId: 1, tag: tag))
_ = try await plynx.send(.deleteTag(dashId: 1, tagId: 100000))
```

### Sharing and the public catalog

```swift
// Read-only access to a project
_ = try await plynx.send(.setSharing(dashId: 1, enabled: true))
_ = try await plynx.send(.getShareToken(dashId: 1))
_ = try await plynx.send(.refreshShareToken(dashId: 1))

// Copy a project between accounts
let code = try await plynx.getCloneCode(dashId: 1)
let imported = try await plynx.importProject(cloneCode: code)

// Publish and browse
let published = try await plynx.publishProject(dashId: 1)
_ = try await plynx.setProjectPublic(publishedId: published.id, isPublic: true,
                                     username: "nick", description: "Greenhouse controller")
let entries = try await plynx.listPublicProjects(query: "greenhouse", offset: 0, limit: 30)
```

### History data

```swift
let raw = try await plynx.requestGraphData(dashId: 1, widgetId: 12, targetId: 0, period: .day)
let series = try await plynx.requestParsedGraphData(dashId: 1, widgetId: 12, targetId: 0, period: .week)

_ = try await plynx.send(.exportGraphData(dashId: 1, widgetId: 12, pinType: .virtual, pin: 1, deviceId: 0))
_ = try await plynx.send(.deleteEnhancedGraphData(dashId: 1, widgetId: 12, dataStreamIds: nil))
```

### Email and energy

```swift
_ = try await plynx.send(.emailToken(dashId: 1, deviceId: 0))
_ = try await plynx.send(.email(dashId: 1, deviceId: 0, to: "user@example.com", subject: "Test", body: "Hello"))

_ = try await plynx.send(.getEnergy)
_ = try await plynx.send(.redeem(code: "PROMO123"))
```

## Direct BLE connection

`PlynxBLEClient` speaks the same protocol over a GATT service, so a phone can drive a board that has no network at all. It scans, authenticates with the 32-character device token, and then reads and writes pins.

```swift
let ble = PlynxBLEClient()

Task {
    for await event in ble.events {
        switch event {
        case .stateChanged(let state):
            print("BLE state: \(state)")
        case .discovered(let devices):
            print("Found: \(devices.map(\.name))")
        case .loginResult(let success):
            print(success ? "Board authenticated" : "Token rejected")
        case .pinUpdate(let command, let pin, let values):
            print("\(command) \(pin) = \(values)")
        }
    }
}

ble.startScan()
ble.connect(deviceId: discoveredDevice.id, token: deviceToken)
ble.writeVirtualPin(1, value: "255")
ble.syncVirtualPin(1)
```

## Error handling

```swift
do {
    try await plynx.connect(email: "user@example.com", password: "wrong", appName: "MyApp")
} catch PlynxError.authenticationFailed(let code) {
    print("Login refused: \(code)")
} catch PlynxError.connectionFailed(let underlying) {
    print("Connection failed: \(underlying?.localizedDescription ?? "no detail")")
} catch PlynxError.timeout {
    print("Request timed out")
} catch {
    print("Other error: \(error)")
}
```

Other cases include `.connectionClosed`, `.notConnected`, `.notAuthenticated`, `.serverError`, `.decodingError`, `.tlsError` and `.cancelled`.

## Behaviour notes

- **Timeouts** — `responseTimeout` and `pingInterval` both default to 10 seconds.
- **Reconnection** — after an unexpected drop the connector retries up to 10 times, waiting 2 seconds and growing the delay by 1.5x up to 30 seconds. `.reconnecting(attempt:)` is emitted before each try, `.reconnected` once the session is back. `stopReconnecting()` cancels the loop.
- **Concurrency** — `Connector` is an actor, so it is safe to use from several tasks; requests are serialised and matched to responses by message id.

## Protocol notes

- Default endpoint is port 9443 over TLS. Plain TCP is available with `useSSL: false`. Self-signed server certificates are accepted.
- App frames use a 7-byte header: 1 byte command, 2 bytes message id (big-endian), 4 bytes body length (big-endian), then the body. Hardware frames use a 5-byte header with a 2-byte length.
- Body fields are separated by a NUL character. Profile and history payloads arrive gzipped and are inflated by the library.

## Repository layout

```
Sources/PlynxConnector/
├── Protocol/        CommandCode, ResponseCode, BlynkMessage, HardwareMessageParser
├── Models/          DashBoard, Device, Widget, Tag, TileTemplate, Report, EventorRule,
│                    sharing and catalog types, and the Enums/ folder
├── Actions/         Action and its wire encoding
├── Events/          Event
├── Transport/       PlynxSocket (TCP/TLS), PlynxBLEClient (CoreBluetooth)
├── Utils/           PlynxError, GzipHelper, GraphDataParser, SHA256Helper, DecodeWarnings
├── MockConnector    In-memory connector for previews and tests
└── PlynxConnector   The Connector actor, public entry point
```

## Documentation

- [INTERFACE.md](INTERFACE.md) — full API reference, every command, event and model.
- [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) — end-to-end setup, from a bare board to live data.

## License

Copyright (c) 2025 NickP005. All rights reserved. This software is proprietary; see [LICENSE](LICENSE) for the terms. For licensing enquiries, contact the author.

## Compatibility and origin

PlynxConnector is an original and independent implementation of the legacy protocol documented publicly, written for interoperability with existing servers and hardware. This project is not affiliated with, sponsored by, or endorsed by Blynk Inc.
