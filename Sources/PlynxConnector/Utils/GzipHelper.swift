//
//  GzipHelper.swift
//  PlynxConnector
//
//  Zlib/Deflate decompression for profile and graph data.
//  Note: The Blynk server uses Java's DeflaterOutputStream which produces
//  zlib-wrapped deflate data (starts with 78 9C), not gzip (1F 8B).
//

import Foundation
import Compression

/// Helper for decompressing compressed data from the server.
public enum GzipHelper {
    
    /// Decompress zlib/deflate data (as used by Blynk server)
    /// - Parameter data: Compressed data (zlib format with 78 9C header)
    /// - Returns: Decompressed data
    /// - Throws: If decompression fails
    public static func decompress(_ data: Data) throws -> Data {
        guard data.count > 0 else {
            return data
        }
        
        // Check for zlib header (78 9C for default compression, 78 DA for best, 78 01 for no compression)
        let isZlib = data.count >= 2 && data[0] == 0x78 && (data[1] == 0x9C || data[1] == 0xDA || data[1] == 0x01 || data[1] == 0x5E)
        
        // Check for gzip magic number
        let isGzip = data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b
        
        if !isZlib && !isGzip {
            // Not compressed, return as-is (might be plain JSON)
            print("[GzipHelper] Data doesn't appear compressed (first bytes: \(data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")))")
            return data
        }
        
        if isZlib {
            return try decompressZlib(data)
        } else {
            return try decompressGzip(data)
        }
    }
    
    /// Decompress zlib-wrapped deflate data
    private static func decompressZlib(_ data: Data) throws -> Data {
        // Zlib format: 2-byte header + deflate data + 4-byte adler32 checksum
        // We skip the 2-byte header and ignore the 4-byte trailer
        guard data.count > 6 else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Zlib data too short"]))
        }
        
        // Start with a reasonable buffer size, will grow if needed
        var decompressedSize = max(data.count * 10, 1024)
        var decompressedData = Data(count: decompressedSize)
        
        let result = decompressedData.withUnsafeMutableBytes { destBuffer -> Int in
            let destPtr = destBuffer.bindMemory(to: UInt8.self).baseAddress!
            
            return data.withUnsafeBytes { sourceBuffer -> Int in
                let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress!
                
                // Skip 2-byte zlib header, exclude 4-byte adler32 trailer
                let compressedStart = 2
                let compressedLength = data.count - 2 - 4
                
                guard compressedLength > 0 else { return 0 }
                
                let decodedSize = compression_decode_buffer(
                    destPtr,
                    decompressedSize,
                    sourcePtr.advanced(by: compressedStart),
                    compressedLength,
                    nil,
                    COMPRESSION_ZLIB
                )
                
                return decodedSize
            }
        }
        
        guard result > 0 else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to decompress zlib data"]))
        }
        
        decompressedData.count = result
        print("[GzipHelper] Decompressed zlib: \(data.count) -> \(result) bytes")
        return decompressedData
    }
    
    /// Decompress gzip data
    private static func decompressGzip(_ data: Data) throws -> Data {
        let decompressedSize = data.count * 10
        var decompressedData = Data(count: decompressedSize)
        
        let result = decompressedData.withUnsafeMutableBytes { destBuffer -> Int in
            let destPtr = destBuffer.bindMemory(to: UInt8.self).baseAddress!
            
            return data.withUnsafeBytes { sourceBuffer -> Int in
                let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress!
                
                // Skip gzip header (minimum 10 bytes)
                let headerSize = parseGzipHeaderSize(data)
                guard headerSize < data.count else { return 0 }
                
                let decodedSize = compression_decode_buffer(
                    destPtr,
                    decompressedSize,
                    sourcePtr.advanced(by: headerSize),
                    data.count - headerSize - 8, // Subtract header and trailer
                    nil,
                    COMPRESSION_ZLIB
                )
                
                
                return decodedSize
            }
        }
        
        guard result > 0 else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to decompress gzip data"]))
        }
        
        decompressedData.count = result
        return decompressedData
    }
    
    /// Parse gzip header size (variable due to optional fields)
    private static func parseGzipHeaderSize(_ data: Data) -> Int {
        guard data.count >= 10 else { return 10 }
        
        var headerSize = 10 // Minimum gzip header
        let flags = data[3]
        
        // FEXTRA
        if flags & 0x04 != 0 {
            guard data.count >= headerSize + 2 else { return headerSize }
            let extraLen = Int(data[headerSize]) | (Int(data[headerSize + 1]) << 8)
            headerSize += 2 + extraLen
        }
        
        // FNAME
        if flags & 0x08 != 0 {
            while headerSize < data.count && data[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1 // Skip null terminator
        }
        
        // FCOMMENT
        if flags & 0x10 != 0 {
            while headerSize < data.count && data[headerSize] != 0 {
                headerSize += 1
            }
            headerSize += 1 // Skip null terminator
        }
        
        // FHCRC
        if flags & 0x02 != 0 {
            headerSize += 2
        }
        
        return headerSize
    }
    
    /// Decompress and decode JSON
    /// - Parameters:
    ///   - data: Compressed JSON data (zlib or gzip)
    ///   - type: Type to decode
    ///   - decoder: JSON decoder
    /// - Returns: Decoded object
    public static func decompressAndDecode<T: Decodable>(_ data: Data, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let decompressed = try decompress(data)
        return try decoder.decode(type, from: decompressed)
    }
}