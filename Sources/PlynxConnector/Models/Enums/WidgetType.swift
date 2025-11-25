//
//  WidgetType.swift
//  PlynxConnector
//
//  All widget types available in Plynx.
//

import Foundation

/// Widget types supported by Plynx.
public enum WidgetType: String, Codable, Sendable {
    // MARK: - Controls
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
    
    // MARK: - Outputs
    case led = "LED"
    case digit4Display = "DIGIT4_DISPLAY"
    case labeledValueDisplay = "LABELED_VALUE_DISPLAY"
    case gauge = "GAUGE"
    case lcd = "LCD"
    case levelDisplay = "LEVEL_DISPLAY"
    case verticalLevelDisplay = "VERTICAL_LEVEL_DISPLAY"
    case video = "VIDEO"
    case enhancedGraph = "ENHANCED_GRAPH" // Superchart
    
    // MARK: - Sensors
    case gpsTrigger = "GPS_TRIGGER"
    case gpsStreaming = "GPS_STREAMING"
    case light = "LIGHT"
    case proximity = "PROXIMITY"
    case temperature = "TEMPERATURE"
    case accelerometer = "ACCELEROMETER"
    case gravity = "GRAVITY"
    case barometer = "BAROMETER"
    case humidity = "HUMIDITY"
    
    // MARK: - Notifications
    case twitter = "TWITTER"
    case emailWidget = "EMAIL"
    case notification = "NOTIFICATION"
    case smsWidget = "SMS"
    
    // MARK: - Interface
    case menu = "MENU"
    case tabs = "TABS"
    case player = "PLAYER"
    case table = "TABLE"
    case image = "IMAGE"
    case report = "REPORT"
    
    // MARK: - Others
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
    
    /// Unknown widget type
    case unknown = "UNKNOWN"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)
        self = WidgetType(rawValue: type) ?? .unknown
    }
}
