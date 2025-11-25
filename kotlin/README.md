# PlynxConnector for Kotlin/Android

🚧 **Coming Soon**

Kotlin client library for Plynx (Blynk Legacy) server.
Native Android support with coroutines.

## Planned Features

- Kotlin Coroutines support
- Flow-based events
- TLS/SSL connection
- Auto-reconnection
- Android lifecycle aware

## Planned Usage

```kotlin
import com.plynx.connector.PlynxConnector

val plynx = PlynxConnector(host = "192.168.1.100", port = 9443)

// Connect
plynx.connect(
    email = "user@example.com",
    password = "password",
    appName = "MyAndroidApp"
)

// Collect events
plynx.events.collect { event ->
    when (event) {
        is VirtualPinUpdate -> {
            println("V${event.pin} = ${event.values}")
        }
    }
}

// Write to virtual pin
plynx.send(WriteVirtualPin(dashId = 1, deviceId = 0, pin = 1, value = "255"))
```

## Gradle

```kotlin
dependencies {
    implementation("com.plynx:connector:1.0.0")
}
```

## License

**© 2025 NickP005. All Rights Reserved.**
