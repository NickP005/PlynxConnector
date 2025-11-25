import XCTest
@testable import PlynxConnector

final class PlynxConnectorTests: XCTestCase {
    
    func testCommandCodeValues() {
        XCTAssertEqual(CommandCode.register.rawValue, 1)
        XCTAssertEqual(CommandCode.login.rawValue, 2)
        XCTAssertEqual(CommandCode.hardware.rawValue, 20)
        XCTAssertEqual(CommandCode.ping.rawValue, 6)
    }
    
    func testResponseCodeValues() {
        XCTAssertEqual(ResponseCode.ok.rawValue, 200)
        XCTAssertEqual(ResponseCode.invalidToken.rawValue, 9)
        XCTAssertEqual(ResponseCode.illegalCommand.rawValue, 2)
    }
    
    func testBlynkMessageSerialization() {
        let message = BlynkMessage(command: .login, messageId: 1, body: "test@example.com\0password\0MyApp")
        let data = message.serialize()
        
        // Header: 1 byte command + 2 bytes msgId + 2 bytes length = 5 bytes
        XCTAssertEqual(data[0], 2) // login command
        XCTAssertEqual(data[1], 0) // msgId high byte
        XCTAssertEqual(data[2], 1) // msgId low byte
        
        let bodyLength = UInt16(message.body.utf8.count)
        XCTAssertEqual(data[3], UInt8(bodyLength >> 8)) // length high byte
        XCTAssertEqual(data[4], UInt8(bodyLength & 0xFF)) // length low byte
    }
    
    func testMessageParser() {
        let parser = MessageParser()
        
        // Create a valid message
        let message = BlynkMessage(command: .ping, messageId: 42, body: "")
        let data = message.serialize()
        
        parser.append(data)
        let parsed = parser.parseAll()
        XCTAssertEqual(parsed.count, 1)
        
        if case .command(let msg) = parsed[0] {
            XCTAssertEqual(msg.command, CommandCode.ping)
            XCTAssertEqual(msg.messageId, 42)
        } else {
            XCTFail("Expected command message")
        }
    }
    
    func testBoardTypes() {
        XCTAssertEqual(BoardType.ESP8266.rawValue, "ESP8266")
        // Board type enum exists and is accessible
        XCTAssertNotNil(BoardType.arduinoUno)
    }
    
    func testWidgetTypes() {
        XCTAssertEqual(WidgetType.button.rawValue, "BUTTON")
        XCTAssertEqual(WidgetType.slider.rawValue, "SLIDER")
        XCTAssertEqual(WidgetType.gauge.rawValue, "GAUGE")
    }
    
    func testActionSerialization() {
        // Test login action
        let loginAction = Action.login(email: "test@test.com", password: "pass123", appName: "TestApp")
        
        // Test virtual pin write
        let vpAction = Action.writeVirtualPin(dashId: 1, deviceId: 0, pin: 5, value: "255")
        
        // These should not crash
        _ = loginAction
        _ = vpAction
    }
    
    func testDeviceCodable() throws {
        let device = Device(id: 1, name: "Test Device", boardType: .ESP8266)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(device)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Device.self, from: data)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.name, device.name)
        XCTAssertEqual(decoded.boardType, device.boardType)
    }
    
    func testDashBoardCodable() throws {
        let dashboard = DashBoard(id: 1, name: "My Dashboard")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(dashboard)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DashBoard.self, from: data)
        
        XCTAssertEqual(decoded.id, dashboard.id)
        XCTAssertEqual(decoded.name, dashboard.name)
    }
    
    func testTagCodable() throws {
        let tag = Tag(id: 100000, name: "Living Room", deviceIds: [0, 1, 2])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(tag)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Tag.self, from: data)
        
        XCTAssertEqual(decoded.id, tag.id)
        XCTAssertEqual(decoded.name, tag.name)
        XCTAssertEqual(decoded.deviceIds, tag.deviceIds)
    }
}
