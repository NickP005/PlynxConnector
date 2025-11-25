//
//  SHA256Helper.swift
//  PlynxConnector
//
//  SHA256 hashing utility for password authentication.
//

import Foundation
import CryptoKit

/// Helper for SHA256 hashing operations
public enum SHA256Helper {
    
    /// Create a SHA256 hash of password + email (Blynk authentication format)
    /// - Parameters:
    ///   - password: User's password
    ///   - email: User's email (used as salt)
    /// - Returns: Hex-encoded SHA256 hash string
    public static func makeHash(password: String, email: String) -> String {
        let combined = password + email
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
