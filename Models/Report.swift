//
//  Report.swift
//  PlynxConnector
//
//  Report model for scheduled data exports.
//

import Foundation

/// Report configuration for scheduled data exports.
public struct Report: Codable, Sendable, Identifiable {
    /// Report ID
    public var id: Int
    
    /// Report name
    public var name: String?
    
    /// Data streams to include
    public var dataStreams: [ReportDataStream]?
    
    /// Report schedule type
    public var reportType: ReportType?
    
    /// Period for data aggregation
    public var granularityType: GranularityType?
    
    /// Is report enabled
    public var isActive: Bool?
    
    /// Recipients (email addresses)
    public var recipients: String?
    
    /// Timezone for scheduling
    public var tzName: String?
    
    /// Days of week (for weekly reports)
    public var dayOfWeek: Int?
    
    /// Hour to send (0-23)
    public var atTime: Int?
    
    /// Last report sent timestamp
    public var lastReportAt: Int64?
    
    /// Next scheduled report timestamp
    public var nextReportAt: Int64?
    
    public init(id: Int, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

/// Data stream reference in a report.
public struct ReportDataStream: Codable, Sendable {
    public var deviceId: Int?
    public var pin: Int?
    public var pinType: PinType?
    public var label: String?
    
    public init(deviceId: Int, pin: Int, pinType: PinType = .virtual) {
        self.deviceId = deviceId
        self.pin = pin
        self.pinType = pinType
    }
}

/// Report schedule types.
public enum ReportType: String, Codable, Sendable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
}

/// Data aggregation period.
public enum GranularityType: String, Codable, Sendable {
    case minute = "MINUTE"
    case hourly = "HOURLY"
    case daily = "DAILY"
}
