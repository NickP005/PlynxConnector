//
//  GraphPeriod.swift
//  PlynxConnector
//
//  Time periods for graph data queries.
//

import Foundation

/// Time periods for querying graph data.
public enum GraphPeriod: String, Codable, Sendable {
    case live = "LIVE"
    case oneHour = "ONE_HOUR"
    case sixHours = "SIX_HOURS"
    case day = "DAY"
    case week = "WEEK"
    case month = "MONTH"
    case threeMonths = "THREE_MONTHS"
    case unknown = "UNKNOWN"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = GraphPeriod(rawValue: value) ?? .unknown
    }
}
