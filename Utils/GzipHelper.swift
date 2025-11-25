//
//  GzipHelper.swift
//  PlynxConnector
//
//  Gzip decompression for profile and graph data.
//

import Foundation
import Compression

/// Helper for decompressing gzipped data from the server.
public enum GzipHelper {
    
    /// Decompress gzipped data
    /// - Parameter data: Gzipped data
    /// - Returns: Decompressed data
    /// - Throws: If decompression fails
    public static func decompress(_ data: Data) throws -> Data {
        guard data.count > 0 else {
            return data
        }
        
        // Check for gzip magic number
        guard data.count >= 2,
              data[0] == 0x1f,
              data[1] == 0x8b else {
            // Not gzipped, return as-is
            return data
        }
        
        // Use Compression framework
        let decompressedSize = data.count * 10 // Estimate
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
    ///   - data: Gzipped JSON data
    ///   - type: Type to decode
    ///   - decoder: JSON decoder
    /// - Returns: Decoded object
    public static func decompressAndDecode<T: Decodable>(_ data: Data, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let decompressed = try decompress(data)
        return try decoder.decode(type, from: decompressed)
    }
}
