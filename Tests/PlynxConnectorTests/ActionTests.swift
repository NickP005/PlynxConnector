import XCTest
@testable import PlynxConnector

final class ActionTests: XCTestCase {

    let encoder = JSONEncoder()
    let testMsgId: UInt16 = 1

    // MARK: - Authentication

    func testLoginCommand() throws {
        let action = Action.login(email: "test@example.com", password: "secret123", appName: "Plynx")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .login)
        XCTAssertEqual(msg.messageId, testMsgId)

        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "test@example.com")
        let expectedHash = SHA256Helper.makeHash(password: "secret123", email: "test@example.com")
        XCTAssertEqual(parts[1], expectedHash)
        XCTAssertEqual(parts[2], "iOS")
        XCTAssertEqual(parts[3], "1.0.0")
        XCTAssertEqual(parts[4], "Plynx")
    }

    func testRegisterCommand() throws {
        let action = Action.register(email: "new@user.com", password: "pass", appName: "Plynx")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .register)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "new@user.com")
        let expectedHash = SHA256Helper.makeHash(password: "pass", email: "new@user.com")
        XCTAssertEqual(parts[1], expectedHash)
        XCTAssertEqual(parts[2], "Plynx")
    }

    func testShareLoginCommand() throws {
        let action = Action.shareLogin(token: "abc123token")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .shareLogin)
        XCTAssertEqual(msg.body, "abc123token")
    }

    func testLogoutWithUID() throws {
        let action = Action.logout(uid: "device-uid-42")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .logout)
        XCTAssertEqual(msg.body, "device-uid-42")
    }

    func testLogoutWithoutUID() throws {
        let action = Action.logout(uid: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .logout)
        XCTAssertEqual(msg.body, "")
    }

    func testResetPasswordStart() throws {
        let action = Action.resetPasswordStart(email: "a@b.com", appName: "Plynx")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .resetPassword)
        XCTAssertEqual(msg.bodyParts, ["start", "a@b.com", "Plynx"])
    }

    func testResetPasswordVerify() throws {
        let action = Action.resetPasswordVerify(token: "tok123")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .resetPassword)
        XCTAssertEqual(msg.bodyParts, ["verify", "tok123"])
    }

    func testGetServer() throws {
        let action = Action.getServer(email: "u@x.com")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getServer)
        XCTAssertEqual(msg.body, "u@x.com")
    }

    // MARK: - Dashboard Management

    func testLoadProfileAll() throws {
        let action = Action.loadProfile(dashId: nil, published: false)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .loadProfileGzipped)
        XCTAssertEqual(msg.body, "")
    }

    func testLoadProfileSpecificDash() throws {
        let action = Action.loadProfile(dashId: 42, published: false)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .loadProfileGzipped)
        XCTAssertEqual(msg.body, "42")
    }

    func testLoadProfilePublished() throws {
        let action = Action.loadProfile(dashId: 7, published: true)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .loadProfileGzipped)
        XCTAssertEqual(msg.bodyParts, ["7", "published"])
    }

    func testActivateDashboard() throws {
        let action = Action.activateDashboard(dashId: 5)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .activateDashboard)
        XCTAssertEqual(msg.body, "5")
    }

    func testDeactivateDashboardSpecific() throws {
        let action = Action.deactivateDashboard(dashId: 10)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deactivateDashboard)
        XCTAssertEqual(msg.body, "10")
    }

    func testDeactivateDashboardAll() throws {
        let action = Action.deactivateDashboard(dashId: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deactivateDashboard)
        XCTAssertEqual(msg.body, "")
    }

    func testDeleteDashboard() throws {
        let action = Action.deleteDashboard(dashId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteDash)
        XCTAssertEqual(msg.body, "3")
    }

    // MARK: - Widget Management

    func testCreateWidget() throws {
        let widget = Widget(id: 100, type: .button)
        let action = Action.createWidget(dashId: 1, widget: widget, tileId: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .createWidget)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "1")
        XCTAssertTrue(parts[1].contains("\"id\":100") || parts[1].contains("\"id\" : 100"))
    }

    func testCreateWidgetWithTileId() throws {
        let widget = Widget(id: 50, type: .slider)
        let action = Action.createWidget(dashId: 2, widget: widget, tileId: 77)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .createWidget)
        let parts = msg.bodyParts
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "2")
        XCTAssertEqual(parts[2], "77")
    }

    func testUpdateWidget() throws {
        let widget = Widget(id: 10, type: .gauge)
        let action = Action.updateWidget(dashId: 3, widget: widget)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .updateWidget)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "3")
        XCTAssertFalse(parts[1].isEmpty)
    }

    func testDeleteWidget() throws {
        let action = Action.deleteWidget(dashId: 1, widgetId: 42)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteWidget)
        XCTAssertEqual(msg.bodyParts, ["1", "42"])
    }

    func testGetWidget() throws {
        let action = Action.getWidget(dashId: 2, widgetId: 99)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getWidget)
        XCTAssertEqual(msg.bodyParts, ["2", "99"])
    }

    func testSetWidgetProperty() throws {
        let action = Action.setWidgetProperty(dashId: 1, deviceId: 0, pin: 5, property: .label, value: "Temp")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .setWidgetProperty)
        XCTAssertEqual(msg.bodyParts, ["1-0", "5", "label", "Temp"])
    }

    // MARK: - Hardware Communication

    func testHardwareCommand() throws {
        let action = Action.hardware(dashId: 1, deviceId: 0, body: "vw\05\0255")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardware)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "1-0")
        XCTAssertEqual(parts[1], "vw")
        XCTAssertEqual(parts[2], "5")
        XCTAssertEqual(parts[3], "255")
    }

    func testWriteVirtualPin() throws {
        let action = Action.writeVirtualPin(dashId: 2, deviceId: 1, pin: 10, value: "hello")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardware)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "2-1")
        XCTAssertEqual(parts[1], "vw")
        XCTAssertEqual(parts[2], "10")
        XCTAssertEqual(parts[3], "hello")
    }

    func testReadVirtualPin() throws {
        let action = Action.readVirtualPin(dashId: 3, deviceId: 0, pin: 7)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardware)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "3-0")
        XCTAssertEqual(parts[1], "vr")
        XCTAssertEqual(parts[2], "7")
    }

    func testHardwareSyncWithTarget() throws {
        let action = Action.hardwareSync(dashId: 1, target: "vr\05")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardwareSync)
        XCTAssertEqual(msg.bodyParts[0], "1")
        XCTAssertEqual(msg.bodyParts[1], "vr")
    }

    func testHardwareSyncWithoutTarget() throws {
        let action = Action.hardwareSync(dashId: 4, target: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardwareSync)
        XCTAssertEqual(msg.body, "4")
    }

    func testAppSyncAll() throws {
        let action = Action.appSync(dashId: 1, widgetIds: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .appSync)
        XCTAssertEqual(msg.body, "1")
    }

    func testAppSyncSpecificWidgets() throws {
        let action = Action.appSync(dashId: 1, widgetIds: [10, 20, 30])
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .appSync)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "1")
        XCTAssertTrue(parts[1].contains("10"))
    }

    func testResendFromBluetooth() throws {
        let action = Action.resendFromBluetooth(dashId: 1, deviceId: 2, body: "vw\03\0128")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .hardwareResendFromBluetooth)
        XCTAssertEqual(msg.bodyParts[0], "1-2")
    }

    // MARK: - Device Management

    func testCreateDevice() throws {
        let device = Device(id: 0, name: "ESP32", boardType: .ESP8266)
        let action = Action.createDevice(dashId: 1, device: device)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .createDevice)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "1")
        XCTAssertFalse(parts[1].isEmpty)
    }

    func testDeleteDevice() throws {
        let action = Action.deleteDevice(dashId: 5, deviceId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteDevice)
        XCTAssertEqual(msg.bodyParts, ["5", "3"])
    }

    func testGetDevices() throws {
        let action = Action.getDevices(dashId: 7)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getDevices)
        XCTAssertEqual(msg.body, "7")
    }

    func testGetDevice() throws {
        let action = Action.getDevice(dashId: 1, deviceId: 2)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .mobileGetDevice)
        XCTAssertEqual(msg.bodyParts, ["1", "2"])
    }

    func testDeleteDeviceDataAll() throws {
        let action = Action.deleteDeviceData(dashId: 1, deviceId: 0, pins: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteDeviceData)
        XCTAssertEqual(msg.bodyParts, ["1", "0"])
    }

    func testDeleteDeviceDataSpecificPins() throws {
        let pins = [PinInfo(pin: 5, pinType: .virtual), PinInfo(pin: 2, pinType: .digital)]
        let action = Action.deleteDeviceData(dashId: 1, deviceId: 0, pins: pins)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteDeviceData)
        let parts = msg.bodyParts
        XCTAssertEqual(parts[0], "1")
        XCTAssertEqual(parts[1], "0")
        XCTAssertEqual(parts[2], "v5")
        XCTAssertEqual(parts[3], "d2")
    }

    // MARK: - Tag Management

    func testDeleteTag() throws {
        let action = Action.deleteTag(dashId: 1, tagId: 5)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteTag)
        XCTAssertEqual(msg.bodyParts, ["1", "5"])
    }

    func testGetTags() throws {
        let action = Action.getTags(dashId: 9)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getTags)
        XCTAssertEqual(msg.body, "9")
    }

    // MARK: - Token Management

    func testRefreshTokenWithDevice() throws {
        let action = Action.refreshToken(dashId: 1, deviceId: 2)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .refreshToken)
        XCTAssertEqual(msg.bodyParts, ["1", "2"])
    }

    func testRefreshTokenAllDevices() throws {
        let action = Action.refreshToken(dashId: 1, deviceId: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .refreshToken)
        XCTAssertEqual(msg.body, "1")
    }

    func testAssignToken() throws {
        let action = Action.assignToken(dashId: 1, deviceId: 0, token: "myToken123")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .assignToken)
        XCTAssertEqual(msg.bodyParts, ["1", "0", "myToken123"])
    }

    func testGetProvisionToken() throws {
        let action = Action.getProvisionToken(dashId: 1, deviceId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getProvisionToken)
        XCTAssertEqual(msg.bodyParts, ["1", "3"])
    }

    // MARK: - Sharing

    func testSetSharingOn() throws {
        let action = Action.setSharing(dashId: 1, enabled: true)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .sharing)
        XCTAssertEqual(msg.bodyParts, ["1", "on"])
    }

    func testSetSharingOff() throws {
        let action = Action.setSharing(dashId: 1, enabled: false)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .sharing)
        XCTAssertEqual(msg.bodyParts, ["1", "off"])
    }

    func testGetShareToken() throws {
        let action = Action.getShareToken(dashId: 4)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getShareToken)
        XCTAssertEqual(msg.body, "4")
    }

    func testRefreshShareToken() throws {
        let action = Action.refreshShareToken(dashId: 2)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .refreshShareToken)
        XCTAssertEqual(msg.body, "2")
    }

    // MARK: - Graph & Data

    func testGetEnhancedGraphDataBasic() throws {
        let action = Action.getEnhancedGraphData(dashId: 1, widgetId: 50, targetId: nil, period: .day, page: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getEnhancedGraphData)
        XCTAssertEqual(msg.bodyParts, ["1", "50", "DAY"])
    }

    func testGetEnhancedGraphDataWithTargetAndPage() throws {
        let action = Action.getEnhancedGraphData(dashId: 1, widgetId: 50, targetId: 3, period: .week, page: 2)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getEnhancedGraphData)
        XCTAssertEqual(msg.bodyParts, ["1-3", "50", "WEEK", "2"])
    }

    func testDeleteEnhancedGraphDataAll() throws {
        let action = Action.deleteEnhancedGraphData(dashId: 1, widgetId: 10, dataStreamIds: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteEnhancedGraphData)
        XCTAssertEqual(msg.bodyParts, ["1", "10"])
    }

    func testDeleteEnhancedGraphDataSpecific() throws {
        let action = Action.deleteEnhancedGraphData(dashId: 1, widgetId: 10, dataStreamIds: [1, 2, 3])
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteEnhancedGraphData)
        XCTAssertEqual(msg.bodyParts, ["1", "10", "1", "2", "3"])
    }

    func testExportGraphData() throws {
        let action = Action.exportGraphData(dashId: 1, widgetId: 5, pinType: .virtual, pin: 3, deviceId: 0)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .exportGraphData)
        XCTAssertEqual(msg.bodyParts, ["1", "5", "VIRTUAL", "3", "0"])
    }

    // MARK: - Push Notifications

    func testAddPushToken() throws {
        let action = Action.addPushToken(dashId: 1, uid: "uid-abc", token: "apns-token-xyz")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .addPushToken)
        XCTAssertEqual(msg.bodyParts, ["1", "uid-abc", "apns-token-xyz"])
    }

    // MARK: - Email

    func testEmailTokenAllDevices() throws {
        let action = Action.emailToken(dashId: 1, deviceId: nil)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .email)
        XCTAssertEqual(msg.body, "1")
    }

    func testEmailTokenSpecificDevice() throws {
        let action = Action.emailToken(dashId: 1, deviceId: 2)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .email)
        XCTAssertEqual(msg.bodyParts, ["1", "2"])
    }

    func testEmailCustom() throws {
        let action = Action.email(dashId: 1, deviceId: 0, to: "a@b.com", subject: "Alert", body: "Temp high")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .email)
        XCTAssertEqual(msg.bodyParts, ["1-0", "a@b.com", "Alert", "Temp high"])
    }

    func testEmailQR() throws {
        let action = Action.emailQR(dashId: 1, widgetId: 5)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .emailQR)
        XCTAssertEqual(msg.bodyParts, ["1", "5"])
    }

    // MARK: - Clone & Project

    func testGetCloneCode() throws {
        let action = Action.getCloneCode(dashId: 1)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getCloneCode)
        XCTAssertEqual(msg.body, "1")
    }

    func testGetProjectByCloneCodeFetch() throws {
        let action = Action.getProjectByCloneCode(code: "ABCD", create: false)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getProjectByCloneCode)
        XCTAssertEqual(msg.body, "ABCD")
    }

    func testGetProjectByCloneCodeCreate() throws {
        let action = Action.getProjectByCloneCode(code: "ABCD", create: true)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getProjectByCloneCode)
        XCTAssertEqual(msg.bodyParts, ["ABCD", "1"])
    }

    func testGetProjectByToken() throws {
        let action = Action.getProjectByToken(token: "flashed-tok")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getProjectByToken)
        XCTAssertEqual(msg.body, "flashed-tok")
    }

    // MARK: - Energy

    func testGetEnergy() throws {
        let action = Action.getEnergy
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .getEnergy)
        XCTAssertTrue(msg.body.isEmpty)
    }

    func testAddEnergy() throws {
        let action = Action.addEnergy(amount: 5000, transactionId: "txn-123")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .addEnergy)
        XCTAssertEqual(msg.bodyParts, ["5000", "txn-123"])
    }

    func testRedeem() throws {
        let action = Action.redeem(code: "PROMO2025")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .redeem)
        XCTAssertEqual(msg.body, "PROMO2025")
    }

    // MARK: - Account Management

    func testDeleteAccount() throws {
        let action = Action.deleteAccount(email: "user@test.com", password: "mypass")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteAccount)
        let expectedHash = SHA256Helper.makeHash(password: "mypass", email: "user@test.com")
        XCTAssertEqual(msg.body, expectedHash)
    }

    // MARK: - Utility

    func testPing() throws {
        let action = Action.ping
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .ping)
        XCTAssertTrue(msg.body.isEmpty)
    }

    // MARK: - Serialization Round-Trip

    func testSerializedMessageCanBeDeserialized() throws {
        let action = Action.hardware(dashId: 1, deviceId: 0, body: "vw\05\0128")
        let msg = try action.toMessage(messageId: 42, encoder: encoder)
        let data = msg.serialize()

        XCTAssertEqual(data[0], CommandCode.hardware.rawValue)
        let msgId = UInt16(data[1]) << 8 | UInt16(data[2])
        XCTAssertEqual(msgId, 42)

        let bodyLen = UInt32(data[3]) << 24 | UInt32(data[4]) << 16 | UInt32(data[5]) << 8 | UInt32(data[6])
        XCTAssertEqual(Int(bodyLen), msg.body.utf8.count)
    }

    func testMessageIdPreserved() throws {
        let action = Action.ping
        let msg = try action.toMessage(messageId: 65535, encoder: encoder)

        XCTAssertEqual(msg.messageId, UInt16.max)
    }

    // MARK: - Tile Template Management

    func testDeleteTileTemplate() throws {
        let action = Action.deleteTileTemplate(dashId: 1, widgetId: 2, templateId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteTileTemplate)
        XCTAssertEqual(msg.bodyParts, ["1", "2", "3"])
    }

    // MARK: - Report Management

    func testDeleteReport() throws {
        let action = Action.deleteReport(dashId: 1, widgetId: 2, reportId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteReport)
        XCTAssertEqual(msg.bodyParts, ["1", "2", "3"])
    }

    func testExportReport() throws {
        let action = Action.exportReport(dashId: 1, widgetId: 2, reportId: 3)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .exportReport)
        XCTAssertEqual(msg.bodyParts, ["1", "2", "3"])
    }

    // MARK: - App Management

    func testDeleteApp() throws {
        let action = Action.deleteApp(appId: 42)
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .deleteApp)
        XCTAssertEqual(msg.body, "42")
    }

    func testUpdateFace() throws {
        let action = Action.updateFace(appId: 1, dashJson: "{\"id\":1}")
        let msg = try action.toMessage(messageId: testMsgId, encoder: encoder)

        XCTAssertEqual(msg.command, .updateFace)
        XCTAssertEqual(msg.bodyParts, ["1", "{\"id\":1}"])
    }
}
