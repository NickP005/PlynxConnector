# PlynxConnector

Multi-platform client libraries for connecting to Plynx (Blynk Legacy) IoT servers.

## Available Platforms

| Platform | Directory | Package Manager | Status |
|----------|-----------|-----------------|--------|
| **iOS/macOS** | [`swift/`](./swift/) | SPM, CocoaPods | ✅ Ready |
| **Flutter** | [`dart/`](./dart/) | pub.dev | 🚧 Coming Soon |
| **Web/Node.js** | [`typescript/`](./typescript/) | npm | 🚧 Coming Soon |
| **Android** | [`kotlin/`](./kotlin/) | Maven | 🚧 Coming Soon |

## Features

All connectors provide:
- 🔐 Secure TLS/SSL connection
- 🔄 Automatic reconnection with exponential backoff
- 📡 Full protocol support (40+ commands)
- 📊 Real-time hardware updates
- 🎛️ Dashboard, device, and widget management

## Quick Start

### Swift (iOS/macOS)

```swift
let plynx = PlynxConnector(host: "192.168.1.100", port: 9443)
try await plynx.connect(email: "user@example.com", password: "pass", appName: "MyApp")
_ = try await plynx.send(.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255"))
```

### Dart (Flutter)
```dart
final plynx = PlynxConnector(host: '192.168.1.100', port: 9443);
await plynx.connect(email: 'user@example.com', password: 'pass', appName: 'MyApp');
await plynx.send(WriteVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: '255'));
```

### TypeScript (Web/Node.js)
```typescript
const plynx = new PlynxConnector({ host: '192.168.1.100', port: 9443 });
await plynx.connect({ email: 'user@example.com', password: 'pass', appName: 'MyApp' });
await plynx.send({ type: 'writeVirtualPin', dashId: 1, deviceId: 0, pin: 1, value: '255' });
```

## Legal Notice

These libraries are **independent clean-room implementations** of the Blynk communication protocol.

- ✅ No code copied from Blynk products
- ✅ Protocol reverse-engineered for interoperability (legal under EU/US law)
- ✅ APIs are not copyrightable (*Oracle v. Google*, 2021)

**Blynk** is a trademark of Blynk Inc. This project is not affiliated with Blynk Inc.

## License

**© 2025 NickP005. All Rights Reserved.**

See individual platform directories for specific licensing terms.
For licensing inquiries, contact the author.
