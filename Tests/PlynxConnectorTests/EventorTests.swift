import XCTest
@testable import PlynxConnector

final class EventorTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ConditionType

    func testConditionTypeRawValues() {
        XCTAssertEqual(EventorCondition.ConditionType.greaterThan.rawValue, "GT")
        XCTAssertEqual(EventorCondition.ConditionType.greaterThanOrEqual.rawValue, "GTE")
        XCTAssertEqual(EventorCondition.ConditionType.lessThan.rawValue, "LT")
        XCTAssertEqual(EventorCondition.ConditionType.lessThanOrEqual.rawValue, "LTE")
        XCTAssertEqual(EventorCondition.ConditionType.equal.rawValue, "EQ")
        XCTAssertEqual(EventorCondition.ConditionType.notEqual.rawValue, "NEQ")
        XCTAssertEqual(EventorCondition.ConditionType.between.rawValue, "BETWEEN")
        XCTAssertEqual(EventorCondition.ConditionType.notBetween.rawValue, "NOT_BETWEEN")
        XCTAssertEqual(EventorCondition.ConditionType.changed.rawValue, "CHANGED")
    }

    func testConditionTypeSymbols() {
        XCTAssertEqual(EventorCondition.ConditionType.greaterThan.symbol, ">")
        XCTAssertEqual(EventorCondition.ConditionType.greaterThanOrEqual.symbol, "≥")
        XCTAssertEqual(EventorCondition.ConditionType.lessThan.symbol, "<")
        XCTAssertEqual(EventorCondition.ConditionType.lessThanOrEqual.symbol, "≤")
        XCTAssertEqual(EventorCondition.ConditionType.equal.symbol, "=")
        XCTAssertEqual(EventorCondition.ConditionType.notEqual.symbol, "≠")
        XCTAssertEqual(EventorCondition.ConditionType.between.symbol, "∈")
        XCTAssertEqual(EventorCondition.ConditionType.notBetween.symbol, "∉")
        XCTAssertEqual(EventorCondition.ConditionType.changed.symbol, "Δ")
    }

    func testConditionTypeDisplayNames() {
        XCTAssertEqual(EventorCondition.ConditionType.greaterThan.displayName, "Greater than")
        XCTAssertEqual(EventorCondition.ConditionType.between.displayName, "Between")
        XCTAssertEqual(EventorCondition.ConditionType.changed.displayName, "Value changed")
    }

    func testConditionTypeCaseIterable() {
        XCTAssertEqual(EventorCondition.ConditionType.allCases.count, 9)
    }

    func testConditionTypeCodableRoundTrip() throws {
        for ct in EventorCondition.ConditionType.allCases {
            let data = try encoder.encode(ct)
            let decoded = try decoder.decode(EventorCondition.ConditionType.self, from: data)
            XCTAssertEqual(decoded, ct)
        }
    }

    // MARK: - EventorCondition displayText

    func testConditionDisplayTextGreaterThan() {
        let c = EventorCondition(type: .greaterThan, value: 30.0)
        XCTAssertEqual(c.displayText, "> 30.0")
    }

    func testConditionDisplayTextLessThanOrEqual() {
        let c = EventorCondition(type: .lessThanOrEqual, value: 100.5)
        XCTAssertEqual(c.displayText, "≤ 100.5")
    }

    func testConditionDisplayTextEqual() {
        let c = EventorCondition(type: .equal, value: 0.0)
        XCTAssertEqual(c.displayText, "= 0.0")
    }

    func testConditionDisplayTextBetween() {
        let c = EventorCondition(type: .between, left: 10, right: 50)
        XCTAssertEqual(c.displayText, "∈ [10, 50]")
    }

    func testConditionDisplayTextNotBetween() {
        let c = EventorCondition(type: .notBetween, left: 0, right: 100)
        XCTAssertEqual(c.displayText, "∉ [0, 100]")
    }

    func testConditionDisplayTextChanged() {
        let c = EventorCondition(type: .changed)
        XCTAssertEqual(c.displayText, "Value changed")
    }

    func testConditionDisplayTextNilType() {
        let c = EventorCondition()
        XCTAssertEqual(c.displayText, "?")
    }

    func testConditionDisplayTextNilValue() {
        let c = EventorCondition(type: .greaterThan)
        XCTAssertEqual(c.displayText, "> ?")
    }

    func testConditionDisplayTextBetweenPartialNil() {
        let c = EventorCondition(type: .between, left: 10)
        XCTAssertEqual(c.displayText, "∈ [10, ?]")
    }

    // MARK: - EventorCondition Codable

    func testConditionCodableRoundTrip() throws {
        let original = EventorCondition(type: .between, value: nil, left: 20, right: 80)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EventorCondition.self, from: data)
        XCTAssertEqual(decoded.type, .between)
        XCTAssertEqual(decoded.left, 20)
        XCTAssertEqual(decoded.right, 80)
        XCTAssertNil(decoded.value)
    }

    func testConditionCodableAllTypes() throws {
        let types: [(EventorCondition.ConditionType, Double?, Double?, Double?)] = [
            (.greaterThan, 25, nil, nil),
            (.lessThan, 10, nil, nil),
            (.equal, 0, nil, nil),
            (.between, nil, 5, 50),
            (.changed, nil, nil, nil),
        ]
        for (type, val, left, right) in types {
            let c = EventorCondition(type: type, value: val, left: left, right: right)
            let data = try encoder.encode(c)
            let decoded = try decoder.decode(EventorCondition.self, from: data)
            XCTAssertEqual(decoded.type, type)
        }
    }

    // MARK: - ActionType

    func testActionTypeRawValues() {
        XCTAssertEqual(EventorAction.ActionType.setPin.rawValue, "SETPIN")
        XCTAssertEqual(EventorAction.ActionType.setProperty.rawValue, "SET_PROP")
        XCTAssertEqual(EventorAction.ActionType.notify.rawValue, "NOTIFY")
        XCTAssertEqual(EventorAction.ActionType.mail.rawValue, "MAIL")
        XCTAssertEqual(EventorAction.ActionType.tweet.rawValue, "TWIT")
    }

    func testActionTypeIcons() {
        XCTAssertEqual(EventorAction.ActionType.setPin.icon, "pin.fill")
        XCTAssertEqual(EventorAction.ActionType.notify.icon, "bell.fill")
        XCTAssertEqual(EventorAction.ActionType.mail.icon, "envelope.fill")
    }

    func testActionTypeDisplayNames() {
        XCTAssertEqual(EventorAction.ActionType.setPin.displayName, "Set Pin")
        XCTAssertEqual(EventorAction.ActionType.notify.displayName, "Send Notification")
        XCTAssertEqual(EventorAction.ActionType.mail.displayName, "Send Email")
    }

    // MARK: - EventorAction displayText

    func testActionDisplayTextSetPin() {
        let a = EventorAction(type: .setPin, pin: EventorDataStream(pin: 5, pinType: .virtual), value: "255")
        XCTAssertEqual(a.displayText, "Set V5 → 255")
    }

    func testActionDisplayTextSetPinNilPin() {
        let a = EventorAction(type: .setPin, value: "1")
        XCTAssertEqual(a.displayText, "Set ? → 1")
    }

    func testActionDisplayTextSetPinNilValue() {
        let a = EventorAction(type: .setPin, pin: EventorDataStream(pin: 0))
        XCTAssertEqual(a.displayText, "Set V0 → ?")
    }

    func testActionDisplayTextNotify() {
        let a = EventorAction(type: .notify, message: "Temperature alert!")
        XCTAssertEqual(a.displayText, "Temperature alert!")
    }

    func testActionDisplayTextNotifyNoMessage() {
        let a = EventorAction(type: .notify)
        XCTAssertEqual(a.displayText, "Notification")
    }

    func testActionDisplayTextMail() {
        let a = EventorAction(type: .mail, message: "body", subject: "Alert")
        XCTAssertEqual(a.displayText, "Alert")
    }

    func testActionDisplayTextMailNoSubject() {
        let a = EventorAction(type: .mail, message: "body text")
        XCTAssertEqual(a.displayText, "body text")
    }

    func testActionDisplayTextNilType() {
        let a = EventorAction()
        XCTAssertEqual(a.displayText, "?")
    }

    func testActionDisplayTextSetProperty() {
        let a = EventorAction(type: .setProperty)
        XCTAssertEqual(a.displayText, "Set property")
    }

    func testActionDisplayTextTweet() {
        let a = EventorAction(type: .tweet, message: "Hello from Plynx!")
        XCTAssertEqual(a.displayText, "Hello from Plynx!")
    }

    // MARK: - EventorAction Codable

    func testActionCodableRoundTrip() throws {
        let original = EventorAction(
            type: .setPin,
            pin: EventorDataStream(pin: 10, pinType: .virtual),
            value: "1",
            setPinType: .custom
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EventorAction.self, from: data)
        XCTAssertEqual(decoded.type, .setPin)
        XCTAssertEqual(decoded.pin?.pin, 10)
        XCTAssertEqual(decoded.pin?.pinType, .virtual)
        XCTAssertEqual(decoded.value, "1")
        XCTAssertEqual(decoded.setPinType, .custom)
    }

    func testActionCodableNotify() throws {
        let original = EventorAction(type: .notify, message: "Alert!")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EventorAction.self, from: data)
        XCTAssertEqual(decoded.type, .notify)
        XCTAssertEqual(decoded.message, "Alert!")
        XCTAssertNil(decoded.pin)
    }

    func testSetPinTypeCodable() throws {
        for spt in [EventorAction.SetPinType.on, .off, .custom] {
            let data = try encoder.encode(spt)
            let decoded = try decoder.decode(EventorAction.SetPinType.self, from: data)
            XCTAssertEqual(decoded, spt)
        }
    }

    // MARK: - EventorDataStream

    func testDataStreamDefaults() {
        let ds = EventorDataStream(pin: 5)
        XCTAssertEqual(ds.pin, 5)
        XCTAssertEqual(ds.pinType, .virtual)
        XCTAssertNil(ds.pwmMode)
        XCTAssertNil(ds.rangeMappingOn)
    }

    func testDataStreamCodableRoundTrip() throws {
        var ds = EventorDataStream(pin: 3, pinType: .digital)
        ds.min = 0
        ds.max = 255
        ds.label = "LED"
        let data = try encoder.encode(ds)
        let decoded = try decoder.decode(EventorDataStream.self, from: data)
        XCTAssertEqual(decoded.pin, 3)
        XCTAssertEqual(decoded.pinType, .digital)
        XCTAssertEqual(decoded.min, 0)
        XCTAssertEqual(decoded.max, 255)
        XCTAssertEqual(decoded.label, "LED")
    }

    // MARK: - EventorTimerTime

    func testTimerTimeCodableRoundTrip() throws {
        let timer = EventorTimerTime(id: 1, days: [1, 3, 5], time: 54000, tzName: "Europe/Rome")
        let data = try encoder.encode(timer)
        let decoded = try decoder.decode(EventorTimerTime.self, from: data)
        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.days, [1, 3, 5])
        XCTAssertEqual(decoded.time, 54000)
        XCTAssertEqual(decoded.tzName, "Europe/Rome")
    }

    // MARK: - EventorRule

    func testRuleCodableRoundTrip() throws {
        let rule = EventorRule(
            triggerPin: EventorDataStream(pin: 5, pinType: .virtual),
            condition: EventorCondition(type: .greaterThan, value: 30),
            actions: [
                EventorAction(type: .setPin, pin: EventorDataStream(pin: 10), value: "1"),
                EventorAction(type: .notify, message: "High temp!")
            ],
            isActive: true
        )
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(EventorRule.self, from: data)
        XCTAssertEqual(decoded.triggerPin?.pin, 5)
        XCTAssertEqual(decoded.triggerPin?.pinType, .virtual)
        XCTAssertEqual(decoded.condition?.type, .greaterThan)
        XCTAssertEqual(decoded.condition?.value, 30)
        XCTAssertEqual(decoded.actions?.count, 2)
        XCTAssertEqual(decoded.actions?[0].type, .setPin)
        XCTAssertEqual(decoded.actions?[0].value, "1")
        XCTAssertEqual(decoded.actions?[1].type, .notify)
        XCTAssertEqual(decoded.actions?[1].message, "High temp!")
        XCTAssertEqual(decoded.isActive, true)
    }

    func testRuleWithTimerTrigger() throws {
        let rule = EventorRule(
            triggerTime: EventorTimerTime(id: 0, days: [0, 1, 2, 3, 4], time: 28800, tzName: "UTC"),
            actions: [EventorAction(type: .setPin, pin: EventorDataStream(pin: 1), value: "1")],
            isActive: true
        )
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(EventorRule.self, from: data)
        XCTAssertNil(decoded.triggerPin)
        XCTAssertEqual(decoded.triggerTime?.days, [0, 1, 2, 3, 4])
        XCTAssertEqual(decoded.triggerTime?.time, 28800)
    }

    func testRuleInactive() throws {
        let rule = EventorRule(
            triggerPin: EventorDataStream(pin: 0),
            condition: EventorCondition(type: .equal, value: 0),
            actions: [],
            isActive: false
        )
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(EventorRule.self, from: data)
        XCTAssertEqual(decoded.isActive, false)
    }

    func testRuleMinimalEmpty() throws {
        let rule = EventorRule()
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(EventorRule.self, from: data)
        XCTAssertNil(decoded.triggerPin)
        XCTAssertNil(decoded.triggerTime)
        XCTAssertNil(decoded.condition)
        XCTAssertNil(decoded.actions)
        XCTAssertEqual(decoded.isActive, true)
    }

    func testRuleMultipleActions() throws {
        let rule = EventorRule(
            triggerPin: EventorDataStream(pin: 2, pinType: .virtual),
            condition: EventorCondition(type: .between, left: 20, right: 30),
            actions: [
                EventorAction(type: .setPin, pin: EventorDataStream(pin: 3), value: "255"),
                EventorAction(type: .setPin, pin: EventorDataStream(pin: 4), value: "0"),
                EventorAction(type: .notify, message: "In range"),
                EventorAction(type: .mail, message: "Body", subject: "Subject")
            ],
            isActive: true
        )
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(EventorRule.self, from: data)
        XCTAssertEqual(decoded.actions?.count, 4)
        XCTAssertEqual(decoded.actions?[2].type, .notify)
        XCTAssertEqual(decoded.actions?[3].type, .mail)
        XCTAssertEqual(decoded.actions?[3].subject, "Subject")
    }

    // MARK: - JSON compatibility (server format)

    func testConditionFromServerJSON() throws {
        let json = """
        {"type":"GT","value":25.5}
        """.data(using: .utf8)!
        let c = try decoder.decode(EventorCondition.self, from: json)
        XCTAssertEqual(c.type, .greaterThan)
        XCTAssertEqual(c.value, 25.5)
    }

    func testActionFromServerJSON() throws {
        let json = """
        {"type":"SETPIN","pin":{"pin":5,"pinType":"VIRTUAL"},"value":"1","setPinType":"CUSTOM"}
        """.data(using: .utf8)!
        let a = try decoder.decode(EventorAction.self, from: json)
        XCTAssertEqual(a.type, .setPin)
        XCTAssertEqual(a.pin?.pin, 5)
        XCTAssertEqual(a.value, "1")
        XCTAssertEqual(a.setPinType, .custom)
    }

    func testRuleFromServerJSON() throws {
        let json = """
        {
            "triggerPin": {"pin": 5, "pinType": "VIRTUAL"},
            "condition": {"type": "LTE", "value": 10.0},
            "actions": [{"type": "NOTIFY", "message": "Low value"}],
            "isActive": true
        }
        """.data(using: .utf8)!
        let rule = try decoder.decode(EventorRule.self, from: json)
        XCTAssertEqual(rule.triggerPin?.pin, 5)
        XCTAssertEqual(rule.condition?.type, .lessThanOrEqual)
        XCTAssertEqual(rule.actions?.first?.type, .notify)
        XCTAssertEqual(rule.actions?.first?.message, "Low value")
    }

    func testConditionBetweenFromServerJSON() throws {
        let json = """
        {"type":"BETWEEN","left":15.0,"right":35.0}
        """.data(using: .utf8)!
        let c = try decoder.decode(EventorCondition.self, from: json)
        XCTAssertEqual(c.type, .between)
        XCTAssertEqual(c.left, 15)
        XCTAssertEqual(c.right, 35)
        XCTAssertNil(c.value)
    }
}
