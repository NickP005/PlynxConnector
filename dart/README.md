# PlynxConnector for Dart/Flutter

🚧 **Coming Soon**

Flutter/Dart client library for Plynx (Blynk Legacy) server.

## Planned Features

- Secure TLS/SSL connection
- Automatic reconnection
- Full protocol support
- Stream-based events
- Null-safe Dart 3.0+

## Planned Usage

```dart
import 'package:plynx_connector/plynx_connector.dart';

final plynx = PlynxConnector(host: '192.168.1.100', port: 9443);

await plynx.connect(
  email: 'user@example.com',
  password: 'password',
  appName: 'MyFlutterApp',
);

// Listen for events
plynx.events.listen((event) {
  if (event is VirtualPinUpdate) {
    print('V${event.pin} = ${event.values}');
  }
});

// Write to virtual pin
await plynx.send(WriteVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: '255'));
```

## License

**© 2025 NickP005. All Rights Reserved.**
