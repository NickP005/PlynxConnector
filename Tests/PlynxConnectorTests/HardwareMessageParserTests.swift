import XCTest
@testable import PlynxConnector

final class HardwareMessageParserTests: XCTestCase {

    func testRoundTripHardwareCommand() {
        let msg = BlynkMessage(command: .hardware, messageId: 7, bodyParts: ["vw", "1", "255"])
        let parser = HardwareMessageParser()
        parser.append(msg.serializeForHardware())
        let parsed = parser.parseAll()
        XCTAssertEqual(parsed.count, 1)
        guard case .command(let m) = parsed[0] else { return XCTFail("expected command") }
        XCTAssertEqual(m.command, .hardware)
        XCTAssertEqual(m.messageId, 7)
        XCTAssertEqual(m.bodyParts, ["vw", "1", "255"])
    }

    func testResponseStatusInLengthField() {
        // 5-byte RESPONSE: cmd=0, id=3, "length"=200 => success status, no body.
        let parser = HardwareMessageParser()
        parser.append(Data([0, 0, 3, 0, 200]))
        let parsed = parser.parseAll()
        XCTAssertEqual(parsed.count, 1)
        guard case .response(let r) = parsed[0] else { return XCTFail("expected response") }
        XCTAssertEqual(r.messageId, 3)
        XCTAssertTrue(r.code.isSuccess)
    }

    func testChunkedReassembly() {
        // Simulate a frame arriving fragmented across small BLE notifications.
        let msg = BlynkMessage(command: .hardware, messageId: 1, bodyParts: ["vw", "5", "hello world"])
        let data = msg.serializeForHardware()
        let parser = HardwareMessageParser()
        var all: [ParsedMessage] = []
        var i = 0
        while i < data.count {
            let end = min(i + 3, data.count)
            parser.append(data.subdata(in: i..<end))
            all.append(contentsOf: parser.parseAll())
            i = end
        }
        XCTAssertEqual(all.count, 1)
        guard case .command(let m) = all.first else { return XCTFail("expected command") }
        XCTAssertEqual(m.bodyParts, ["vw", "5", "hello world"])
    }

    func testTwoFramesConcatenated() {
        var data = Data()
        data.append(BlynkMessage(command: .hardware, messageId: 1, bodyParts: ["vw", "1", "1"]).serializeForHardware())
        data.append(Data([0, 0, 2, 0, 200])) // a RESPONSE right after
        let parser = HardwareMessageParser()
        parser.append(data)
        let parsed = parser.parseAll()
        XCTAssertEqual(parsed.count, 2)
        if case .command(let m) = parsed[0] { XCTAssertEqual(m.command, .hardware) } else { XCTFail() }
        if case .response(let r) = parsed[1] { XCTAssertTrue(r.code.isSuccess) } else { XCTFail() }
    }
}
