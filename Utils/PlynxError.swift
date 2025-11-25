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
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let underlying):
            if let underlying = underlying {
                return "Failed to connect: \(underlying.localizedDescription)"
            }
            return "Failed to connect to server"
            
        case .connectionClosed:
            return "Connection was closed unexpectedly"
            
        case .authenticationFailed(let code):
            return "Authentication failed: \(code.description)"
            
        case .serverError(let code):
            return "Server error: \(code.description)"
            
        case .timeout:
            return "Request timed out"
            
        case .encodingError(let error):
            return "Failed to encode message: \(error.localizedDescription)"
            
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
            
        case .invalidResponse:
            return "Invalid response from server"
            
        case .notConnected:
            return "Not connected to server"
            
        case .notAuthenticated:
            return "Not authenticated"
            
        case .cancelled:
            return "Operation was cancelled"
            
        case .tlsError(let message):
            return "TLS error: \(message)"
        }
    }
}
