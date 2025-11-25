//
//  Tag.swift
//  PlynxConnector
//
//  Tag model for grouping devices.
//

import Foundation

/// Tag for grouping devices.
/// Note: Tag IDs must be >= 100,000
public struct Tag: Codable, Sendable, Identifiable {
    /// Tag ID (must be >= 100,000)
    public var id: Int
    
    /// Tag name (max 40 characters)
    public var name: String?
    
    /// Device IDs in this tag (max 25)
    public var deviceIds: [Int]?
    
    /// Minimum valid tag ID
    public static let minimumId = 100_000
    
    public init(id: Int, name: String? = nil, deviceIds: [Int]? = nil) {
        self.id = max(id, Self.minimumId)
        self.name = name
        self.deviceIds = deviceIds
    }
}
