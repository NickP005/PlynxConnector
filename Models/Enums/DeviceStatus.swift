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
}
