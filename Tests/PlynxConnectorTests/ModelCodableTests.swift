import XCTest
@testable import PlynxConnector

final class ModelCodableTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Widget Tests

    func testWidgetMinimalRoundTrip() throws {
        let widget = Widget(id: 42)

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.id, 42)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.x)
        XCTAssertNil(decoded.label)
        XCTAssertNil(decoded.pin)
    }

    func testWidgetFullRoundTrip() throws {
        var widget = Widget(id: 1, type: .button)
        widget.x = 0
        widget.y = 0
        widget.width = 2
        widget.height = 2
        widget.label = "Test Button"
        widget.color = -1
        widget.deviceId = 0
        widget.pin = 5
        widget.pinType = .virtual
        widget.min = 0
        widget.max = 1
        widget.value = "1"
        widget.pushMode = true
        widget.onLabel = "ON"
        widget.offLabel = "OFF"
        widget.frequency = 1000
        widget.tabId = 0

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.type, .button)
        XCTAssertEqual(decoded.x, 0)
        XCTAssertEqual(decoded.y, 0)
        XCTAssertEqual(decoded.width, 2)
        XCTAssertEqual(decoded.height, 2)
        XCTAssertEqual(decoded.label, "Test Button")
        XCTAssertEqual(decoded.color, -1)
        XCTAssertEqual(decoded.deviceId, 0)
        XCTAssertEqual(decoded.pin, 5)
        XCTAssertEqual(decoded.pinType, .virtual)
        XCTAssertEqual(decoded.min, 0)
        XCTAssertEqual(decoded.max, 1)
        XCTAssertEqual(decoded.value, "1")
        XCTAssertEqual(decoded.pushMode, true)
        XCTAssertEqual(decoded.onLabel, "ON")
        XCTAssertEqual(decoded.offLabel, "OFF")
        XCTAssertEqual(decoded.frequency, 1000)
        XCTAssertEqual(decoded.tabId, 0)
    }

    func testWidgetFromServerJSON() throws {
        let json = """
        {"id":1,"type":"BUTTON","x":0,"y":0,"width":2,"height":2,"label":"My Button","color":-1,"deviceId":0,"pin":1,"pinType":"VIRTUAL","min":0,"max":1,"pushMode":false,"onLabel":"ON","offLabel":"OFF"}
        """.data(using: .utf8)!

        let widget = try decoder.decode(Widget.self, from: json)

        XCTAssertEqual(widget.id, 1)
        XCTAssertEqual(widget.type, .button)
        XCTAssertEqual(widget.x, 0)
        XCTAssertEqual(widget.y, 0)
        XCTAssertEqual(widget.width, 2)
        XCTAssertEqual(widget.height, 2)
        XCTAssertEqual(widget.label, "My Button")
        XCTAssertEqual(widget.color, -1)
        XCTAssertEqual(widget.deviceId, 0)
        XCTAssertEqual(widget.pin, 1)
        XCTAssertEqual(widget.pinType, .virtual)
        XCTAssertEqual(widget.min, 0)
        XCTAssertEqual(widget.max, 1)
        XCTAssertEqual(widget.pushMode, false)
        XCTAssertEqual(widget.onLabel, "ON")
        XCTAssertEqual(widget.offLabel, "OFF")
    }

    func testWidgetWithDataStreams() throws {
        var widget = Widget(id: 10, type: .enhancedGraph)
        widget.dataStreams = [
            DataStream(pin: 0, pinType: .virtual, min: 0, max: 100),
            DataStream(pin: 1, pinType: .virtual, min: -10, max: 50)
        ]
        widget.period = .day
        widget.showLegend = true

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.id, 10)
        XCTAssertEqual(decoded.type, .enhancedGraph)
        XCTAssertEqual(decoded.dataStreams?.count, 2)
        XCTAssertEqual(decoded.dataStreams?[0].pin, 0)
        XCTAssertEqual(decoded.dataStreams?[0].pinType, .virtual)
        XCTAssertEqual(decoded.dataStreams?[0].max, 100)
        XCTAssertEqual(decoded.dataStreams?[1].pin, 1)
        XCTAssertEqual(decoded.dataStreams?[1].min, -10)
        XCTAssertEqual(decoded.period, .day)
        XCTAssertEqual(decoded.showLegend, true)
    }

    func testWidgetWithEventorRules() throws {
        var widget = Widget(id: 20, type: .eventorWidget)
        let rule = EventorRule(
            triggerPin: EventorDataStream(pin: 5, pinType: .virtual),
            condition: EventorCondition(type: .greaterThan, value: 25.0),
            actions: [
                EventorAction(type: .setPin, pin: EventorDataStream(pin: 10, pinType: .virtual), value: "1")
            ],
            isActive: true
        )
        widget.rules = [rule]

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.id, 20)
        XCTAssertEqual(decoded.type, .eventorWidget)
        XCTAssertEqual(decoded.rules?.count, 1)
        XCTAssertEqual(decoded.rules?[0].triggerPin?.pin, 5)
        XCTAssertEqual(decoded.rules?[0].triggerPin?.pinType, .virtual)
        XCTAssertEqual(decoded.rules?[0].condition?.type, .greaterThan)
        XCTAssertEqual(decoded.rules?[0].condition?.value, 25.0)
        XCTAssertEqual(decoded.rules?[0].actions?.count, 1)
        XCTAssertEqual(decoded.rules?[0].actions?[0].type, .setPin)
        XCTAssertEqual(decoded.rules?[0].actions?[0].value, "1")
        XCTAssertEqual(decoded.rules?[0].isActive, true)
    }

    func testWidgetSliderProperties() throws {
        var widget = Widget(id: 30, type: .slider)
        widget.pin = 3
        widget.pinType = .virtual
        widget.min = 0
        widget.max = 1023
        widget.sendOnReleaseOn = false
        widget.valueFormatting = "/pin/ °C"
        widget.suffix = "°C"
        widget.maximumFractionDigits = 1

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.type, .slider)
        XCTAssertEqual(decoded.min, 0)
        XCTAssertEqual(decoded.max, 1023)
        XCTAssertEqual(decoded.sendOnReleaseOn, false)
        XCTAssertEqual(decoded.valueFormatting, "/pin/ °C")
        XCTAssertEqual(decoded.suffix, "°C")
        XCTAssertEqual(decoded.maximumFractionDigits, 1)
    }

    func testWidgetStepProperties() throws {
        var widget = Widget(id: 31, type: .step)
        widget.step = 0.5
        widget.isArrowsOn = true
        widget.isLoopOn = false
        widget.isSendStep = true
        widget.showValueOn = true

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.step, 0.5)
        XCTAssertEqual(decoded.isArrowsOn, true)
        XCTAssertEqual(decoded.isLoopOn, false)
        XCTAssertEqual(decoded.isSendStep, true)
        XCTAssertEqual(decoded.showValueOn, true)
    }

    func testWidgetTimerCodingKeys() throws {
        let json = """
        {"id":50,"type":"TIMER","startTime":3600,"stopTime":7200,"startValue":"1","stopValue":"0","days":127,"timezone":"Europe/Rome","pin":1,"pinType":"VIRTUAL"}
        """.data(using: .utf8)!

        let widget = try decoder.decode(Widget.self, from: json)

        XCTAssertEqual(widget.id, 50)
        XCTAssertEqual(widget.type, .timer)
        XCTAssertEqual(widget.startAt, 3600)
        XCTAssertEqual(widget.stopAt, 7200)
        XCTAssertEqual(widget.startValue, "1")
        XCTAssertEqual(widget.stopValue, "0")
        XCTAssertEqual(widget.days, 127)
        XCTAssertEqual(widget.timezone, "Europe/Rome")
    }

    func testWidgetStyledButtonStates() throws {
        var widget = Widget(id: 60, type: .styledButton)
        widget.onButtonState = ButtonState(text: "Running", textColor: 255, backgroundColor: 65280, iconName: "play")
        widget.offButtonState = ButtonState(text: "Stopped", textColor: 16711680, backgroundColor: 0)

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.onButtonState?.text, "Running")
        XCTAssertEqual(decoded.onButtonState?.textColor, 255)
        XCTAssertEqual(decoded.onButtonState?.backgroundColor, 65280)
        XCTAssertEqual(decoded.onButtonState?.iconName, "play")
        XCTAssertEqual(decoded.offButtonState?.text, "Stopped")
        XCTAssertEqual(decoded.offButtonState?.textColor, 16711680)
    }

    func testWidgetRGBPickerUsePinsKey() throws {
        let json = """
        {"id":70,"type":"RGB","pins":[{"pin":0,"pinType":"VIRTUAL","min":0,"max":255},{"pin":1,"pinType":"VIRTUAL","min":0,"max":255},{"pin":2,"pinType":"VIRTUAL","min":0,"max":255}],"splitMode":true}
        """.data(using: .utf8)!

        let widget = try decoder.decode(Widget.self, from: json)

        XCTAssertEqual(widget.id, 70)
        XCTAssertEqual(widget.type, .rgbPicker)
        XCTAssertEqual(widget.dataStreams?.count, 3)
        XCTAssertEqual(widget.dataStreams?[0].pin, 0)
        XCTAssertEqual(widget.dataStreams?[2].max, 255)
        XCTAssertEqual(widget.splitMode, true)
    }

    func testWidgetTerminalProperties() throws {
        var widget = Widget(id: 80, type: .terminal)
        widget.autoScrollOn = true
        widget.textInputOn = true
        widget.textLightOn = false

        let data = try encoder.encode(widget)
        let decoded = try decoder.decode(Widget.self, from: data)

        XCTAssertEqual(decoded.autoScrollOn, true)
        XCTAssertEqual(decoded.textInputOn, true)
        XCTAssertEqual(decoded.textLightOn, false)
    }

    // MARK: - DashBoard Tests

    func testDashBoardMinimalRoundTrip() throws {
        let board = DashBoard()

        let data = try encoder.encode(board)
        let decoded = try decoder.decode(DashBoard.self, from: data)

        XCTAssertEqual(decoded.id, 0)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.widgets)
        XCTAssertNil(decoded.devices)
    }

    func testDashBoardFullRoundTrip() throws {
        var board = DashBoard(id: 999, name: "Smart Home")
        board.parentId = -1
        board.isPreview = false
        board.createdAt = 1700000000000
        board.updatedAt = 1700001000000
        board.theme = .blynk
        board.keepScreenOn = true
        board.isAppConnectedOn = true
        board.isNotificationsOff = false
        board.isShared = false
        board.isActive = true
        board.widgetBackgroundOn = true
        board.color = 0
        board.isDefaultColor = true

        let data = try encoder.encode(board)
        let decoded = try decoder.decode(DashBoard.self, from: data)

        XCTAssertEqual(decoded.id, 999)
        XCTAssertEqual(decoded.name, "Smart Home")
        XCTAssertEqual(decoded.parentId, -1)
        XCTAssertEqual(decoded.isPreview, false)
        XCTAssertEqual(decoded.createdAt, 1700000000000)
        XCTAssertEqual(decoded.updatedAt, 1700001000000)
        XCTAssertEqual(decoded.theme, .blynk)
        XCTAssertEqual(decoded.keepScreenOn, true)
        XCTAssertEqual(decoded.isAppConnectedOn, true)
        XCTAssertEqual(decoded.isNotificationsOff, false)
        XCTAssertEqual(decoded.isShared, false)
        XCTAssertEqual(decoded.isActive, true)
        XCTAssertEqual(decoded.widgetBackgroundOn, true)
        XCTAssertEqual(decoded.color, 0)
        XCTAssertEqual(decoded.isDefaultColor, true)
    }

    func testDashBoardFromServerJSON() throws {
        let json = """
        {"id":123456,"name":"My Project","theme":"Blynk","keepScreenOn":false,"isAppConnectedOn":false,"isNotificationsOff":false,"isShared":false,"isActive":false,"widgetBackgroundOn":false,"color":0,"isDefaultColor":true}
        """.data(using: .utf8)!

        let board = try decoder.decode(DashBoard.self, from: json)

        XCTAssertEqual(board.id, 123456)
        XCTAssertEqual(board.name, "My Project")
        XCTAssertEqual(board.theme, .blynk)
        XCTAssertEqual(board.keepScreenOn, false)
        XCTAssertEqual(board.isAppConnectedOn, false)
        XCTAssertEqual(board.isNotificationsOff, false)
        XCTAssertEqual(board.isShared, false)
        XCTAssertEqual(board.isActive, false)
        XCTAssertEqual(board.widgetBackgroundOn, false)
        XCTAssertEqual(board.color, 0)
        XCTAssertEqual(board.isDefaultColor, true)
    }

    func testDashBoardWithWidgetsAndDevices() throws {
        var board = DashBoard(id: 1, name: "IoT")
        var button = Widget(id: 1, type: .button)
        button.pin = 0
        button.pinType = .virtual
        var slider = Widget(id: 2, type: .slider)
        slider.pin = 1
        slider.pinType = .virtual
        board.widgets = [button, slider]
        board.devices = [
            Device(id: 0, name: "ESP8266", boardType: .ESP8266, token: "abc"),
            Device(id: 1, name: "Arduino", boardType: .arduinoUno, token: "def")
        ]
        board.tags = [Tag(id: 100_000, name: "Living Room", deviceIds: [0, 1])]

        let data = try encoder.encode(board)
        let decoded = try decoder.decode(DashBoard.self, from: data)

        XCTAssertEqual(decoded.widgets?.count, 2)
        XCTAssertEqual(decoded.widgets?[0].type, .button)
        XCTAssertEqual(decoded.widgets?[1].type, .slider)
        XCTAssertEqual(decoded.devices?.count, 2)
        XCTAssertEqual(decoded.devices?[0].name, "ESP8266")
        XCTAssertEqual(decoded.devices?[1].boardType, .arduinoUno)
        XCTAssertEqual(decoded.tags?.count, 1)
        XCTAssertEqual(decoded.tags?[0].name, "Living Room")
        XCTAssertEqual(decoded.tags?[0].deviceIds, [0, 1])
    }

    // MARK: - Device Tests

    func testDeviceMinimalRoundTrip() throws {
        let device = Device(id: 0)

        let data = try encoder.encode(device)
        let decoded = try decoder.decode(Device.self, from: data)

        XCTAssertEqual(decoded.id, 0)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.boardType)
        XCTAssertNil(decoded.token)
        XCTAssertNil(decoded.status)
    }

    func testDeviceFullRoundTrip() throws {
        var device = Device(id: 0, name: "ESP32", boardType: .ESP32DevBoard, token: "longtoken123")
        device.connectionType = .wifi
        device.status = .online
        device.disconnectTime = 1700000000000
        device.connectTime = 1700000500000
        device.firstConnectTime = 1690000000000
        device.lastLoggedIP = "192.168.1.100"
        device.iconName = "chip"
        device.isUserIcon = false

        let data = try encoder.encode(device)
        let decoded = try decoder.decode(Device.self, from: data)

        XCTAssertEqual(decoded.id, 0)
        XCTAssertEqual(decoded.name, "ESP32")
        XCTAssertEqual(decoded.boardType, .ESP32DevBoard)
        XCTAssertEqual(decoded.token, "longtoken123")
        XCTAssertEqual(decoded.connectionType, .wifi)
        XCTAssertEqual(decoded.status, .online)
        XCTAssertEqual(decoded.disconnectTime, 1700000000000)
        XCTAssertEqual(decoded.connectTime, 1700000500000)
        XCTAssertEqual(decoded.firstConnectTime, 1690000000000)
        XCTAssertEqual(decoded.lastLoggedIP, "192.168.1.100")
        XCTAssertEqual(decoded.iconName, "chip")
        XCTAssertEqual(decoded.isUserIcon, false)
    }

    func testDeviceFromServerJSON() throws {
        let json = """
        {"id":0,"name":"ESP8266","boardType":"ESP8266","connectionType":"WI_FI","token":"abc123token","status":"OFFLINE","disconnectTime":1700000000000,"lastLoggedIP":"10.0.0.5"}
        """.data(using: .utf8)!

        let device = try decoder.decode(Device.self, from: json)

        XCTAssertEqual(device.id, 0)
        XCTAssertEqual(device.name, "ESP8266")
        XCTAssertEqual(device.boardType, .ESP8266)
        XCTAssertEqual(device.connectionType, .wifi)
        XCTAssertEqual(device.token, "abc123token")
        XCTAssertEqual(device.status, .offline)
        XCTAssertEqual(device.disconnectTime, 1700000000000)
        XCTAssertEqual(device.lastLoggedIP, "10.0.0.5")
    }

    func testDeviceWithHardwareInfo() throws {
        var device = Device(id: 1, name: "NodeMCU")
        var hwInfo = HardwareInfo()
        hwInfo.version = "0.6.1"
        hwInfo.blynkVersion = "1.2.0"
        hwInfo.boardType = "ESP8266"
        hwInfo.cpuType = "Xtensa"
        hwInfo.connectionType = "WI_FI"
        device.hardwareInfo = hwInfo

        let data = try encoder.encode(device)
        let decoded = try decoder.decode(Device.self, from: data)

        XCTAssertEqual(decoded.hardwareInfo?.version, "0.6.1")
        XCTAssertEqual(decoded.hardwareInfo?.blynkVersion, "1.2.0")
        XCTAssertEqual(decoded.hardwareInfo?.boardType, "ESP8266")
        XCTAssertEqual(decoded.hardwareInfo?.cpuType, "Xtensa")
    }

    // MARK: - Profile Tests

    func testProfileEmptyRoundTrip() throws {
        let profile = Profile()

        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(Profile.self, from: data)

        XCTAssertNil(decoded.dashBoards)
        XCTAssertNil(decoded.apps)
    }

    func testProfileWithDashBoards() throws {
        var profile = Profile()
        profile.dashBoards = [
            DashBoard(id: 1, name: "Home"),
            DashBoard(id: 2, name: "Office")
        ]

        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(Profile.self, from: data)

        XCTAssertEqual(decoded.dashBoards?.count, 2)
        XCTAssertEqual(decoded.dashBoards?[0].id, 1)
        XCTAssertEqual(decoded.dashBoards?[0].name, "Home")
        XCTAssertEqual(decoded.dashBoards?[1].id, 2)
        XCTAssertEqual(decoded.dashBoards?[1].name, "Office")
    }

    func testProfileFromServerJSON() throws {
        let json = """
        {"dashBoards":[{"id":1,"name":"Project One","theme":"Blynk","isActive":true,"widgets":[{"id":1,"type":"BUTTON","pin":0,"pinType":"VIRTUAL"}],"devices":[{"id":0,"name":"ESP","boardType":"ESP8266","token":"tok1"}]}],"apps":[{"id":1,"name":"My App"}]}
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        XCTAssertEqual(profile.dashBoards?.count, 1)
        XCTAssertEqual(profile.dashBoards?[0].name, "Project One")
        XCTAssertEqual(profile.dashBoards?[0].isActive, true)
        XCTAssertEqual(profile.dashBoards?[0].widgets?.count, 1)
        XCTAssertEqual(profile.dashBoards?[0].widgets?[0].type, .button)
        XCTAssertEqual(profile.dashBoards?[0].devices?.count, 1)
        XCTAssertEqual(profile.dashBoards?[0].devices?[0].name, "ESP")
        XCTAssertEqual(profile.apps?.count, 1)
        XCTAssertEqual(profile.apps?[0].name, "My App")
    }

    func testProfileWithApps() throws {
        var profile = Profile()
        var app = App(id: 1, name: "Plynx App")
        app.theme = .blynkLight
        app.provisionType = .staticProvision
        app.projectIds = [1, 2, 3]
        app.color = 255
        app.isPublished = true
        profile.apps = [app]

        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(Profile.self, from: data)

        XCTAssertEqual(decoded.apps?.count, 1)
        XCTAssertEqual(decoded.apps?[0].name, "Plynx App")
        XCTAssertEqual(decoded.apps?[0].theme, .blynkLight)
        XCTAssertEqual(decoded.apps?[0].provisionType, .staticProvision)
        XCTAssertEqual(decoded.apps?[0].projectIds, [1, 2, 3])
        XCTAssertEqual(decoded.apps?[0].isPublished, true)
    }

    // MARK: - Tag Tests

    func testTagRoundTrip() throws {
        let tag = Tag(id: 100_001, name: "Bedroom", deviceIds: [0, 1, 2])

        let data = try encoder.encode(tag)
        let decoded = try decoder.decode(Tag.self, from: data)

        XCTAssertEqual(decoded.id, 100_001)
        XCTAssertEqual(decoded.name, "Bedroom")
        XCTAssertEqual(decoded.deviceIds, [0, 1, 2])
    }

    func testTagMinimumIdEnforced() throws {
        let tag = Tag(id: 5, name: "Low ID")

        XCTAssertEqual(tag.id, Tag.minimumId)

        let data = try encoder.encode(tag)
        let decoded = try decoder.decode(Tag.self, from: data)

        XCTAssertEqual(decoded.id, 100_000)
    }

    // MARK: - Enum Tests

    func testWidgetTypeAllCases() throws {
        let representativeCases: [WidgetType] = [
            .button, .styledButton, .slider, .verticalSlider,
            .led, .digit4Display, .gauge, .lcd,
            .enhancedGraph, .terminal, .timer, .step,
            .rgbPicker, .twoAxisJoystick, .menu, .tabs,
            .table, .image, .report, .map,
            .eventorWidget, .deviceTiles, .notification
        ]

        for widgetType in representativeCases {
            let data = try encoder.encode(widgetType)
            let decoded = try decoder.decode(WidgetType.self, from: data)
            XCTAssertEqual(decoded, widgetType, "Failed round-trip for \(widgetType)")
        }
    }

    func testPinTypeCodable() throws {
        for pinType in [PinType.virtual, .digital, .analog] {
            let data = try encoder.encode(pinType)
            let decoded = try decoder.decode(PinType.self, from: data)
            XCTAssertEqual(decoded, pinType)
        }

        let virtualJSON = "\"VIRTUAL\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(PinType.self, from: virtualJSON), .virtual)

        let digitalJSON = "\"DIGITAL\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(PinType.self, from: digitalJSON), .digital)

        let analogJSON = "\"ANALOG\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(PinType.self, from: analogJSON), .analog)
    }

    func testThemeCodable() throws {
        for theme in [Theme.blynk, .blynkLight, .sparkFun] {
            let data = try encoder.encode(theme)
            let decoded = try decoder.decode(Theme.self, from: data)
            XCTAssertEqual(decoded, theme)
        }

        let blynkJSON = "\"Blynk\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(Theme.self, from: blynkJSON), .blynk)
    }

    func testDeviceStatusCodable() throws {
        for status in [DeviceStatus.online, .offline] {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(DeviceStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }

        let onlineJSON = "\"ONLINE\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(DeviceStatus.self, from: onlineJSON), .online)
    }

    func testConnectionTypeCodable() throws {
        for ct in [ConnectionType.wifi, .ethernet, .usb, .bluetooth, .ble, .gsm] {
            let data = try encoder.encode(ct)
            let decoded = try decoder.decode(ConnectionType.self, from: data)
            XCTAssertEqual(decoded, ct)
        }

        let wifiJSON = "\"WI_FI\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(ConnectionType.self, from: wifiJSON), .wifi)
    }

    func testBoardTypeCodable() throws {
        let cases: [BoardType] = [.ESP8266, .arduinoUno, .nodeMCU, .raspberryPi3B, .ESP32DevBoard, .genericBoard]

        for board in cases {
            let data = try encoder.encode(board)
            let decoded = try decoder.decode(BoardType.self, from: data)
            XCTAssertEqual(decoded, board)
        }

        let espJSON = "\"ESP8266\"".data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(BoardType.self, from: espJSON), .ESP8266)
    }

    func testGraphPeriodCodable() throws {
        let periods: [GraphPeriod] = [.live, .oneHour, .sixHours, .day, .week, .month, .threeMonths]

        for period in periods {
            let data = try encoder.encode(period)
            let decoded = try decoder.decode(GraphPeriod.self, from: data)
            XCTAssertEqual(decoded, period)
        }
    }

    func testWidgetPropertyCodable() throws {
        let properties: [WidgetProperty] = [.label, .color, .min, .max, .url, .step, .suffix, .labels]

        for property in properties {
            let data = try encoder.encode(property)
            let decoded = try decoder.decode(WidgetProperty.self, from: data)
            XCTAssertEqual(decoded, property)
        }
    }

    // MARK: - Edge Cases

    func testWidgetUnknownTypeDecodesGracefully() throws {
        let json = """
        {"id":99,"type":"FUTURE_WIDGET_2030","x":0,"y":0}
        """.data(using: .utf8)!

        let widget = try decoder.decode(Widget.self, from: json)

        XCTAssertEqual(widget.id, 99)
        XCTAssertEqual(widget.type, .unknown)
        XCTAssertEqual(widget.x, 0)
    }

    func testWidgetNullFieldsDecoded() throws {
        let json = """
        {"id":5,"type":null,"label":null,"pin":null,"value":null}
        """.data(using: .utf8)!

        let widget = try decoder.decode(Widget.self, from: json)

        XCTAssertEqual(widget.id, 5)
        XCTAssertNil(widget.type)
        XCTAssertNil(widget.label)
        XCTAssertNil(widget.pin)
        XCTAssertNil(widget.value)
    }

    func testDashBoardEmptyWidgetsArray() throws {
        let json = """
        {"id":10,"name":"Empty Board","widgets":[],"devices":[]}
        """.data(using: .utf8)!

        let board = try decoder.decode(DashBoard.self, from: json)

        XCTAssertEqual(board.id, 10)
        XCTAssertEqual(board.name, "Empty Board")
        XCTAssertEqual(board.widgets?.count, 0)
        XCTAssertEqual(board.devices?.count, 0)
    }

    func testProfileNullDashBoards() throws {
        let json = """
        {"dashBoards":null,"apps":null}
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        XCTAssertNil(profile.dashBoards)
        XCTAssertNil(profile.apps)
    }

    func testBoardTypeUnknownFallsBackToGeneric() throws {
        let json = "\"Totally Unknown Board XYZ\"".data(using: .utf8)!
        let board = try decoder.decode(BoardType.self, from: json)
        XCTAssertEqual(board, .genericBoard)
    }

    func testDataStreamNestedGraphFormat() throws {
        let json = """
        {"id":1,"pin":{"pin":5,"pinType":"VIRTUAL","min":0,"max":1023},"title":"Temperature","graphType":"LINE","color":-1,"targetId":0,"functionType":"AVG"}
        """.data(using: .utf8)!

        let stream = try decoder.decode(DataStream.self, from: json)

        XCTAssertEqual(stream.pin, 5)
        XCTAssertEqual(stream.dataStream?.pin, 5)
        XCTAssertEqual(stream.dataStream?.pinType, .virtual)
        XCTAssertEqual(stream.dataStream?.min, 0)
        XCTAssertEqual(stream.dataStream?.max, 1023)
        XCTAssertEqual(stream.title, "Temperature")
        XCTAssertEqual(stream.graphType, "LINE")
        XCTAssertEqual(stream.functionType, "AVG")
        XCTAssertEqual(stream.targetId, 0)
    }

    func testComplexServerProfileJSON() throws {
        let json = """
        {
          "dashBoards": [
            {
              "id": 100,
              "name": "Home Automation",
              "theme": "Blynk",
              "isActive": true,
              "keepScreenOn": false,
              "widgets": [
                {"id":1,"type":"BUTTON","x":0,"y":0,"width":2,"height":1,"pin":0,"pinType":"VIRTUAL","min":0,"max":1,"deviceId":0},
                {"id":2,"type":"SLIDER","x":0,"y":1,"width":4,"height":1,"pin":1,"pinType":"VIRTUAL","min":0,"max":100,"deviceId":0},
                {"id":3,"type":"DIGIT4_DISPLAY","x":0,"y":2,"width":2,"height":1,"pin":2,"pinType":"VIRTUAL","deviceId":0}
              ],
              "devices": [
                {"id":0,"name":"ESP32","boardType":"ESP32 Dev Board","connectionType":"WI_FI","token":"tok123","status":"ONLINE"}
              ],
              "tags": [
                {"id":100000,"name":"All Devices","deviceIds":[0]}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        XCTAssertEqual(profile.dashBoards?.count, 1)

        let dash = profile.dashBoards![0]
        XCTAssertEqual(dash.id, 100)
        XCTAssertEqual(dash.name, "Home Automation")
        XCTAssertEqual(dash.theme, .blynk)
        XCTAssertEqual(dash.isActive, true)
        XCTAssertEqual(dash.widgets?.count, 3)
        XCTAssertEqual(dash.widgets?[0].type, .button)
        XCTAssertEqual(dash.widgets?[1].type, .slider)
        XCTAssertEqual(dash.widgets?[1].max, 100)
        XCTAssertEqual(dash.widgets?[2].type, .digit4Display)
        XCTAssertEqual(dash.devices?.count, 1)
        XCTAssertEqual(dash.devices?[0].boardType, .ESP32DevBoard)
        XCTAssertEqual(dash.devices?[0].status, .online)
        XCTAssertEqual(dash.tags?.count, 1)
        XCTAssertEqual(dash.tags?[0].id, 100_000)
    }
}
