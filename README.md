# PlynxConnector

Swift iOS connector library for the Plynx (Blynk) server. Provides a complete interface to control IoT devices through the Plynx server using the binary TCP/SSL protocol.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 13+

## Installation

1. Copy the entire `PlynxConnector/` folder into your Xcode project
2. Make sure all files are added to your target
3. The library uses only Foundation and Network frameworks (no external dependencies)

## Quick Start

```swift
import Foundation

// Create connector
let plynx = PlynxConnector(host: "192.168.1.100", port: 9443)

Task {
    do {
        // Connect and login
        try await plynx.connect(email: "user@example.com", password: "mypassword", appName: "MyApp")
        print("Connected!")
        
        // Activate a dashboard (required before hardware commands)
        _ = try await plynx.send(.activateDashboard(dashId: 1))
        
        // Write to virtual pin
        _ = try await plynx.send(.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255"))
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Listening for Events

```swift
Task {
    for await event in plynx.events {
        switch event {
        case .connected:
            print("Connected to server")
            
        case .loginSuccess:
            print("Logged in successfully")
            
        case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
            print("Dashboard \(dashId), Device \(deviceId): V\(pin) = \(values)")
            
        case .hardwareConnected(let dashId, let deviceId):
            print("Device \(deviceId) connected")
            
        case .hardwareDisconnected(let dashId, let deviceId):
            print("Device \(deviceId) disconnected")
            
        case .disconnected(let error):
            print("Disconnected: \(error?.localizedDescription ?? "unknown")")
            
        case .reconnecting(let attempt):
            print("Reconnecting... attempt \(attempt)")
            
        default:
            break
        }
    }
}
```

## Available Actions

### Authentication

```swift
// Login
try await plynx.connect(email: "user@example.com", password: "pass", appName: "MyApp")

// Login with share token
try await plynx.connectWithShareToken("abc123")

// Logout
_ = try await plynx.send(.logout(uid: nil))

// Register new account
_ = try await plynx.send(.register(email: "new@example.com", password: "pass", appName: "MyApp"))
```

### Dashboard Management

```swift
// Load all dashboards
_ = try await plynx.send(.loadProfile(dashId: nil, published: false))

// Create dashboard
let dashboard = DashBoard(id: 0, name: "My Dashboard")
_ = try await plynx.send(.createDashboard(dashboard: dashboard, generateToken: true))

// Activate dashboard (required for hardware commands to work)
_ = try await plynx.send(.activateDashboard(dashId: 1))

// Deactivate dashboard
_ = try await plynx.send(.deactivateDashboard(dashId: 1))

// Delete dashboard
_ = try await plynx.send(.deleteDashboard(dashId: 1))
```

### Device Management

```swift
// Create device
let device = Device(id: 0, name: "My ESP8266", boardType: .ESP8266)
let response = try await plynx.send(.createDevice(dashId: 1, device: device))

// Get all devices
_ = try await plynx.send(.getDevices(dashId: 1))

// Get single device
_ = try await plynx.send(.getDevice(dashId: 1, deviceId: 0))

// Update device
var updatedDevice = device
updatedDevice.name = "Updated Name"
_ = try await plynx.send(.updateDevice(dashId: 1, device: updatedDevice))

// Delete device
_ = try await plynx.send(.deleteDevice(dashId: 1, deviceId: 0))

// Refresh device token
_ = try await plynx.send(.refreshToken(dashId: 1, deviceId: 0))
```

### Widget Management

```swift
// Create widget
var button = Widget(id: 0, type: .button)
button.x = 0
button.y = 0
button.width = 2
button.height = 1
button.pin = 1
button.pinType = .virtual
_ = try await plynx.send(.createWidget(dashId: 1, widget: button, tileId: nil))

// Update widget
button.label = "My Button"
_ = try await plynx.send(.updateWidget(dashId: 1, widget: button))

// Delete widget
_ = try await plynx.send(.deleteWidget(dashId: 1, widgetId: button.id))

// Set widget property
_ = try await plynx.send(.setWidgetProperty(dashId: 1, deviceId: 0, pin: 1, property: .label, value: "New Label"))
```

### Hardware Communication

```swift
// Write to virtual pin
_ = try await plynx.send(.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255"))

// Read from virtual pin
_ = try await plynx.send(.readVirtualPin(dashId: 1, deviceId: 0, pin: 1))

// Raw hardware command
_ = try await plynx.send(.hardware(dashId: 1, deviceId: 0, body: "vw\u{0}1\u{0}255"))

// Sync hardware state
_ = try await plynx.send(.hardwareSync(dashId: 1, target: nil))

// Sync app state
_ = try await plynx.send(.appSync(dashId: 1, widgetIds: nil))
```

### Tag Management

```swift
// Create tag
let tag = Tag(id: 100000, name: "Living Room", deviceIds: [0, 1])
_ = try await plynx.send(.createTag(dashId: 1, tag: tag))

// Get all tags
_ = try await plynx.send(.getTags(dashId: 1))

// Update tag
_ = try await plynx.send(.updateTag(dashId: 1, tag: tag))

// Delete tag
_ = try await plynx.send(.deleteTag(dashId: 1, tagId: 100000))
```

### Sharing

```swift
// Enable sharing
_ = try await plynx.send(.setSharing(dashId: 1, enabled: true))

// Get share token
_ = try await plynx.send(.getShareToken(dashId: 1))

// Refresh share token
_ = try await plynx.send(.refreshShareToken(dashId: 1))
```

### Graph Data

```swift
// Get enhanced graph data
_ = try await plynx.send(.getEnhancedGraphData(
    dashId: 1,
    deviceId: 0,
    dataStreams: [0],
    period: .day,
    page: nil
))

// Export graph data as CSV (sent via email)
_ = try await plynx.send(.exportGraphData(
    dashId: 1,
    widgetId: 1,
    pinType: .virtual,
    pin: 1,
    deviceId: 0
))

// Delete graph data
_ = try await plynx.send(.deleteEnhancedGraphData(dashId: 1, widgetId: 1, dataStreamIds: nil))
```

### Email

```swift
// Send device token via email
_ = try await plynx.send(.emailToken(dashId: 1, deviceId: 0))

// Send custom email
_ = try await plynx.send(.email(dashId: 1, deviceId: 0, to: "user@example.com", subject: "Test", body: "Hello!"))
```

### Energy (Credits)

```swift
// Get energy balance
_ = try await plynx.send(.getEnergy)

// Redeem promotional code
_ = try await plynx.send(.redeem(code: "PROMO123"))
```

## Error Handling

```swift
do {
    try await plynx.connect(email: "user@example.com", password: "wrong")
} catch PlynxError.authenticationFailed(let code) {
    print("Auth failed: \(code.description)")
} catch PlynxError.connectionFailed(let underlying) {
    print("Connection failed: \(underlying?.localizedDescription ?? "unknown")")
} catch PlynxError.timeout {
    print("Request timed out")
} catch {
    print("Other error: \(error)")
}
```

## Configuration

```swift
let plynx = PlynxConnector(host: "192.168.1.100", port: 9443)

// Set response timeout (default: 10 seconds)
plynx.responseTimeout = 15.0

// Set ping interval (default: 10 seconds)
plynx.pingInterval = 10.0
```

## Auto-Reconnection

The connector automatically handles reconnection with exponential backoff:
- Starts at 1 second delay
- Doubles on each attempt (1s, 2s, 4s, 8s, ...)
- Maximum delay: 60 seconds
- Maximum attempts: 10

You'll receive `.reconnecting(attempt:)` events during reconnection and `.reconnected` when successful.

## Thread Safety

`PlynxConnector` is an `actor`, making it safe to use from multiple tasks concurrently. All operations are automatically serialized.

## Protocol Details

- Uses binary TCP protocol over TLS (port 9443 by default)
- Messages: 1 byte command + 2 bytes message ID (big-endian) + 2 bytes length (big-endian) + body
- Body fields are separated by null character (`\0`)
- Server accepts self-signed certificates (configurable)

## File Structure

```
PlynxConnector/
├── Protocol/
│   ├── CommandCode.swift       # All command codes (40+)
│   ├── ResponseCode.swift      # Server response codes
│   └── BlynkMessage.swift      # Message serialization
├── Models/
│   ├── Enums/
│   │   ├── BoardType.swift     # Hardware board types
│   │   ├── WidgetType.swift    # Widget types (40+)
│   │   ├── WidgetProperty.swift
│   │   ├── PinType.swift
│   │   ├── GraphPeriod.swift
│   │   ├── DeviceStatus.swift
│   │   ├── ConnectionType.swift
│   │   └── Theme.swift
│   ├── Device.swift
│   ├── DashBoard.swift
│   ├── Widget.swift
│   ├── Tag.swift
│   ├── TileTemplate.swift
│   ├── Report.swift
│   └── App.swift
├── Actions/
│   └── Action.swift            # All possible actions
├── Events/
│   └── Event.swift             # All possible events
├── Transport/
│   └── PlynxSocket.swift       # SSL socket with reconnection
├── Utils/
│   ├── PlynxError.swift
│   └── GzipHelper.swift
└── PlynxConnector.swift        # Main public interface
```

## License

This connector is designed to work with the Plynx Server (GPL licensed).
