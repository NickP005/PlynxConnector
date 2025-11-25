//
//  App.swift
//  PlynxConnector
//
//  App configuration for published apps.
//

import Foundation

/// App configuration for publishing Plynx apps.
public struct App: Codable, Sendable, Identifiable {
    /// App ID
    public var id: Int
    
    /// App name
    public var name: String?
    
    /// App icon name
    public var iconName: String?
    
    /// Theme for the app
    public var theme: Theme?
    
    /// Provisioning type
    public var provisionType: ProvisionType?
    
    /// Dashboard IDs included in this app
    public var projectIds: [Int]?
    
    /// Color
    public var color: Int?
    
    /// Published
    public var isPublished: Bool?
    
    public init(id: Int = 0, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

/// Provisioning type for published apps.
public enum ProvisionType: String, Codable, Sendable {
    case staticProvision = "STATIC"
    case dynamicProvision = "DYNAMIC"
}
