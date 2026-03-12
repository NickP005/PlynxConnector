import XCTest
@testable import PlynxConnector

final class MessageParserTests: XCTestCase {
    
    func testParseResponseMessage() {
        let parser = MessageParser()
        
        var data = Data()
        data.append(CommandCode.response.rawValue) // command = 0
        data.append(0) // msgId high
        data.append(5) // msgId low = 5
        data.append(0) // length/status byte 1
        data.append(0) // length/status byte 2
        data.append(0) // length/status byte 3
        data.append(200) // length/status byte 4 = 200 (OK)
        
        parser.append(data)
        let messages = parser.parseAll()
        
        XCTAssertEqual(messages.count, 1)
        if case .response(let resp) = messages[0] {
            XCTAssertEqual(resp.messageId, 5)
            XCTAssertEqual(resp.code, .ok)
        } else {
            XCTFail("Expected response message")
        }
    }
    
    func testParseCommandWithBody() {
        let parser = MessageParser()
        
        let body = "1\020\05\0255"
        let bodyData = body.data(using: .utf8)!
        let bodyLen = UInt32(bodyData.count)
        
        var data = Data()
        data.append(CommandCode.hardware.rawValue) // command = 20
        data.append(0) // msgId high
        data.append(10) // msgId low = 10
        data.append(UInt8((bodyLen >> 24) & 0xFF))
        data.append(UInt8((bodyLen >> 16) & 0xFF))
        data.append(UInt8((bodyLen >> 8) & 0xFF))
        data.append(UInt8(bodyLen & 0xFF))
        data.append(bodyData)
        
        parser.append(data)
        let messages = parser.parseAll()
        
        XCTAssertEqual(messages.count, 1)
        if case .command(let msg) = messages[0] {
            XCTAssertEqual(msg.command, .hardware)
            XCTAssertEqual(msg.messageId, 10)
            XCTAssertEqual(msg.body, body)
        } else {
            XCTFail("Expected command message")
        }
    }
    
    func testParseMultipleMessages() {
        let parser = MessageParser()
        
        let msg1 = BlynkMessage(command: .ping, messageId: 1, body: "")
        let msg2 = BlynkMessage(command: .ping, messageId: 2, body: "")
        
        var combined = msg1.serialize()
        combined.append(msg2.serialize())
        
        parser.append(combined)
        let messages = parser.parseAll()
        
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].messageId, 1)
        XCTAssertEqual(messages[1].messageId, 2)
    }
    
    func testParsePartialMessage() {
        let parser = MessageParser()
        
        let msg = BlynkMessage(command: .hardware, messageId: 42, body: "test\0data")
        let fullData = msg.serialize()
        
        let splitPoint = 5
        let part1 = fullData.prefix(splitPoint)
        let part2 = fullData.suffix(from: splitPoint)
        
        parser.append(Data(part1))
        XCTAssertEqual(parser.parseAll().count, 0)
        
        parser.append(Data(part2))
        let messages = parser.parseAll()
        XCTAssertEqual(messages.count, 1)
        
        if case .command(let parsed) = messages[0] {
            XCTAssertEqual(parsed.messageId, 42)
            XCTAssertEqual(parsed.body, "test\0data")
        } else {
            XCTFail("Expected command")
        }
    }
    
    func testParseEmptyBody() {
        let parser = MessageParser()
        
        let msg = BlynkMessage(command: .ping, messageId: 100, body: "")
        parser.append(msg.serialize())
        
        let messages = parser.parseAll()
        XCTAssertEqual(messages.count, 1)
        
        if case .command(let parsed) = messages[0] {
            XCTAssertEqual(parsed.command, .ping)
            XCTAssertEqual(parsed.body, "")
        } else {
            XCTFail("Expected command")
        }
    }
    
    func testReset() {
        let parser = MessageParser()
        
        let msg = BlynkMessage(command: .ping, messageId: 1, body: "")
        parser.append(msg.serialize())
        parser.reset()
        
        XCTAssertEqual(parser.parseAll().count, 0)
    }
    
    func testInsufficientData() {
        let parser = MessageParser()
        
        parser.append(Data([0x01, 0x02]))
        XCTAssertEqual(parser.parseAll().count, 0)
    }
}

final class BlynkMessageTests: XCTestCase {
    
    func testSerializeDeserializeRoundTrip() {
        let original = BlynkMessage(command: .hardware, messageId: 256, body: "vw\05\0100")
        let data = original.serialize()
        
        XCTAssertEqual(data[0], CommandCode.hardware.rawValue)
        XCTAssertEqual(UInt16(data[1]) << 8 | UInt16(data[2]), 256)
        
        let bodyLength = UInt32(data[3]) << 24 | UInt32(data[4]) << 16 | UInt32(data[5]) << 8 | UInt32(data[6])
        XCTAssertEqual(Int(bodyLength), original.body.utf8.count)
    }
    
    func testBodyParts() {
        let msg = BlynkMessage(command: .hardware, messageId: 1, body: "vw\05\0255")
        let parts = msg.bodyParts
        
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "vw")
        XCTAssertEqual(parts[1], "5")
        XCTAssertEqual(parts[2], "255")
    }
    
    func testInitWithBodyParts() {
        let msg = BlynkMessage(command: .hardware, messageId: 1, bodyParts: ["vw", "5", "255"])
        
        XCTAssertEqual(msg.body, "vw\05\0255")
        XCTAssertEqual(msg.bodyParts.count, 3)
    }
    
    func testMobileHeaderSize() {
        XCTAssertEqual(BlynkMessage.headerSize, 7)
    }
    
    func testHardwareHeaderSize() {
        XCTAssertEqual(BlynkMessage.hardwareHeaderSize, 5)
    }
    
    func testHardwareSerialization() {
        let msg = BlynkMessage(command: .login, messageId: 1, body: "token123")
        let data = msg.serializeForHardware()
        
        XCTAssertEqual(data[0], CommandCode.login.rawValue)
        XCTAssertEqual(UInt16(data[1]) << 8 | UInt16(data[2]), 1)
        
        let bodyLength = UInt16(data[3]) << 8 | UInt16(data[4])
        XCTAssertEqual(Int(bodyLength), "token123".utf8.count)
        
        XCTAssertEqual(data.count, 5 + "token123".utf8.count)
    }
    
    func testMessageIdWrapping() {
        let msg = BlynkMessage(command: .ping, messageId: UInt16.max, body: "")
        let data = msg.serialize()
        
        XCTAssertEqual(data[1], 0xFF)
        XCTAssertEqual(data[2], 0xFF)
    }
    
    func testSeparatorConstant() {
        XCTAssertEqual(BlynkMessage.separator, "\0")
        XCTAssertEqual(BlynkMessage.separatorString, "\0")
    }
}

final class WidgetModelTests: XCTestCase {
    
    func testWidgetCodableRoundTrip() throws {
        var widget = Widget(id: 1, type: .button)
        widget.x = 0
        widget.y = 0
        widget.width = 2
        widget.height = 1
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(widget)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Widget.self, from: data)
        
        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.type, .button)
        XCTAssertEqual(decoded.x, 0)
        XCTAssertEqual(decoded.y, 0)
        XCTAssertEqual(decoded.width, 2)
        XCTAssertEqual(decoded.height, 1)
    }
    
    func testWidgetWithAllProperties() throws {
        var widget = Widget(id: 42, type: .slider)
        widget.x = 1
        widget.y = 2
        widget.width = 4
        widget.height = 1
        widget.tabId = 0
        widget.label = "Temperature"
        widget.color = 0xFF00FF
        widget.deviceId = 0
        widget.pin = 5
        widget.pinType = .virtual
        widget.value = "128"
        widget.min = 0
        widget.max = 255
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(widget)
        let decoded = try JSONDecoder().decode(Widget.self, from: data)
        
        XCTAssertEqual(decoded.label, "Temperature")
        XCTAssertEqual(decoded.pin, 5)
        XCTAssertEqual(decoded.pinType, .virtual)
        XCTAssertEqual(decoded.value, "128")
        XCTAssertEqual(decoded.min, 0)
        XCTAssertEqual(decoded.max, 255)
    }
    
    func testWidgetFromServerJSON() throws {
        let json = """
        {
            "id": 1,
            "type": "BUTTON",
            "x": 0,
            "y": 0,
            "width": 2,
            "height": 1,
            "label": "LED",
            "pinType": "VIRTUAL",
            "pin": 1,
            "min": 0,
            "max": 1,
            "pushMode": true,
            "deviceId": 0
        }
        """.data(using: .utf8)!
        
        let widget = try JSONDecoder().decode(Widget.self, from: json)
        
        XCTAssertEqual(widget.id, 1)
        XCTAssertEqual(widget.type, .button)
        XCTAssertEqual(widget.label, "LED")
        XCTAssertEqual(widget.pinType, .virtual)
        XCTAssertEqual(widget.pin, 1)
        XCTAssertTrue(widget.pushMode ?? false)
    }
    
    func testWidgetTypeValues() {
        XCTAssertEqual(WidgetType.button.rawValue, "BUTTON")
        XCTAssertEqual(WidgetType.slider.rawValue, "SLIDER")
        XCTAssertEqual(WidgetType.gauge.rawValue, "GAUGE")
        XCTAssertEqual(WidgetType.lcd.rawValue, "LCD")
        XCTAssertEqual(WidgetType.terminal.rawValue, "TERMINAL")
        XCTAssertEqual(WidgetType.twoAxisJoystick.rawValue, "TWO_AXIS_JOYSTICK")
        XCTAssertEqual(WidgetType.led.rawValue, "LED")
        XCTAssertEqual(WidgetType.digit4Display.rawValue, "DIGIT4_DISPLAY")
    }
    
    func testPinTypeValues() {
        XCTAssertEqual(PinType.virtual.rawValue, "VIRTUAL")
        XCTAssertEqual(PinType.digital.rawValue, "DIGITAL")
        XCTAssertEqual(PinType.analog.rawValue, "ANALOG")
    }
    
    func testDeviceStatusValues() {
        XCTAssertNotNil(DeviceStatus.online)
        XCTAssertNotNil(DeviceStatus.offline)
    }
}

final class DashBoardModelTests: XCTestCase {
    
    func testDashBoardCodableRoundTrip() throws {
        var dashboard = DashBoard(id: 1, name: "Test Project")
        dashboard.theme = .blynk
        dashboard.isActive = true
        
        let data = try JSONEncoder().encode(dashboard)
        let decoded = try JSONDecoder().decode(DashBoard.self, from: data)
        
        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.name, "Test Project")
        XCTAssertEqual(decoded.theme, .blynk)
        XCTAssertEqual(decoded.isActive, true)
    }
    
    func testDashBoardWithWidgets() throws {
        var dashboard = DashBoard(id: 1, name: "With Widgets")
        let widget = Widget(id: 1, type: .button)
        dashboard.widgets = [widget]
        
        let data = try JSONEncoder().encode(dashboard)
        let decoded = try JSONDecoder().decode(DashBoard.self, from: data)
        
        XCTAssertEqual(decoded.widgets?.count, 1)
        XCTAssertEqual(decoded.widgets?[0].type, .button)
    }
    
    func testDashBoardWithDevices() throws {
        var dashboard = DashBoard(id: 1, name: "With Devices")
        let device = Device(id: 0, name: "ESP8266", boardType: .ESP8266)
        dashboard.devices = [device]
        
        let data = try JSONEncoder().encode(dashboard)
        let decoded = try JSONDecoder().decode(DashBoard.self, from: data)
        
        XCTAssertEqual(decoded.devices?.count, 1)
        XCTAssertEqual(decoded.devices?[0].boardType, .ESP8266)
    }
}

final class GraphDataParserTests: XCTestCase {
    
    func testParseBinaryEmptyData() throws {
        let data = Data()
        let streams = try GraphDataParser.parseBinary(data)
        XCTAssertTrue(streams.isEmpty)
    }
    
    func testParseBinaryTooSmall() throws {
        let data = Data([0x00, 0x01])
        let streams = try GraphDataParser.parseBinary(data)
        XCTAssertTrue(streams.isEmpty)
    }
    
    func testParseBinaryZeroPoints() throws {
        var data = Data()
        appendInt32(&data, 1) // stream count
        appendInt32(&data, 0) // zero points
        
        let streams = try GraphDataParser.parseBinary(data)
        XCTAssertEqual(streams.count, 1)
        XCTAssertEqual(streams[0].points.count, 0)
    }
    
    func testParseBinarySinglePoint() throws {
        var data = Data()
        appendInt32(&data, 1) // stream count
        appendInt32(&data, 1) // one point
        appendFloat64(&data, 25.5) // value
        appendInt64(&data, 1700000000000) // timestamp (ms)
        
        let streams = try GraphDataParser.parseBinary(data)
        XCTAssertEqual(streams.count, 1)
        XCTAssertEqual(streams[0].points.count, 1)
        XCTAssertEqual(streams[0].points[0].value, 25.5, accuracy: 0.001)
        XCTAssertEqual(streams[0].points[0].timestamp, 1700000000000)
    }
    
    func testGraphPointDate() {
        let point = GraphPoint(value: 42.0, timestamp: 1700000000000)
        let date = point.date
        let interval = date.timeIntervalSince1970
        XCTAssertEqual(interval, 1700000000, accuracy: 1.0)
    }
    
    private func appendInt32(_ data: inout Data, _ value: Int32) {
        var v = value.bigEndian
        data.append(Data(bytes: &v, count: 4))
    }
    
    private func appendInt64(_ data: inout Data, _ value: Int64) {
        var v = value.bigEndian
        data.append(Data(bytes: &v, count: 8))
    }
    
    private func appendFloat64(_ data: inout Data, _ value: Double) {
        var bits = value.bitPattern.bigEndian
        data.append(Data(bytes: &bits, count: 8))
    }
}

final class ResponseCodeTests: XCTestCase {
    
    func testCommonResponseCodes() {
        XCTAssertEqual(ResponseCode.ok.rawValue, 200)
        XCTAssertEqual(ResponseCode.invalidToken.rawValue, 9)
        XCTAssertEqual(ResponseCode.illegalCommand.rawValue, 2)
        XCTAssertNotNil(ResponseCode(rawValue: 200))
    }
    
    func testUnknownResponseCode() {
        let code = ResponseCode(rawValue: 99999)
        XCTAssertNotNil(code)
    }
}

final class CommandCodeTests: XCTestCase {
    
    func testAllCommandCodes() {
        XCTAssertEqual(CommandCode.response.rawValue, 0)
        XCTAssertEqual(CommandCode.register.rawValue, 1)
        XCTAssertEqual(CommandCode.login.rawValue, 2)
        XCTAssertEqual(CommandCode.ping.rawValue, 6)
        XCTAssertEqual(CommandCode.hardware.rawValue, 20)
    }
}
