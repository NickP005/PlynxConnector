# PlynxConnector - Swift iOS Connector for Plynx Server

## Overview

PlynxConnector is a Swift library that provides a complete interface to the Plynx (Blynk) server using the binary TCP/SSL protocol. It supports all 40+ commands available to mobile apps, with fully typed Swift models for dashboards, widgets, devices, and tags.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 13+

## Architecture

```
PlynxConnector/
├── Protocol/
│   ├── CommandCode.swift       # All 40+ command codes
│   ├── ResponseCode.swift      # Server response codes
│   └── BlynkMessage.swift      # Message structure & serialization
├── Models/
│   ├── Enums/
│   │   ├── BoardType.swift     # Hardware board types (ESP8266, etc.)
│   │   ├── WidgetType.swift    # Widget types (button, slider, etc.)
│   │   ├── WidgetProperty.swift # Widget properties (label, color, etc.)
│   │   ├── PinType.swift       # Pin types (virtual, digital, analog)
│   │   ├── GraphPeriod.swift   # Graph data periods
│   │   ├── DeviceStatus.swift  # Online/offline status
│   │   ├── ConnectionType.swift # WiFi, ethernet, etc.
│   │   └── Theme.swift         # Dashboard themes
│   ├── Device.swift            # Device model
│   ├── DashBoard.swift         # Dashboard model
│   ├── Widget.swift            # Widget model (with all subtypes)
│   ├── Tag.swift               # Tag model
│   ├── TileTemplate.swift      # DeviceTiles template model
│   ├── Report.swift            # Report model
│   ├── App.swift               # App configuration model
│   ├── DataStream.swift        # Data stream for graphs
│   └── HardwareInfo.swift      # Hardware info model
├── Actions/
│   └── Action.swift            # All possible actions (40+)
├── Events/
│   └── Event.swift             # All possible events
├── Transport/
│   └── PlynxSocket.swift       # SSL socket with auto-reconnection
├── Utils/
│   ├── BigEndian.swift         # Big-endian encoding helpers
│   ├── GzipHelper.swift        # Gzip decompression
│   └── PlynxError.swift        # Error types
└── PlynxConnector.swift        # Main public interface

README.md                       # Usage documentation
```

## Protocol Details

### Message Format (Mobile App ↔ Server)

| Field      | Size    | Description                          |
|------------|---------|--------------------------------------|
| Command    | 1 byte  | Command code (unsigned)              |
| Message ID | 2 bytes | Big-endian, unique per message       |
| Length     | 2 bytes | Big-endian, body length (or status)  |
| Body       | Variable| UTF-8 string, fields separated by \0 |

### Connection Flow

1. Open TLS connection to server (default port 9443)
2. Send LOGIN command with email\0password\0appName
3. Receive RESPONSE with code 200 (OK)
4. Start ping timer (every 10s)
5. Send/receive commands as needed

### Auto-Reconnection

- On disconnect: exponential backoff (1s, 2s, 4s, 8s, ... max 60s)
- Re-authenticate automatically on reconnect
- Queue actions during reconnection
- Emit `.reconnecting(attempt:)` events

## Command Reference

### Authentication (6 commands)
- `REGISTER (1)`: Register new account
- `LOGIN (2)`: Login with email/password
- `SHARE_LOGIN (32)`: Login with share token
- `LOGOUT (66)`: Logout
- `RESET_PASSWORD (81)`: Password reset flow
- `GET_SERVER (40)`: Get user's server

### Dashboard Management (6 commands)
- `CREATE_DASH (21)`: Create dashboard
- `UPDATE_DASH (22)`: Update dashboard
- `DELETE_DASH (23)`: Delete dashboard
- `ACTIVATE_DASHBOARD (7)`: Activate dashboard
- `DEACTIVATE_DASHBOARD (8)`: Deactivate dashboard
- `UPDATE_PROJECT_SETTINGS (38)`: Update settings only

### Widget Management (5 commands)
- `CREATE_WIDGET (33)`: Create widget
- `UPDATE_WIDGET (34)`: Update widget
- `DELETE_WIDGET (35)`: Delete widget
- `GET_WIDGET (70)`: Get widget by ID
- `SET_WIDGET_PROPERTY (19)`: Set widget property

### Device Management (6 commands)
- `CREATE_DEVICE (42)`: Create device
- `UPDATE_DEVICE (43)`: Update device
- `DELETE_DEVICE (44)`: Delete device
- `GET_DEVICES (45)`: Get all devices
- `MOBILE_GET_DEVICE (50)`: Get single device
- `DELETE_DEVICE_DATA (76)`: Delete device data

### Tag Management (4 commands)
- `CREATE_TAG (46)`: Create tag
- `UPDATE_TAG (47)`: Update tag
- `DELETE_TAG (48)`: Delete tag
- `GET_TAGS (49)`: Get all tags

### Token Management (3 commands)
- `REFRESH_TOKEN (9)`: Refresh device token
- `ASSIGN_TOKEN (39)`: Assign pre-flashed token
- `GET_PROVISION_TOKEN (74)`: Get provision token

### Hardware Communication (4 commands)
- `HARDWARE (20)`: Send hardware command
- `HARDWARE_SYNC (16)`: Sync hardware state
- `APP_SYNC (25)`: Sync app state
- `HARDWARE_RESEND_FROM_BLUETOOTH (65)`: Bluetooth relay

### Sharing (3 commands)
- `SHARING (26)`: Enable/disable sharing
- `GET_SHARE_TOKEN (30)`: Get share token
- `REFRESH_SHARE_TOKEN (31)`: Refresh share token

### Graph & Reports (8 commands)
- `LOAD_PROFILE_GZIPPED (24)`: Load profile
- `GET_ENHANCED_GRAPH_DATA (60)`: Get graph data
- `DELETE_ENHANCED_GRAPH_DATA (61)`: Delete graph data
- `EXPORT_GRAPH_DATA (28)`: Export as CSV email
- `CREATE_REPORT (77)`: Create report
- `UPDATE_REPORT (78)`: Update report
- `DELETE_REPORT (79)`: Delete report
- `EXPORT_REPORT (80)`: Export report

### Other Commands
- `EMAIL (13)`: Send email
- `EMAIL_QR (59)`: Email QR codes
- `ADD_PUSH_TOKEN (27)`: Register push token
- `PING (6)`: Keep-alive
- `GET_ENERGY (36)`: Get energy balance
- `ADD_ENERGY (37)`: Purchase energy
- `REDEEM (3)`: Redeem promo code
- `GET_CLONE_CODE (62)`: Get clone code
- `GET_PROJECT_BY_CLONE_CODE (63)`: Clone project
- `CREATE/UPDATE/DELETE_APP (55-57)`: App management
- `CREATE/UPDATE/DELETE_TILE_TEMPLATE (67-69)`: Tile templates

## Usage Example

```swift
import Foundation

// Create connector
let plynx = PlynxConnector(host: "192.168.1.100", port: 9443)

// Connect and login
Task {
    do {
        try await plynx.connect(email: "user@example.com", password: "mypassword")
        print("Connected!")
        
        // Listen for events
        Task {
            for await event in plynx.events {
                switch event {
                case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
                    print("Pin V\(pin) updated: \(values)")
                case .hardwareConnected(let dashId, let deviceId):
                    print("Device \(deviceId) connected")
                case .disconnected(let error):
                    print("Disconnected: \(error?.localizedDescription ?? "unknown")")
                default:
                    break
                }
            }
        }
        
        // Load profile
        let profileEvent = try await plynx.send(.loadProfile(dashId: nil, published: false))
        
        // Activate dashboard
        _ = try await plynx.send(.activateDashboard(dashId: 1))
        
        // Write to virtual pin
        _ = try await plynx.send(.hardware(dashId: 1, deviceId: 0, body: "vw\u{0}1\u{0}255"))
        
        // Create a new device
        let device = Device(id: 0, name: "My ESP8266", boardType: .ESP8266)
        let createEvent = try await plynx.send(.createDevice(dashId: 1, device: device))
        if case .deviceCreated(let newDevice) = createEvent {
            print("Created device with token: \(newDevice.token ?? "none")")
        }
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Integration Instructions

1. Copy the entire `PlynxConnector/` folder into your Xcode project
2. Make sure all files are added to your target
3. Import and use:
   ```swift
   // In your Swift file
   let connector = PlynxConnector(host: "your-server-ip", port: 9443)
   ```

## Notes

- The server uses self-signed certificates by default. The connector is configured to accept them.
- Only one dashboard can be active at a time on the server side.
- Virtual pin writes use format: `vw\0{pin}\0{value}`
- Virtual pin reads use format: `vr\0{pin}`
- The `\0` character is the null byte (ASCII 0) used as field separator.

## License

This connector is designed to work with the Plynk Server (GPL licensed).
