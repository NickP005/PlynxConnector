//
//  TileTemplate.swift
//  PlynxConnector
//
//  Tile template for DeviceTiles widget.
//

import Foundation

/// Template for tiles in DeviceTiles widget.
public struct TileTemplate: Codable, Sendable, Identifiable {
    /// Template ID
    public var id: Int
    
    /// Template name
    public var name: String?
    
    /// Board types this template applies to
    public var boardTypes: [BoardType]?
    
    /// Widgets in this template
    public var widgets: [Widget]?
    
    /// Device IDs using this template
    public var deviceIds: [Int]?
    
    /// Data streams for this template
    public var dataStreams: [DataStream]?
    
    /// Template icon
    public var iconName: String?
    
    /// Tile color
    public var color: Int?
    
    public init(id: Int, name: String? = nil) {
        self.id = id
        self.name = name
    }
}
