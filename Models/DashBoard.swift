//
//  DashBoard.swift
//  PlynxConnector
//
//  Dashboard model for Plynx.
//

import Foundation

/// Represents a dashboard (project) in Plynx.
public struct DashBoard: Codable, Sendable, Identifiable {
    /// Dashboard ID
    public var id: Int
    
    /// Parent dashboard ID (-1 if this is a parent)
    public var parentId: Int?
    
    /// Whether this is a preview/clone
    public var isPreview: Bool?
    
    /// Dashboard name
    public var name: String?
    
    /// Creation timestamp (millis since epoch)
    public var createdAt: Int64?
    
    /// Last update timestamp (millis since epoch)
    public var updatedAt: Int64?
    
    /// Widgets on this dashboard
    public var widgets: [Widget]?
    
    /// Devices in this dashboard
    public var devices: [Device]?
    
    /// Tags for grouping devices
    public var tags: [Tag]?
    
    /// Color theme
    public var theme: Theme?
    
    /// Keep screen on while viewing
    public var keepScreenOn: Bool?
    
    /// Show app connected indicator
    public var isAppConnectedOn: Bool?
    
    /// Disable notifications
    public var isNotificationsOff: Bool?
    
    /// Whether sharing is enabled
    public var isShared: Bool?
    
    /// Whether dashboard is currently active
    public var isActive: Bool?
    
    /// Show widget background
    public var widgetBackgroundOn: Bool?
    
    /// Background color (as int)
    public var color: Int?
    
    /// Using default color
    public var isDefaultColor: Bool?
    
    public init(id: Int = 0, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

/// User profile containing all dashboards.
public struct Profile: Codable, Sendable {
    public var dashBoards: [DashBoard]?
    public var apps: [App]?
    
    public init() {}
}
