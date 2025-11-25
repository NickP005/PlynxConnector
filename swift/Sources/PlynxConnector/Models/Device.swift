//
//  Device.swift
//  PlynxConnector
//
//  Device model for Plynx dashboards.
//

import Foundation

/// Represents a hardware device connected to a dashboard.
public struct Device: Codable, Sendable, Identifiable {
    /// Device ID within the dashboard
    public var id: Int
    
    /// Device name (user-configurable)
    public var name: String?
    
    /// Hardware board type
    public var boardType: BoardType?
    
    /// Bluetooth address (if applicable)
    public var address: String?
    
    /// Authentication token (may be nil in responses)
    public var token: String?
    
    /// Hardware vendor
    public var vendor: String?
    
    /// How the device connects
    public var connectionType: ConnectionType?
    
    /// Current connection status
    public var status: DeviceStatus?
    
    /// Last disconnect timestamp (millis since epoch)
    public var disconnectTime: Int64?
    
    /// Last connect timestamp (millis since epoch)
    public var connectTime: Int64?
    
    /// First ever connect timestamp (millis since epoch)
    public var firstConnectTime: Int64?
    
    /// Last data received timestamp (millis since epoch)
    public var dataReceivedAt: Int64?
    
    /// Last known IP address
    public var lastLoggedIP: String?
    
    /// Hardware info (firmware version, etc.)
    public var hardwareInfo: HardwareInfo?
    
    /// OTA update info
    public var deviceOtaInfo: DeviceOtaInfo?
    
    /// Icon name for display
    public var iconName: String?
    
    /// Whether using a user-uploaded icon
    public var isUserIcon: Bool?
    
    public init(
        id: Int,
        name: String? = nil,
        boardType: BoardType? = nil,
        token: String? = nil
    ) {
        self.id = id
        self.name = name
        self.boardType = boardType
        self.token = token
    }
}

/// Hardware information reported by device.
public struct HardwareInfo: Codable, Sendable {
    public var version: String?
    public var blynkVersion: String?
    public var boardType: String?
    public var cpuType: String?
    public var connectionType: String?
    public var build: String?
    public var templateId: String?
    
    public init() {}
}

/// OTA (Over-The-Air) update information.
public struct DeviceOtaInfo: Codable, Sendable {
    public var otaInitiatedBy: String?
    public var otaInitiatedAt: Int64?
    public var otaUpdateAt: Int64?
    
    public init() {}
}

/// Device with status info for list responses.
public struct DeviceStatusDTO: Codable, Sendable {
    public var id: Int
    public var name: String?
    public var boardType: BoardType?
    public var status: DeviceStatus?
    public var disconnectTime: Int64?
    public var connectTime: Int64?
    public var lastLoggedIP: String?
    public var hardwareInfo: HardwareInfo?
    public var iconName: String?
    public var isUserIcon: Bool?
}
