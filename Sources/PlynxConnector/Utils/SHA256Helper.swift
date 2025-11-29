//
//  SHA256Helper.swift
//  PlynxConnector
//
//  SHA256 hashing utility for password authentication.
//  Matches Blynk server's SHA256Util.makeHash() implementation.
//

import Foundation
import CryptoKit

/// Helper for SHA256 hashing operations
public enum SHA256Helper {
    
    /// Create a SHA256 hash of password with email as salt (Blynk authentication format)
    ///
    /// This matches the Java implementation:
    /// ```java
    /// MessageDigest md = MessageDigest.getInstance("SHA-256");
    /// md.update(password.getBytes(UTF_8));
    /// byte[] byteData = md.digest(makeHash(salt.toLowerCase()));
    /// return Base64.getEncoder().encodeToString(byteData);
    /// ```
    ///
    /// - Parameters:
    ///   - password: User's password
    ///   - email: User's email (used as salt, lowercased)
    /// - Returns: Base64-encoded SHA256 hash string
    public static func makeHash(password: String, email: String) -> String {
        // Step 1: SHA256 hash of lowercased email
        let emailLower = email.lowercased()
        let emailData = Data(emailLower.utf8)
        let emailHash = SHA256.hash(data: emailData)
        let emailHashBytes = Array(emailHash)
        
        // Step 2: SHA256(password bytes + emailHash bytes)
        // Java's md.update(password) followed by md.digest(salt) 
        // is equivalent to SHA256(password || salt)
        var passwordData = Data(password.utf8)
        passwordData.append(contentsOf: emailHashBytes)
        let finalHash = SHA256.hash(data: passwordData)
        
        // Step 3: Base64 encode the result
        let hashData = Data(finalHash)
        return hashData.base64EncodedString()
    }
}
