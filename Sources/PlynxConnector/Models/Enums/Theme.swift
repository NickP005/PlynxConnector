//
//  Theme.swift
//  PlynxConnector
//
//  Dashboard themes.
//

import Foundation

/// Dashboard color themes.
public enum Theme: String, Codable, Sendable {
    case blynk = "Blynk"
    case blynkLight = "BlynkLight"
    case sparkFun = "SparkFun"
    case unknown = "UNKNOWN"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = Theme(rawValue: value) ?? .unknown
    }
}
