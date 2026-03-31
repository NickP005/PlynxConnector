//
//  DeviceStatus.swift
//  PlynxConnector
//
//  Device connection status.
//

import Foundation

/// Device connection status.
public enum DeviceStatus: String, Codable, Sendable {
    case online = "ONLINE"
    case offline = "OFFLINE"
    case unknown = "UNKNOWN"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = DeviceStatus(rawValue: value) ?? .unknown
    }
}
