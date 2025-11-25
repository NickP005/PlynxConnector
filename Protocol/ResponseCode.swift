//
//  ResponseCode.swift
//  PlynxConnector
//
//  Server response codes for Plynx protocol.
//

import Foundation

/// Response codes returned by the Plynx server.
/// When command == 0 (RESPONSE), the 2-byte length field contains this code.
public enum ResponseCode: Int, Sendable, CustomStringConvertible {
    case ok = 200
    case quotaLimit = 1
    case illegalCommand = 2
    case userNotRegistered = 3
    case userAlreadyRegistered = 4
    case userNotAuthenticated = 5
    case notAllowed = 6
    case deviceNotInNetwork = 7
    case noActiveDashboard = 8
    case invalidToken = 9
    case illegalCommandBody = 11
    case notificationInvalidBody = 13
    case notificationNotAuthorized = 14
    case notificationError = 15
    case noData = 17
    case serverError = 19
    case energyLimit = 21
    case facebookUserLoginWithPass = 22
    
    /// Unknown response code
    case unknown = -1
    
    /// Initialize from raw value, returning .unknown for unrecognized codes
    public init(rawValue: Int) {
        switch rawValue {
        case 200: self = .ok
        case 1: self = .quotaLimit
        case 2: self = .illegalCommand
        case 3: self = .userNotRegistered
        case 4: self = .userAlreadyRegistered
        case 5: self = .userNotAuthenticated
        case 6: self = .notAllowed
        case 7: self = .deviceNotInNetwork
        case 8: self = .noActiveDashboard
        case 9: self = .invalidToken
        case 11: self = .illegalCommandBody
        case 13: self = .notificationInvalidBody
        case 14: self = .notificationNotAuthorized
        case 15: self = .notificationError
        case 17: self = .noData
        case 19: self = .serverError
        case 21: self = .energyLimit
        case 22: self = .facebookUserLoginWithPass
        default: self = .unknown
        }
    }
    
    /// Whether this response indicates success
    public var isSuccess: Bool {
        return self == .ok
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .ok: return "OK"
        case .quotaLimit: return "Quota Limit Exceeded"
        case .illegalCommand: return "Illegal Command"
        case .userNotRegistered: return "User Not Registered"
        case .userAlreadyRegistered: return "User Already Registered"
        case .userNotAuthenticated: return "User Not Authenticated"
        case .notAllowed: return "Not Allowed"
        case .deviceNotInNetwork: return "Device Not In Network"
        case .noActiveDashboard: return "No Active Dashboard"
        case .invalidToken: return "Invalid Token"
        case .illegalCommandBody: return "Illegal Command Body"
        case .notificationInvalidBody: return "Notification Invalid Body"
        case .notificationNotAuthorized: return "Notification Not Authorized"
        case .notificationError: return "Notification Error"
        case .noData: return "No Data"
        case .serverError: return "Server Error"
        case .energyLimit: return "Energy Limit"
        case .facebookUserLoginWithPass: return "Facebook User Login With Password"
        case .unknown: return "Unknown"
        }
    }
}
