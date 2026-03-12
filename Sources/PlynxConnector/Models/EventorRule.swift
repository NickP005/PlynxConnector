import Foundation

public struct EventorRule: Codable, Sendable, Identifiable {
    public var id: UUID { UUID() }

    public var triggerPin: EventorDataStream?
    public var triggerTime: EventorTimerTime?
    public var condition: EventorCondition?
    public var actions: [EventorAction]?
    public var isActive: Bool?

    public init(
        triggerPin: EventorDataStream? = nil,
        triggerTime: EventorTimerTime? = nil,
        condition: EventorCondition? = nil,
        actions: [EventorAction]? = nil,
        isActive: Bool? = true
    ) {
        self.triggerPin = triggerPin
        self.triggerTime = triggerTime
        self.condition = condition
        self.actions = actions
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case triggerPin
        case triggerTime
        case condition
        case actions
        case isActive
    }
}

public struct EventorDataStream: Codable, Sendable {
    public var pin: Int?
    public var pinType: PinType?
    public var pwmMode: Bool?
    public var rangeMappingOn: Bool?
    public var min: Double?
    public var max: Double?
    public var label: String?
    public var value: String?

    public init(pin: Int? = nil, pinType: PinType? = .virtual) {
        self.pin = pin
        self.pinType = pinType
    }
}

public struct EventorTimerTime: Codable, Sendable {
    public var id: Int?
    public var days: [Int]?
    public var time: Int?
    public var tzName: String?

    public init(id: Int? = nil, days: [Int]? = nil, time: Int? = nil, tzName: String? = nil) {
        self.id = id
        self.days = days
        self.time = time
        self.tzName = tzName
    }
}

public struct EventorCondition: Codable, Sendable {
    public var type: ConditionType?
    public var value: Double?
    public var left: Double?
    public var right: Double?

    public init(type: ConditionType? = nil, value: Double? = nil, left: Double? = nil, right: Double? = nil) {
        self.type = type
        self.value = value
        self.left = left
        self.right = right
    }

    public enum ConditionType: String, Codable, Sendable, CaseIterable {
        case greaterThan = "GT"
        case greaterThanOrEqual = "GTE"
        case lessThan = "LT"
        case lessThanOrEqual = "LTE"
        case equal = "EQ"
        case notEqual = "NEQ"
        case between = "BETWEEN"
        case notBetween = "NOT_BETWEEN"
        case changed = "CHANGED"

        public var symbol: String {
            switch self {
            case .greaterThan: return ">"
            case .greaterThanOrEqual: return "≥"
            case .lessThan: return "<"
            case .lessThanOrEqual: return "≤"
            case .equal: return "="
            case .notEqual: return "≠"
            case .between: return "∈"
            case .notBetween: return "∉"
            case .changed: return "Δ"
            }
        }

        public var displayName: String {
            switch self {
            case .greaterThan: return "Greater than"
            case .greaterThanOrEqual: return "Greater or equal"
            case .lessThan: return "Less than"
            case .lessThanOrEqual: return "Less or equal"
            case .equal: return "Equal to"
            case .notEqual: return "Not equal to"
            case .between: return "Between"
            case .notBetween: return "Not between"
            case .changed: return "Value changed"
            }
        }
    }

    public var displayText: String {
        guard let type else { return "?" }
        switch type {
        case .between, .notBetween:
            let l = left.map { String(format: "%.0f", $0) } ?? "?"
            let r = right.map { String(format: "%.0f", $0) } ?? "?"
            return "\(type.symbol) [\(l), \(r)]"
        case .changed:
            return type.displayName
        default:
            let v = value.map { String(format: "%.1f", $0) } ?? "?"
            return "\(type.symbol) \(v)"
        }
    }
}

public struct EventorAction: Codable, Sendable {
    public var type: ActionType?
    public var pin: EventorDataStream?
    public var value: String?
    public var setPinType: SetPinType?
    public var message: String?
    public var subject: String?

    public init(
        type: ActionType? = nil,
        pin: EventorDataStream? = nil,
        value: String? = nil,
        setPinType: SetPinType? = nil,
        message: String? = nil,
        subject: String? = nil
    ) {
        self.type = type
        self.pin = pin
        self.value = value
        self.setPinType = setPinType
        self.message = message
        self.subject = subject
    }

    public enum ActionType: String, Codable, Sendable {
        case setPin = "SETPIN"
        case increment = "INCREMENT"
        case multiply = "MULTIPLY"
        case setProperty = "SET_PROP"
        case notify = "NOTIFY"
        case mail = "MAIL"
        case tweet = "TWIT"

        public var icon: String {
            switch self {
            case .setPin: return "pin.fill"
            case .increment: return "plus.circle.fill"
            case .multiply: return "multiply.circle.fill"
            case .setProperty: return "gearshape.fill"
            case .notify: return "bell.fill"
            case .mail: return "envelope.fill"
            case .tweet: return "bird.fill"
            }
        }

        public var displayName: String {
            switch self {
            case .setPin: return "Set Pin"
            case .increment: return "Increase Pin"
            case .multiply: return "Multiply Pin"
            case .setProperty: return "Set Property"
            case .notify: return "Send Notification"
            case .mail: return "Send Email"
            case .tweet: return "Tweet"
            }
        }
    }

    public enum SetPinType: String, Codable, Sendable {
        case on = "ON"
        case off = "OFF"
        case custom = "CUSTOM"
    }

    public var displayText: String {
        guard let type else { return "?" }
        switch type {
        case .setPin:
            let pinDesc = pin.map { "V\($0.pin ?? 0)" } ?? "?"
            let val = value ?? "?"
            return "Set \(pinDesc) → \(val)"
        case .increment:
            let pinDesc = pin.map { "V\($0.pin ?? 0)" } ?? "?"
            let val = value ?? "?"
            return "\(pinDesc) += \(val)"
        case .multiply:
            let pinDesc = pin.map { "V\($0.pin ?? 0)" } ?? "?"
            let val = value ?? "?"
            return "\(pinDesc) × \(val)"
        case .setProperty:
            return "Set property"
        case .notify:
            return message ?? "Notification"
        case .mail:
            return subject ?? message ?? "Email"
        case .tweet:
            return message ?? "Tweet"
        }
    }
}
