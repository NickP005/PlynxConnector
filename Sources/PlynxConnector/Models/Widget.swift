//
//  Widget.swift
//  PlynxConnector
//
//  Widget model for Plynx dashboards.
//

import Foundation

/// Represents a widget on a dashboard.
public struct Widget: Codable, Sendable, Identifiable {
    /// Widget ID
    public var id: Int
    
    /// Widget type
    public var type: WidgetType?
    
    /// X position on grid
    public var x: Int?
    
    /// Y position on grid
    public var y: Int?
    
    /// Width in grid units
    public var width: Int?
    
    /// Height in grid units
    public var height: Int?
    
    /// Tab ID (for tabbed dashboards)
    public var tabId: Int?
    
    /// Display label
    public var label: String?
    
    /// Widget color (as int)
    public var color: Int?
    
    /// Device ID this widget is bound to
    public var deviceId: Int?
    
    /// Pin number
    public var pin: Int?
    
    /// Pin type
    public var pinType: PinType?
    
    /// Current value
    public var value: String?
    
    /// Minimum value (for sliders, etc.)
    public var min: Double?
    
    /// Maximum value (for sliders, etc.)
    public var max: Double?
    
    /// Frequency of updates in milliseconds
    public var frequency: Int?
    
    /// PWM mode enabled
    public var pwmMode: Bool?
    
    /// Range mapping enabled
    public var rangeMappingOn: Bool?
    
    // MARK: - Button/Switch specific
    
    /// On label text
    public var onLabel: String?
    
    /// Off label text
    public var offLabel: String?
    
    /// Push mode (momentary) vs toggle
    public var pushMode: Bool?
    
    // MARK: - StyledButton specific
    
    /// On button state (text, colors)
    public var onButtonState: ButtonState?
    
    /// Off button state (text, colors)
    public var offButtonState: ButtonState?
    
    // MARK: - Slider specific
    
    /// Send value only on release (false = real-time)
    public var sendOnReleaseOn: Bool?
    
    // MARK: - Step widget specific
    
    /// Step increment value
    public var step: Float?
    
    /// Arrows visible
    public var isArrowsOn: Bool?
    
    /// Loop when reaching min/max
    public var isLoopOn: Bool?
    
    /// Send step delta instead of absolute value
    public var isSendStep: Bool?
    
    /// Show current value
    public var showValueOn: Bool?
    
    // MARK: - Joystick specific
    
    /// Split mode - sends X/Y to separate pins
    public var split: Bool?
    
    /// Auto return to center when released
    public var autoReturnOn: Bool?
    
    // MARK: - RGB (ZeRGBa) specific
    
    /// Split mode for RGB - sends R/G/B to separate pins
    public var splitMode: Bool?
    
    // MARK: - Display specific
    
    /// Value formatting string
    public var valueFormatting: String?
    
    /// Text alignment
    public var textAlignment: String?
    
    /// Suffix text
    public var suffix: String?
    
    /// Maximum fraction digits
    public var maximumFractionDigits: Int?
    
    // MARK: - Graph specific
    
    /// Data streams for graph widgets
    public var dataStreams: [DataStream]?
    
    // MARK: - Menu/Segmented specific
    
    /// Labels for menu items
    public var labels: [String]?
    
    // MARK: - Timer specific
    
    /// Start time (seconds from midnight)
    public var startAt: Int?
    
    /// Stop time (seconds from midnight)
    public var stopAt: Int?
    
    /// Days of week (bitmask)
    public var days: Int?
    
    /// Timezone
    public var timezone: String?
    
    // MARK: - Image/Video specific
    
    /// URL for image/video
    public var url: String?
    
    /// Multiple URLs
    public var urls: [String]?
    
    // MARK: - Terminal specific
    
    /// Auto scroll enabled
    public var autoScrollOn: Bool?
    
    /// Text input enabled
    public var textInputOn: Bool?
    
    /// Text light mode
    public var textLightOn: Bool?
    
    // MARK: - Notification specific
    
    /// Notification token
    public var notifyWhenOffline: Bool?
    
    /// Notification body
    public var notifyBody: String?
    
    // MARK: - Tabs specific
    
    /// Tabs for Tabs widget
    public var tabs: [TabItem]?
    
    // MARK: - DeviceTiles specific
    
    /// Tile templates
    public var templates: [TileTemplate]?
    
    /// Tiles
    public var tiles: [Tile]?
    
    // MARK: - Report specific
    
    /// Reports in this widget
    public var reports: [Report]?
    
    public init(id: Int, type: WidgetType? = nil) {
        self.id = id
        self.type = type
    }
    
    // Custom coding keys to handle 'type' being a string in JSON
    enum CodingKeys: String, CodingKey {
        case id, type, x, y, width, height, tabId, label, color
        case deviceId, pin, pinType, value, min, max, frequency
        case pwmMode, rangeMappingOn, onLabel, offLabel, pushMode
        case onButtonState, offButtonState, sendOnReleaseOn
        case step, isArrowsOn, isLoopOn, isSendStep, showValueOn
        case split, autoReturnOn, splitMode
        case valueFormatting, textAlignment, suffix, maximumFractionDigits
        case dataStreams  // Changed: use "dataStreams" directly (works for Superchart)
        case pins         // Also try "pins" for MultiPinWidget compatibility
        case labels, startAt, stopAt, days, timezone
        case url, urls, autoScrollOn, textInputOn, textLightOn
        case notifyWhenOffline, notifyBody, templates, tiles, reports, tabs
    }
    
    // Custom decoder to handle both "dataStreams" and "pins" keys
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decodeIfPresent(WidgetType.self, forKey: .type)
        x = try container.decodeIfPresent(Int.self, forKey: .x)
        y = try container.decodeIfPresent(Int.self, forKey: .y)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        tabId = try container.decodeIfPresent(Int.self, forKey: .tabId)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        deviceId = try container.decodeIfPresent(Int.self, forKey: .deviceId)
        pin = try container.decodeIfPresent(Int.self, forKey: .pin)
        pinType = try container.decodeIfPresent(PinType.self, forKey: .pinType)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        min = try container.decodeIfPresent(Double.self, forKey: .min)
        max = try container.decodeIfPresent(Double.self, forKey: .max)
        frequency = try container.decodeIfPresent(Int.self, forKey: .frequency)
        pwmMode = try container.decodeIfPresent(Bool.self, forKey: .pwmMode)
        rangeMappingOn = try container.decodeIfPresent(Bool.self, forKey: .rangeMappingOn)
        onLabel = try container.decodeIfPresent(String.self, forKey: .onLabel)
        offLabel = try container.decodeIfPresent(String.self, forKey: .offLabel)
        pushMode = try container.decodeIfPresent(Bool.self, forKey: .pushMode)
        onButtonState = try container.decodeIfPresent(ButtonState.self, forKey: .onButtonState)
        offButtonState = try container.decodeIfPresent(ButtonState.self, forKey: .offButtonState)
        sendOnReleaseOn = try container.decodeIfPresent(Bool.self, forKey: .sendOnReleaseOn)
        step = try container.decodeIfPresent(Double.self, forKey: .step)
        isArrowsOn = try container.decodeIfPresent(Bool.self, forKey: .isArrowsOn)
        isLoopOn = try container.decodeIfPresent(Bool.self, forKey: .isLoopOn)
        isSendStep = try container.decodeIfPresent(Bool.self, forKey: .isSendStep)
        showValueOn = try container.decodeIfPresent(Bool.self, forKey: .showValueOn)
        split = try container.decodeIfPresent(Bool.self, forKey: .split)
        autoReturnOn = try container.decodeIfPresent(Bool.self, forKey: .autoReturnOn)
        splitMode = try container.decodeIfPresent(Bool.self, forKey: .splitMode)
        valueFormatting = try container.decodeIfPresent(String.self, forKey: .valueFormatting)
        textAlignment = try container.decodeIfPresent(String.self, forKey: .textAlignment)
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
        maximumFractionDigits = try container.decodeIfPresent(Int.self, forKey: .maximumFractionDigits)
        
        // Try "dataStreams" first (for Superchart), then "pins" (for MultiPinWidget)
        if let streams = try container.decodeIfPresent([DataStream].self, forKey: .dataStreams) {
            dataStreams = streams
        } else if let pins = try container.decodeIfPresent([DataStream].self, forKey: .pins) {
            dataStreams = pins
        } else {
            dataStreams = nil
        }
        
        labels = try container.decodeIfPresent([String].self, forKey: .labels)
        startAt = try container.decodeIfPresent(Int.self, forKey: .startAt)
        stopAt = try container.decodeIfPresent(Int.self, forKey: .stopAt)
        days = try container.decodeIfPresent(Int.self, forKey: .days)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        urls = try container.decodeIfPresent([String].self, forKey: .urls)
        autoScrollOn = try container.decodeIfPresent(Bool.self, forKey: .autoScrollOn)
        textInputOn = try container.decodeIfPresent(Bool.self, forKey: .textInputOn)
        textLightOn = try container.decodeIfPresent(Bool.self, forKey: .textLightOn)
        notifyWhenOffline = try container.decodeIfPresent(Bool.self, forKey: .notifyWhenOffline)
        notifyBody = try container.decodeIfPresent(String.self, forKey: .notifyBody)
        templates = try container.decodeIfPresent([TileTemplate].self, forKey: .templates)
        tiles = try container.decodeIfPresent([Tile].self, forKey: .tiles)
        reports = try container.decodeIfPresent([Report].self, forKey: .reports)
        tabs = try container.decodeIfPresent([TabItem].self, forKey: .tabs)
    }
}

/// Button state for StyledButton widget.
public struct ButtonState: Codable, Sendable {
    public var text: String?
    public var textColor: Int?
    public var backgroundColor: Int?
    public var iconName: String?
    
    public init(text: String? = nil, textColor: Int? = nil, backgroundColor: Int? = nil, iconName: String? = nil) {
        self.text = text
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.iconName = iconName
    }
}

/// Tab item for Tabs widget.
public struct TabItem: Codable, Sendable, Identifiable {
    public var id: Int
    public var label: String?
    
    public init(id: Int, label: String? = nil) {
        self.id = id
        self.label = label
    }
}

/// Data stream for MultiPinWidget (RGB, Joystick) and graph widgets.
public struct DataStream: Codable, Sendable {
    public var id: Int?
    public var pin: Int?
    public var pinType: PinType?
    public var pwmMode: Bool?
    public var rangeMappingOn: Bool?
    public var value: String?
    public var min: Double?
    public var max: Double?
    public var label: String?
    public var color: Int?
    public var suffix: String?
    public var isHidden: Bool?
    
    // GraphDataStream specific fields
    public var title: String?
    public var graphType: String?  // LINE, BAR, AREA
    public var targetId: Int?
    public var functionType: String?  // AVG, MIN, MAX, SUM
    public var dataStream: NestedDataStream?  // The actual pin config in GraphDataStream
    
    public init(pin: Int, pinType: PinType = .virtual, min: Double = 0, max: Double = 255) {
        self.pin = pin
        self.pinType = pinType
        self.min = min
        self.max = max
    }
    
    enum CodingKeys: String, CodingKey {
        case id, pin, pinType, pwmMode, rangeMappingOn, value, min, max, label, color, suffix, isHidden
        case title, graphType, targetId, functionType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        pinType = try container.decodeIfPresent(PinType.self, forKey: .pinType)
        pwmMode = try container.decodeIfPresent(Bool.self, forKey: .pwmMode)
        rangeMappingOn = try container.decodeIfPresent(Bool.self, forKey: .rangeMappingOn)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        min = try container.decodeIfPresent(Double.self, forKey: .min)
        max = try container.decodeIfPresent(Double.self, forKey: .max)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        graphType = try container.decodeIfPresent(String.self, forKey: .graphType)
        targetId = try container.decodeIfPresent(Int.self, forKey: .targetId)
        functionType = try container.decodeIfPresent(String.self, forKey: .functionType)
        
        // "pin" can be either an Int (simple pin) or a NestedDataStream object (GraphDataStream)
        // Try decoding as Int first, then as NestedDataStream object
        if let pinInt = try? container.decodeIfPresent(Int.self, forKey: .pin) {
            pin = pinInt
            dataStream = nil
        } else if let nested = try? container.decodeIfPresent(NestedDataStream.self, forKey: .pin) {
            // GraphDataStream case: "pin" is a nested object
            dataStream = nested
            pin = nested.pin  // Extract pin number from nested object
            // Also get pinType from nested if not already set at top level
            if pinType == nil {
                pinType = nested.pinType
            }
        } else {
            pin = nil
            dataStream = nil
        }
    }
}

/// Nested DataStream for GraphDataStream's "pin" field
public struct NestedDataStream: Codable, Sendable {
    public var pin: Int?
    public var pinType: PinType?
    public var pwmMode: Bool?
    public var rangeMappingOn: Bool?
    public var value: String?
    public var min: Double?
    public var max: Double?
    
    public init(pin: Int, pinType: PinType = .virtual) {
        self.pin = pin
        self.pinType = pinType
    }
}

/// Tile in DeviceTiles widget.
public struct Tile: Codable, Sendable {
    public var deviceId: Int?
    public var templateId: Int?
    public var dataStreams: [DataStream]?
    
    public init(deviceId: Int, templateId: Int) {
        self.deviceId = deviceId
        self.templateId = templateId
    }
}
