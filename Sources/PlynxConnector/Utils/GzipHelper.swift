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
        guard data.count > 6 else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Zlib data too short"]))
        }
        
        let compressedStart = 2
        let compressedLength = data.count - 2 - 4
        guard compressedLength > 0 else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Zlib data too short"]))
        }
        
        var multiplier = 10
        while multiplier <= 100 {
            let bufferSize = max(data.count * multiplier, 1024)
            var decompressedData = Data(count: bufferSize)
            
            let result = decompressedData.withUnsafeMutableBytes { destBuffer -> Int in
                guard let destPtr = destBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                
                return data.withUnsafeBytes { sourceBuffer -> Int in
                    guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    
                    return compression_decode_buffer(
                        destPtr,
                        bufferSize,
                        sourcePtr.advanced(by: compressedStart),
                        compressedLength,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            
            guard result > 0 else {
                throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to decompress zlib data"]))
            }
            
            if result < bufferSize {
                decompressedData.count = result
                return decompressedData
            }
            
            multiplier *= 2
        }
        
        throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Decompressed data exceeds maximum buffer size"]))
    }
    
    /// Decompress gzip data
    private static func decompressGzip(_ data: Data) throws -> Data {
        let headerSize = parseGzipHeaderSize(data)
        guard headerSize < data.count else {
            throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Invalid gzip header"]))
        }
        
        var multiplier = 10
        while multiplier <= 100 {
            let bufferSize = max(data.count * multiplier, 1024)
            var decompressedData = Data(count: bufferSize)
            
            let result = decompressedData.withUnsafeMutableBytes { destBuffer -> Int in
                guard let destPtr = destBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                
                return data.withUnsafeBytes { sourceBuffer -> Int in
                    guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    
                    return compression_decode_buffer(
                        destPtr,
                        bufferSize,
                        sourcePtr.advanced(by: headerSize),
                        data.count - headerSize - 8,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            
            guard result > 0 else {
                throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to decompress gzip data"]))
            }
            
            if result < bufferSize {
                decompressedData.count = result
                return decompressedData
            }
            
            multiplier *= 2
        }
        
        throw PlynxError.decodingError(NSError(domain: "GzipHelper", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Decompressed data exceeds maximum buffer size"]))
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