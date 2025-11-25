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
        case valueFormatting, textAlignment, suffix, maximumFractionDigits
        case dataStreams, labels, startAt, stopAt, days, timezone
        case url, urls, autoScrollOn, textInputOn, textLightOn
        case notifyWhenOffline, notifyBody, templates, tiles, reports, tabs
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

/// Data stream for graph widgets.
public struct DataStream: Codable, Sendable {
    public var id: Int?
    public var pin: Int?
    public var pinType: PinType?
    public var label: String?
    public var color: Int?
    public var suffix: String?
    public var min: Double?
    public var max: Double?
    public var isHidden: Bool?
    
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
