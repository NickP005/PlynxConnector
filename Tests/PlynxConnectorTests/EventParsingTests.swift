import XCTest
@testable import PlynxConnector

final class EventParsingTests: XCTestCase {

    let decoder = JSONDecoder()

    // MARK: - Response Parsing

    func testResponseOK() {
        let response = BlynkResponse(messageId: 1, code: .ok)
        let event = Event.from(message: .response(response), decoder: decoder)

        if case .response(let msgId, let code) = event {
            XCTAssertEqual(msgId, 1)
            XCTAssertEqual(code, .ok)
        } else {
            XCTFail("Expected .response event, got \(String(describing: event))")
        }
    }

    func testResponseError() {
        let response = BlynkResponse(messageId: 10, code: .invalidToken)
        let event = Event.from(message: .response(response), decoder: decoder)

        if case .response(let msgId, let code) = event {
            XCTAssertEqual(msgId, 10)
            XCTAssertEqual(code, .invalidToken)
        } else {
            XCTFail("Expected .response event")
        }
    }

    func testResponseUserNotRegistered() {
        let response = BlynkResponse(messageId: 5, code: .userNotRegistered)
        let event = Event.from(message: .response(response), decoder: decoder)

        if case .response(_, let code) = event {
            XCTAssertEqual(code, .userNotRegistered)
        } else {
            XCTFail("Expected .response event")
        }
    }

    func testResponseUserAlreadyRegistered() {
        let response = BlynkResponse(messageId: 5, code: .userAlreadyRegistered)
        let event = Event.from(message: .response(response), decoder: decoder)

        if case .response(_, let code) = event {
            XCTAssertEqual(code, .userAlreadyRegistered)
        } else {
            XCTFail("Expected .response event")
        }
    }

    func testResponseEnergyLimit() {
        let response = BlynkResponse(messageId: 7, code: .energyLimit)
        let event = Event.from(message: .response(response), decoder: decoder)

        if case .response(_, let code) = event {
            XCTAssertEqual(code, .energyLimit)
        } else {
            XCTFail("Expected .response event")
        }
    }

    // MARK: - Hardware Connected / Disconnected

    func testHardwareConnected() {
        let msg = BlynkMessage(command: .hardwareConnected, messageId: 1, body: "5-0")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareConnected(let dashId, let deviceId) = event {
            XCTAssertEqual(dashId, 5)
            XCTAssertEqual(deviceId, 0)
        } else {
            XCTFail("Expected .hardwareConnected, got \(String(describing: event))")
        }
    }

    func testHardwareConnectedMultiDigit() {
        let msg = BlynkMessage(command: .hardwareConnected, messageId: 1, body: "123-456")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareConnected(let dashId, let deviceId) = event {
            XCTAssertEqual(dashId, 123)
            XCTAssertEqual(deviceId, 456)
        } else {
            XCTFail("Expected .hardwareConnected")
        }
    }

    func testHardwareDisconnected() {
        let msg = BlynkMessage(command: .deviceOffline, messageId: 1, body: "3-1")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareDisconnected(let dashId, let deviceId) = event {
            XCTAssertEqual(dashId, 3)
            XCTAssertEqual(deviceId, 1)
        } else {
            XCTFail("Expected .hardwareDisconnected, got \(String(describing: event))")
        }
    }

    func testHardwareConnectedInvalidBody() {
        let msg = BlynkMessage(command: .hardwareConnected, messageId: 1, body: "invalid")
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - Hardware Messages (Virtual Pin)

    func testVirtualPinUpdateFromHardware() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0", "vw", "5", "255"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .virtualPinUpdate(let dashId, let deviceId, let pin, let values) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(pin, 5)
            XCTAssertEqual(values, ["255"])
        } else {
            XCTFail("Expected .virtualPinUpdate, got \(String(describing: event))")
        }
    }

    func testVirtualPinUpdateMultipleValues() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["2-1", "vw", "10", "100", "200", "300"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .virtualPinUpdate(let dashId, let deviceId, let pin, let values) = event {
            XCTAssertEqual(dashId, 2)
            XCTAssertEqual(deviceId, 1)
            XCTAssertEqual(pin, 10)
            XCTAssertEqual(values, ["100", "200", "300"])
        } else {
            XCTFail("Expected .virtualPinUpdate with multiple values")
        }
    }

    func testDigitalPinUpdateFromHardware() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0", "dw", "13", "1"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .digitalPinUpdate(let dashId, let deviceId, let pin, let value) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(pin, 13)
            XCTAssertEqual(value, 1)
        } else {
            XCTFail("Expected .digitalPinUpdate, got \(String(describing: event))")
        }
    }

    func testAnalogPinUpdateFromHardware() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0", "aw", "0", "512"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .analogPinUpdate(let dashId, let deviceId, let pin, let value) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(pin, 0)
            XCTAssertEqual(value, 512)
        } else {
            XCTFail("Expected .analogPinUpdate, got \(String(describing: event))")
        }
    }

    func testRawHardwareMessageUnknownCommand() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0", "pm", "5", "out"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareMessage(let dashId, let deviceId, let body) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertTrue(body.contains("pm"))
        } else {
            XCTFail("Expected .hardwareMessage, got \(String(describing: event))")
        }
    }

    func testHardwareMessageOnlyTarget() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareMessage(let dashId, let deviceId, let body) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(body, "")
        } else {
            XCTFail("Expected .hardwareMessage, got \(String(describing: event))")
        }
    }

    func testHardwareMessageInvalidTarget() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["badformat", "vw", "5", "1"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareMessage(let dashId, let deviceId, _) = event {
            XCTAssertEqual(dashId, 0)
            XCTAssertEqual(deviceId, 0)
        } else {
            XCTFail("Expected .hardwareMessage fallback")
        }
    }

    // MARK: - Widget Property Changed

    func testWidgetPropertyChanged() {
        let msg = BlynkMessage(command: .setWidgetProperty, messageId: 1,
                               bodyParts: ["1-0", "5", "label", "Temperature"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .widgetPropertyChanged(let dashId, let deviceId, let pin, let property, let value) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(pin, 5)
            XCTAssertEqual(property, .label)
            XCTAssertEqual(value, "Temperature")
        } else {
            XCTFail("Expected .widgetPropertyChanged, got \(String(describing: event))")
        }
    }

    func testWidgetPropertyChangedColor() {
        let msg = BlynkMessage(command: .setWidgetProperty, messageId: 1,
                               bodyParts: ["2-1", "3", "color", "#FF0000"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .widgetPropertyChanged(let dashId, let deviceId, let pin, let property, let value) = event {
            XCTAssertEqual(dashId, 2)
            XCTAssertEqual(deviceId, 1)
            XCTAssertEqual(pin, 3)
            XCTAssertEqual(property, .color)
            XCTAssertEqual(value, "#FF0000")
        } else {
            XCTFail("Expected .widgetPropertyChanged")
        }
    }

    func testWidgetPropertyInsufficientParts() {
        let msg = BlynkMessage(command: .setWidgetProperty, messageId: 1,
                               bodyParts: ["1-0", "5"])
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    func testWidgetPropertyUnknownProperty() {
        let msg = BlynkMessage(command: .setWidgetProperty, messageId: 1,
                               bodyParts: ["1-0", "5", "unknownProp", "val"])
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - App Sync

    func testAppSyncDataSimple() {
        let msg = BlynkMessage(command: .appSync, messageId: 1,
                               bodyParts: ["1", "vw", "5", "128"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .appSyncData(let dashId, let body) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertTrue(body.contains("vw"))
            XCTAssertTrue(body.contains("5"))
            XCTAssertTrue(body.contains("128"))
        } else {
            XCTFail("Expected .appSyncData, got \(String(describing: event))")
        }
    }

    func testAppSyncDataWithDeviceId() {
        let msg = BlynkMessage(command: .appSync, messageId: 1,
                               bodyParts: ["1-0", "vw", "5", "255"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .appSyncData(let dashId, let body) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertTrue(body.hasPrefix("0\0"))
            XCTAssertTrue(body.contains("vw"))
        } else {
            XCTFail("Expected .appSyncData, got \(String(describing: event))")
        }
    }

    func testAppSyncDataInsufficientParts() {
        let msg = BlynkMessage(command: .appSync, messageId: 1,
                               bodyParts: ["1"])
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    func testAppSyncDataInvalidDashId() {
        let msg = BlynkMessage(command: .appSync, messageId: 1,
                               bodyParts: ["abc", "vw", "5", "1"])
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - Sharing Events

    func testSharingChangedActive() {
        let msg = BlynkMessage(command: .sharing, messageId: 1,
                               bodyParts: ["1", "1"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .sharingChanged(let dashId, let active) = event {
            XCTAssertEqual(dashId, 1)
            XCTAssertTrue(active)
        } else {
            XCTFail("Expected .sharingChanged, got \(String(describing: event))")
        }
    }

    func testSharingChangedInactive() {
        let msg = BlynkMessage(command: .sharing, messageId: 1,
                               bodyParts: ["2", "0"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .sharingChanged(let dashId, let active) = event {
            XCTAssertEqual(dashId, 2)
            XCTAssertFalse(active)
        } else {
            XCTFail("Expected .sharingChanged")
        }
    }

    // MARK: - Dashboard Activated/Deactivated By Other

    func testDashboardActivatedByOther() {
        let msg = BlynkMessage(command: .activateDashboard, messageId: 1, body: "7")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .dashboardActivatedByOther(let dashId) = event {
            XCTAssertEqual(dashId, 7)
        } else {
            XCTFail("Expected .dashboardActivatedByOther, got \(String(describing: event))")
        }
    }

    func testDashboardDeactivatedByOther() {
        let msg = BlynkMessage(command: .deactivateDashboard, messageId: 1, body: "3")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .dashboardDeactivatedByOther(let dashId) = event {
            XCTAssertEqual(dashId, 3)
        } else {
            XCTFail("Expected .dashboardDeactivatedByOther, got \(String(describing: event))")
        }
    }

    func testDashboardActivatedByOtherInvalidBody() {
        let msg = BlynkMessage(command: .activateDashboard, messageId: 1, body: "not-a-number")
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - Outdated App Notification

    func testOutdatedAppNotification() {
        let msg = BlynkMessage(command: .outdatedAppNotification, messageId: 1, body: "Please update your app")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .outdatedAppNotification(let message) = event {
            XCTAssertEqual(message, "Please update your app")
        } else {
            XCTFail("Expected .outdatedAppNotification, got \(String(describing: event))")
        }
    }

    // MARK: - Internal Message

    func testInternalMessage() {
        let msg = BlynkMessage(command: .blynkInternal, messageId: 1, body: "ver\00.1.0\0h-beat\015")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .internalMessage(let body) = event {
            XCTAssertTrue(body.contains("ver"))
        } else {
            XCTFail("Expected .internalMessage, got \(String(describing: event))")
        }
    }

    // MARK: - Ping / Pong

    func testPingResponseIsPong() {
        let msg = BlynkMessage(command: .ping, messageId: 1, body: "")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .pong = event {
            // pass
        } else {
            XCTFail("Expected .pong, got \(String(describing: event))")
        }
    }

    // MARK: - Unknown Command

    func testUnknownCommandReturnsNil() {
        let msg = BlynkMessage(command: .bridge, messageId: 1, body: "something")
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - Graph Data

    func testGraphDataWithRawData() {
        let rawBytes = Data([0x1f, 0x8b, 0x08, 0x00])
        let msg = BlynkMessage(command: .getEnhancedGraphData, messageId: 1, body: "", rawData: rawBytes)
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .graphData(let data) = event {
            XCTAssertEqual(data, rawBytes)
        } else {
            XCTFail("Expected .graphData, got \(String(describing: event))")
        }
    }

    func testGraphDataWithoutRawDataReturnsNil() {
        let msg = BlynkMessage(command: .getEnhancedGraphData, messageId: 1, body: "")
        let event = Event.from(message: .command(msg), decoder: decoder)
        XCTAssertNil(event)
    }

    // MARK: - Edge Cases

    func testEmptyHardwareBody() {
        let msg = BlynkMessage(command: .hardware, messageId: 1, body: "")
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareMessage(let dashId, let deviceId, let body) = event {
            XCTAssertEqual(dashId, 0)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(body, "")
        } else {
            XCTFail("Expected .hardwareMessage fallback for empty body")
        }
    }

    func testResponseAllErrorCodes() {
        let codes: [ResponseCode] = [
            .ok, .quotaLimit, .illegalCommand, .userNotRegistered,
            .userAlreadyRegistered, .userNotAuthenticated, .notAllowed,
            .deviceNotInNetwork, .noActiveDashboard, .invalidToken,
            .illegalCommandBody, .noData, .serverError, .energyLimit
        ]

        for code in codes {
            let response = BlynkResponse(messageId: 1, code: code)
            let event = Event.from(message: .response(response), decoder: decoder)
            XCTAssertNotNil(event, "Event should not be nil for code \(code)")
            if case .response(_, let parsedCode) = event {
                XCTAssertEqual(parsedCode, code)
            }
        }
    }

    func testHardwareMessageEmptyBodyParts() {
        let msg = BlynkMessage(command: .hardware, messageId: 1, bodyParts: [""])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .hardwareMessage(let dashId, let deviceId, let body) = event {
            XCTAssertEqual(dashId, 0)
            XCTAssertEqual(deviceId, 0)
            XCTAssertEqual(body, "")
        } else {
            XCTFail("Expected .hardwareMessage fallback")
        }
    }

    func testVirtualPinUpdateStringValue() {
        let msg = BlynkMessage(command: .hardware, messageId: 1,
                               bodyParts: ["1-0", "vw", "5", "hello world"])
        let event = Event.from(message: .command(msg), decoder: decoder)

        if case .virtualPinUpdate(_, _, let pin, let values) = event {
            XCTAssertEqual(pin, 5)
            XCTAssertEqual(values, ["hello world"])
        } else {
            XCTFail("Expected .virtualPinUpdate")
        }
    }
}
