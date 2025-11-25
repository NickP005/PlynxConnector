//
//  PinType.swift
//  PlynxConnector
//
//  Pin types for hardware communication.
//

import Foundation

/// Types of pins for hardware communication.
public enum PinType: String, Codable, Sendable {
    case virtual = "VIRTUAL"
    case digital = "DIGITAL"
    case analog = "ANALOG"
    
    /// Short code used in protocol (v, d, a)
    public var code: String {
        switch self {
        case .virtual: return "v"
        case .digital: return "d"
        case .analog: return "a"
        }
    }
    
    /// Initialize from short code
    public init?(code: String) {
        switch code.lowercased() {
        case "v": self = .virtual
        case "d": self = .digital
        case "a": self = .analog
        default: return nil
        }
    }
}
