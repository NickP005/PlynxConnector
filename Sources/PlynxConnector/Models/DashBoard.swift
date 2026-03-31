//
//  DashBoard.swift
//  PlynxConnector
//
//  Dashboard model for Plynx.
//

import Foundation

/// Represents a dashboard (project) in Plynx.
public struct DashBoard: Codable, Sendable, Identifiable, Hashable {
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
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, parentId, isPreview, name, createdAt, updatedAt
        case widgets, devices, tags, theme
        case keepScreenOn, isAppConnectedOn, isNotificationsOff
        case isShared, isActive, widgetBackgroundOn, color, isDefaultColor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        parentId = try container.decodeIfPresent(Int.self, forKey: .parentId)
        isPreview = try container.decodeIfPresent(Bool.self, forKey: .isPreview)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        createdAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt)
        
        widgets = DashBoard.decodeLossyArray(Widget.self, from: container, forKey: .widgets)
        devices = DashBoard.decodeLossyArray(Device.self, from: container, forKey: .devices)
        
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags)
        theme = try? container.decodeIfPresent(Theme.self, forKey: .theme)
        keepScreenOn = try container.decodeIfPresent(Bool.self, forKey: .keepScreenOn)
        isAppConnectedOn = try container.decodeIfPresent(Bool.self, forKey: .isAppConnectedOn)
        isNotificationsOff = try container.decodeIfPresent(Bool.self, forKey: .isNotificationsOff)
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        widgetBackgroundOn = try container.decodeIfPresent(Bool.self, forKey: .widgetBackgroundOn)
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        isDefaultColor = try container.decodeIfPresent(Bool.self, forKey: .isDefaultColor)
    }
    
    private static func decodeLossyArray<T: Decodable>(_ type: T.Type, from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> [T]? {
        guard var unkeyedContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            return nil
        }
        var result: [T] = []
        while !unkeyedContainer.isAtEnd {
            if let element = try? unkeyedContainer.decode(T.self) {
                result.append(element)
            } else {
                _ = try? unkeyedContainer.decode(AnyCodable.self)
            }
        }
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: DashBoard, rhs: DashBoard) -> Bool {
        lhs.id == rhs.id
    }
}

private struct AnyCodable: Decodable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer().decode(String.self)
    }
}

/// User profile containing all dashboards.
public struct Profile: Codable, Sendable {
    public var dashBoards: [DashBoard]?
    public var apps: [App]?
    
    public init() {}
    
    enum CodingKeys: String, CodingKey {
        case dashBoards, apps
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if var unkeyedContainer = try? container.nestedUnkeyedContainer(forKey: .dashBoards) {
            var boards: [DashBoard] = []
            while !unkeyedContainer.isAtEnd {
                if let board = try? unkeyedContainer.decode(DashBoard.self) {
                    boards.append(board)
                } else {
                    _ = try? unkeyedContainer.decode(AnyCodable.self)
                }
            }
            dashBoards = boards.isEmpty ? nil : boards
        } else {
            dashBoards = nil
        }
        
        apps = try? container.decodeIfPresent([App].self, forKey: .apps)
    }
}
