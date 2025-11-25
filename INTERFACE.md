# PlynxConnector Interface Reference

## PlynxConnector

```swift
public actor PlynxConnector {
    // MARK: - Initialization
    init(host: String, port: UInt16 = 9443)
    
    // MARK: - Properties
    var authenticated: Bool { get }
    var socketConnected: Bool { get }
    var activeDashboardId: Int? { get }
    var isConnected: Bool { get async }
    var responseTimeout: TimeInterval
    var pingInterval: TimeInterval
    var events: AsyncStream<Event>
    
    // MARK: - Callbacks
    var onVirtualPinUpdate: ((Int, Int, Int, [String]) -> Void)?      // (dashId, deviceId, pin, values)
    var onDigitalPinUpdate: ((Int, Int, Int, Int) -> Void)?           // (dashId, deviceId, pin, value)
    var onAnalogPinUpdate: ((Int, Int, Int, Int) -> Void)?            // (dashId, deviceId, pin, value)
    var onWidgetPropertyChanged: ((Int, Int, Int, WidgetProperty, String) -> Void)?
    var onHardwareConnected: ((Int, Int) -> Void)?                    // (dashId, deviceId)
    var onHardwareDisconnected: ((Int, Int) -> Void)?                 // (dashId, deviceId)
    var onConnectionStateChanged: ((Bool, Bool) -> Void)?             // (connected, authenticated)
    var onHardwareMessage: ((Int, Int, String) -> Void)?              // (dashId, deviceId, body)
    
    // MARK: - Connection
    func connect(email: String, password: String, appName: String) async throws
    func connectWithShareToken(_ token: String) async throws
    func disconnect() async
    
    // MARK: - Actions
    func send(_ action: Action) async throws -> Event
    
    // MARK: - Convenience
    func activateDashboard(_ dashId: Int) async throws -> Event
    func deactivateAllDashboards() async throws -> Event
    func writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String) async throws -> Event
    func loadProfile() async throws -> Profile
}
```

---

## Action

```swift
public enum Action {
    // Authentication
    case register(email: String, password: String, appName: String)
    case login(email: String, password: String, appName: String)
    case logout(uid: String?)
    case getServer(email: String)
    
    // Profile
    case loadProfile(dashId: Int?, published: Bool)
    case saveProfile(profile: Data)
    case deleteProfile
    
    // Dashboard
    case createDashboard(dashboard: DashBoard, generateToken: Bool)
    case updateDashboard(dashboard: DashBoard)
    case deleteDashboard(dashId: Int)
    case activateDashboard(dashId: Int)
    case deactivateDashboard(dashId: Int?)
    
    // Device
    case createDevice(dashId: Int, device: Device)
    case updateDevice(dashId: Int, device: Device)
    case deleteDevice(dashId: Int, deviceId: Int)
    case getDevices(dashId: Int)
    case getDevice(dashId: Int, deviceId: Int)
    
    // Widget
    case createWidget(dashId: Int, widget: Widget, tileId: Int?)
    case updateWidget(dashId: Int, widget: Widget)
    case deleteWidget(dashId: Int, widgetId: Int)
    case loadWidget(dashId: Int, widgetId: Int)
    case setWidgetProperty(dashId: Int, deviceId: Int, pin: Int, property: WidgetProperty, value: String)
    
    // Tag
    case createTag(dashId: Int, tag: Tag)
    case updateTag(dashId: Int, tag: Tag)
    case deleteTag(dashId: Int, tagId: Int)
    case getTags(dashId: Int)
    
    // Token
    case refreshToken(dashId: Int, deviceId: Int)
    case getProvisionToken(dashId: Int, deviceId: Int)
    case assignProvisionToken(dashId: Int, deviceId: Int, token: String)
    
    // Hardware
    case hardware(dashId: Int, deviceId: Int, body: String)
    case writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String)
    case readVirtualPin(dashId: Int, deviceId: Int, pin: Int)
    case hardwareSync(dashId: Int, target: Int?)
    case appSync(dashId: Int, widgetIds: [Int]?)
    
    // Sharing
    case setSharing(dashId: Int, enabled: Bool)
    case getShareToken(dashId: Int)
    case refreshShareToken(dashId: Int)
    case shareLogin(token: String)
    
    // Graph
    case getEnhancedGraphData(dashId: Int, deviceId: Int, dataStreams: [Int], period: GraphPeriod, page: Int?)
    case deleteEnhancedGraphData(dashId: Int, widgetId: Int, dataStreamIds: [Int]?)
    case exportGraphData(dashId: Int, widgetId: Int, pinType: PinType, pin: Int, deviceId: Int)
    
    // Tile Template
    case createTileTemplate(dashId: Int, template: TileTemplate)
    case updateTileTemplate(dashId: Int, template: TileTemplate)
    case deleteTileTemplate(dashId: Int, templateId: Int)
    
    // Report
    case createReport(dashId: Int, report: Report)
    case updateReport(dashId: Int, report: Report)
    case deleteReport(dashId: Int, reportId: Int)
    case exportReport(dashId: Int, reportId: Int)
    
    // App
    case createApp(app: App)
    case updateApp(app: App)
    case deleteApp(appId: String)
    case getApps
    
    // Clone
    case getCloneCode(dashId: Int)
    case getProjectFromClone(token: String)
    
    // Email
    case email(dashId: Int, deviceId: Int, to: String, subject: String, body: String)
    case emailToken(dashId: Int, deviceId: Int)
    
    // Push
    case addPushToken(token: String, platform: String)
    
    // Energy
    case getEnergy
    case addEnergy(amount: Int)
    case redeem(code: String)
    
    // Misc
    case ping
}
```

---

## Event

```swift
public enum Event {
    // Connection
    case connected
    case disconnected(Error?)
    case reconnecting(attempt: Int)
    case reconnected
    
    // Authentication
    case loginSuccess
    case loginFailed(ResponseCode)
    case registered
    case registrationFailed(ResponseCode)
    case serverAddress(String)
    case loggedOut
    
    // Response
    case response(messageId: UInt16, code: ResponseCode)
    
    // Profile
    case profileLoaded(Data)
    
    // Device
    case deviceCreated(Device)
    case devicesLoaded([Device])
    case deviceLoaded(Device)
    case hardwareConnected(dashId: Int, deviceId: Int)
    case hardwareDisconnected(dashId: Int, deviceId: Int)
    
    // Tag
    case tagCreated(Tag)
    case tagsLoaded([Tag])
    
    // Widget
    case widgetLoaded(Widget)
    case widgetPropertyChanged(dashId: Int, deviceId: Int, pin: Int, property: WidgetProperty, value: String)
    
    // Token
    case tokenRefreshed(String)
    case provisionToken(Device)
    
    // Share
    case shareToken(String)
    
    // Graph
    case graphData(Data)
    case graphDataExported
    
    // Report
    case reportCreated(Report)
    case reportUpdated(Report)
    case reportExported(Report)
    
    // Clone
    case cloneCode(String)
    case projectFromClone(Data)
    
    // App
    case appCreated(App)
    
    // Energy
    case energyBalance(Int)
    case energyAdded
    case redeemed
    
    // Hardware
    case hardwareMessage(dashId: Int, deviceId: Int, body: String)
    case virtualPinUpdate(dashId: Int, deviceId: Int, pin: Int, values: [String])
    case digitalPinUpdate(dashId: Int, deviceId: Int, pin: Int, value: Int)
    case analogPinUpdate(dashId: Int, deviceId: Int, pin: Int, value: Int)
    
    // Sync
    case appSyncData(dashId: Int, body: String)
    
    // Sharing
    case sharingChanged(dashId: Int, active: Bool)
    case dashboardActivatedByOther(dashId: Int)
    case dashboardDeactivatedByOther(dashId: Int)
    
    // Notification
    case outdatedAppNotification(message: String)
    case emailSent
    case pushTokenAdded
    
    // Internal
    case internalMessage(String)
    case pong
}
```

---

## ResponseCode

```swift
public enum ResponseCode: UInt16 {
    case ok = 200
    case quotaLimit = 1
    case illegalCommand = 2
    case userNotRegistered = 3
    case userAlreadyRegistered = 4
    case userNotAuthenticated = 5
    case notAllowed = 6
    case deviceNotInNetwork = 7
    case noActiveDevice = 8
    case invalidToken = 9
    case deviceWentOffline = 10
    case illegalCommandBody = 11
    case getGraphDataException = 12
    case noDataException = 17
    case deviceIsOffline = 18
    case serverException = 19
    case notSupported = 20
    case energyLimit = 21
    case facebookUserLoginWithPass = 22
}
```

---

## CommandCode

```swift
public enum CommandCode: UInt8 {
    case register = 1
    case login = 2
    case saveProfile = 3
    case loadProfile = 5
    case ping = 6
    case activateDashboard = 7
    case deactivateDashboard = 8
    case refreshToken = 9
    case getToken = 10
    case tweet = 12
    case email = 13
    case notify = 14
    case bridge = 15
    case hardwareSync = 16
    case blynkInternal = 17
    case setWidgetProperty = 19
    case hardware = 20
    case hardwareLogin = 29
    case createDashboard = 21
    case updateDashboard = 22
    case deleteDashboard = 23
    case createWidget = 24
    case updateWidget = 25
    case deleteWidget = 26
    case addPushToken = 27
    case appSync = 28
    case getEnergy = 30
    case addEnergy = 31
    case getServer = 32
    case connectRedirect = 41
    case createDevice = 42
    case updateDevice = 43
    case deleteDevice = 44
    case getDevices = 45
    case createTag = 46
    case updateTag = 47
    case deleteTag = 48
    case getTags = 49
    case getEnhancedGraphData = 52
    case deleteEnhancedGraphData = 53
    case getCloneCode = 54
    case getProjectFromClone = 55
    case exportGraphData = 56
    case assignToken = 57
    case getProvisionToken = 58
    case setSharing = 59
    case getShareToken = 60
    case refreshShareToken = 61
    case shareLogin = 62
    case logout = 63
    case createTileTemplate = 64
    case updateTileTemplate = 65
    case deleteTileTemplate = 66
    case createReport = 67
    case updateReport = 68
    case deleteReport = 69
    case exportReport = 70
    case deviceOffline = 71
    case outdatedAppNotification = 72
    case hardwareConnected = 4
    case sharing = 26
    case createApp = 73
    case updateApp = 74
    case deleteApp = 75
    case getApps = 76
    case redeem = 77
}
```

---

## Data Structures

### Device
```swift
public struct Device: Codable {
    var id: Int
    var name: String
    var boardType: BoardType?
    var token: String?
    var status: DeviceStatus?
    var connectionType: ConnectionType?
    var lastOnlineTime: Int64?
    var disconnectTime: Int64?
    var firstConnectTime: Int64?
    var dataReceivedAt: Int64?
    var isUserIcon: Bool?
    var iconName: String?
    var metadata: DeviceMetadata?
}
```

### DashBoard
```swift
public struct DashBoard: Codable {
    var id: Int
    var name: String
    var theme: Theme?
    var isActive: Bool?
    var isShared: Bool?
    var widgets: [Widget]?
    var devices: [Device]?
    var tags: [Tag]?
}
```

### Widget
```swift
public struct Widget: Codable {
    var id: Int
    var type: WidgetType
    var x: Int?
    var y: Int?
    var width: Int?
    var height: Int?
    var label: String?
    var color: Int?
    var pin: Int?
    var pinType: PinType?
    var deviceId: Int?
    var min: Double?
    var max: Double?
    var value: String?
    var frequency: Int?
}
```

### Tag
```swift
public struct Tag: Codable {
    var id: Int
    var name: String
    var deviceIds: [Int]?
}
```

### TileTemplate
```swift
public struct TileTemplate: Codable {
    var id: Int
    var name: String?
    var widgets: [Widget]?
}
```

### Report
```swift
public struct Report: Codable {
    var id: Int
    var name: String?
    var reportType: String?
    var granularity: String?
}
```

### App
```swift
public struct App: Codable {
    var id: String
    var name: String?
    var icon: String?
    var provisionType: String?
}
```

---

## Enums

### BoardType
```swift
public enum BoardType: String, Codable {
    case ESP8266 = "ESP8266"
    case arduinoUno = "Arduino UNO"
    case nodeMCU = "NodeMCU"
    case raspberryPi3B = "Raspberry Pi 3 B"
    case wemosD1Mini = "WeMos D1 mini"
    case arduinoNano = "Arduino Nano"
    case arduinoMega = "Arduino Mega"
    case ESP32DevBoard = "ESP32 Dev Board"
    case wemosD1 = "WeMos D1"
    case genericBoard = "Generic Board"
    case raspberryPi2AB = "Raspberry Pi 2/A+/B+"
    case particlePhoton = "Particle Photon"
    case arduinoMKR1000 = "Arduino MKR1000"
    case arduino101 = "Arduino 101"
    case arduinoYun = "Arduino Yun"
    case raspberryPiABv2 = "Raspberry Pi A/B (Rev2)"
    case arduinoProMini = "Arduino Pro Mini"
    case arduinoLeonardo = "Arduino Leonardo"
    case raspberryPiBv1 = "Raspberry Pi B (Rev1)"
    case arduinoDue = "Arduino Due"
    case sparkFunBlynkBoard = "SparkFun Blynk Board"
    case orangePi = "Orange Pi"
    case bbcMicrobit = "BBC Micro:bit"
    case arduinoMini = "Arduino Mini"
    case arduinoMicro = "Arduino Micro"
    case onionOmega = "Onion Omega"
    case arduinoProMicro = "Arduino Pro Micro"
    case particleCore = "Particle Core"
    case sparkFunESP8266Thing = "SparkFun ESP8266 Thing"
    case stm32f103cBluePill = "STM32F103C Blue Pill"
    case wiPy = "WiPy"
    case particleElectron = "Particle Electron"
    case arduinoZero = "Arduino Zero"
    case intelEdison = "Intel Edison"
    case teensy3 = "Teensy 3"
    case linkItONE = "LinkIt ONE"
    case nanoPi = "NanoPi"
    case lightBlueBean = "LightBlue Bean"
    case intelGalileo = "Intel Galileo"
    case redBearLabBLENano = "RedBearLab BLE Nano"
    case redBearDuo = "RedBear Duo"
    case tiCC3200LaunchXL = "TI CC3200-LaunchXL"
    case digistumpOak = "Digistump Oak"
    case seeedWioLink = "Seeed Wio Link"
    case tiTivaCConnected = "TI Tiva C Connected"
    case samsungARTIK5 = "Samsung ARTIK 5"
    case microduinoCoreUSB = "Microduino CoreUSB"
    case espruinoPico = "Espruino Pico"
    case tinyDuino = "TinyDuino"
    case microduinoCorePlus = "Microduino Core+"
    case chipKITUno32 = "chipKIT Uno32"
    case theAirBoard = "The AirBoard"
    case microduinoCore = "Microduino Core"
    case simblee = "Simblee"
    case leMakerBananaPro = "LeMaker Banana Pro"
    case wildfireV2 = "Wildfire v2"
    case lightBlueBeanPlus = "LightBlue Bean+"
    case sparkFunPhotonRedBoard = "SparkFun Photon RedBoard"
    case microduinoCoreRF = "Microduino CoreRF"
    case redBearLabCC3200Mini = "RedBearLab CC3200/Mini"
    case bluz = "Bluz"
    case leMakerGuitar = "LeMaker Guitar"
    case panStampEspOutput = "panStamp esp-output"
    case digistumpDigispark = "Digistump Digispark"
    case redBearLabBlendMicro = "RedBearLab Blend Micro"
    case tiLM4F120LaunchPad = "TI LM4F120 LaunchPad"
    case wildfireV3 = "Wildfire v3"
    case wildfireV4 = "Wildfire v4"
    case konektDashPro = "Konekt Dash Pro"
}
```

### WidgetType
```swift
public enum WidgetType: String, Codable {
    // Controls
    case button = "BUTTON"
    case styledButton = "STYLED_BUTTON"
    case linkButton = "LINK_BUTTON"
    case textInput = "TEXT_INPUT"
    case numberInput = "NUMBER_INPUT"
    case slider = "SLIDER"
    case verticalSlider = "VERTICAL_SLIDER"
    case rgbPicker = "RGB"
    case timer = "TIMER"
    case twoAxisJoystick = "TWO_AXIS_JOYSTICK"
    case terminal = "TERMINAL"
    case step = "STEP"
    case verticalStep = "VERTICAL_STEP"
    case qrCode = "QR"
    case timeInput = "TIME_INPUT"
    case segmentedControl = "SEGMENTED_CONTROL"
    case switchWidget = "SWITCH"
    
    // Outputs
    case led = "LED"
    case digit4Display = "DIGIT4_DISPLAY"
    case labeledValueDisplay = "LABELED_VALUE_DISPLAY"
    case gauge = "GAUGE"
    case lcd = "LCD"
    case levelDisplay = "LEVEL_DISPLAY"
    case verticalLevelDisplay = "VERTICAL_LEVEL_DISPLAY"
    case video = "VIDEO"
    case enhancedGraph = "ENHANCED_GRAPH"
    
    // Sensors
    case gpsTrigger = "GPS_TRIGGER"
    case gpsStreaming = "GPS_STREAMING"
    case light = "LIGHT"
    case proximity = "PROXIMITY"
    case temperature = "TEMPERATURE"
    case accelerometer = "ACCELEROMETER"
    case gravity = "GRAVITY"
    case barometer = "BAROMETER"
    case humidity = "HUMIDITY"
    
    // Notifications
    case twitter = "TWITTER"
    case emailWidget = "EMAIL"
    case notification = "NOTIFICATION"
    case smsWidget = "SMS"
    
    // Interface
    case menu = "MENU"
    case tabs = "TABS"
    case player = "PLAYER"
    case table = "TABLE"
    case image = "IMAGE"
    case report = "REPORT"
    
    // Others
    case rtc = "RTC"
    case bridgeWidget = "BRIDGE"
    case bluetooth = "BLUETOOTH"
    case bluetoothSerial = "BLUETOOTH_SERIAL"
    case eventorWidget = "EVENTOR"
    case map = "MAP"
    case deviceSelector = "DEVICE_SELECTOR"
    case deviceTiles = "DEVICE_TILES"
    case text = "TEXT"
    case webhook = "WEBHOOK"
    case unknown = "UNKNOWN"
}
```

### WidgetProperty
```swift
public enum WidgetProperty: String, Codable {
    case label = "label"
    case color = "color"
    case onBackColor = "onBackColor"
    case offBackColor = "offBackColor"
    case onColor = "onColor"
    case offColor = "offColor"
    case onLabel = "onLabel"
    case offLabel = "offLabel"
    case labels = "labels"
    case min = "min"
    case max = "max"
    case isOnPlay = "isOnPlay"
    case url = "url"
    case urls = "urls"
    case step = "step"
    case valueFormatting = "valueFormatting"
    case suffix = "suffix"
    case maximumFractionDigits = "maximumFractionDigits"
    case opacity = "opacity"
    case scale = "scale"
    case rotation = "rotation"
}
```

### PinType
```swift
public enum PinType: String, Codable {
    case virtual = "VIRTUAL"
    case digital = "DIGITAL"
    case analog = "ANALOG"
}
```

### GraphPeriod
```swift
public enum GraphPeriod: String, Codable {
    case live = "LIVE"
    case hour = "ONE_HOUR"
    case sixHours = "SIX_HOURS"
    case day = "DAY"
    case week = "WEEK"
    case month = "MONTH"
    case threeMonths = "THREE_MONTHS"
}
```

### DeviceStatus
```swift
public enum DeviceStatus: String, Codable {
    case online = "ONLINE"
    case offline = "OFFLINE"
}
```

### ConnectionType
```swift
public enum ConnectionType: String, Codable {
    case wifi = "WI_FI"
    case ethernet = "ETHERNET"
    case bluetooth = "BLUETOOTH"
    case usb = "USB"
    case gsm = "GSM"
}
```

### Theme
```swift
public enum Theme: String, Codable {
    case light = "Blynk"
    case dark = "BlynkDark"
}
```

---

## PlynxError

```swift
public enum PlynxError: Error {
    case connectionFailed(Error?)
    case authenticationFailed(ResponseCode)
    case notConnected
    case timeout
    case invalidResponse
    case encodingError
    case connectionClosed
}
```
