//
//  PlynxError.swift
//  PlynxConnector
//
//  Error types for PlynxConnector.
//

import Foundation

/// Errors that can occur in PlynxConnector.
public enum PlynxError: Error, LocalizedError, Sendable {
    /// Failed to establish connection
    case connectionFailed(underlying: Error?)
    
    /// Connection was closed unexpectedly
    case connectionClosed
    
    /// Authentication failed
    case authenticationFailed(ResponseCode)
    
    /// Server returned an error response
    case serverError(ResponseCode)
    
    /// Request timed out waiting for response
    case timeout
    
    /// Failed to encode message
    case encodingError(Error)
    
    /// Failed to decode response
    case decodingError(Error)
    
    /// Invalid response format
    case invalidResponse
    
    /// Not connected to server
    case notConnected
    
    /// Not authenticated
    case notAuthenticated
    
    /// Operation cancelled
    case cancelled
    
    /// TLS/SSL error
    case tlsError(String)
    
    /// Unexpected response type from server
    case unexpectedResponse
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let underlying):
            if let underlying = underlying {
                return "Connection failed: \(underlying.localizedDescription)"
            }
            return "Unable to reach the server"
            
        case .connectionClosed:
            return "Connection lost"
            
        case .authenticationFailed(let code):
            switch code {
            case .userNotRegistered:
                return "Account not found"
            case .invalidToken, .userNotAuthenticated:
                return "Invalid credentials"
            case .userAlreadyRegistered:
                return "An account with this email already exists"
            default:
                return "Authentication failed (\(code.rawValue))"
            }
            
        case .serverError(let code):
            return "Server error (\(code.rawValue))"
            
        case .timeout:
            return "Request timed out"
            
        case .encodingError:
            return "Failed to send data"
            
        case .decodingError:
            return "Failed to load project data. The server response could not be read. Some projects may use unsupported features."
            
        case .invalidResponse:
            return "Unexpected server response"
            
        case .notConnected:
            return "Not connected to server"
            
        case .notAuthenticated:
            return "Not authenticated"
            
        case .cancelled:
            return "Operation cancelled"
            
        case .tlsError:
            return "Secure connection failed"
            
        case .unexpectedResponse:
            return "Unexpected server response"
        }
    }
}
