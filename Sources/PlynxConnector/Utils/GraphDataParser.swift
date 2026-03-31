import Foundation

public struct GraphPoint: Sendable {
    public let value: Double
    public let timestamp: Int64
    
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
    }
}

public struct GraphStreamData: Sendable {
    public let points: [GraphPoint]
}

public enum GraphDataParser {
    
    public static func parse(compressedData: Data) throws -> [GraphStreamData] {
        let decompressed = try GzipHelper.decompress(compressedData)
        return try parseBinary(decompressed)
    }
    
    static func parseBinary(_ data: Data) throws -> [GraphStreamData] {
        guard data.count >= 4 else { return [] }
        
        var offset = 0
        
        let _ = readInt32(data, at: &offset)
        
        var streams: [GraphStreamData] = []
        
        while offset + 4 <= data.count {
            let pointCount = Int(readInt32(data, at: &offset))
            
            guard pointCount >= 0, pointCount < 100_000 else { break }
            
            let bytesNeeded = pointCount * 16
            guard offset + bytesNeeded <= data.count else { break }
            
            var points: [GraphPoint] = []
            points.reserveCapacity(pointCount)
            
            for _ in 0..<pointCount {
                let value = readFloat64(data, at: &offset)
                let timestamp = readInt64(data, at: &offset)
                
                if !value.isNaN && !value.isInfinite {
                    points.append(GraphPoint(value: value, timestamp: timestamp))
                }
            }
            
            streams.append(GraphStreamData(points: points))
        }
        
        return streams
    }
    
    private static func readInt32(_ data: Data, at offset: inout Int) -> Int32 {
        guard offset + 4 <= data.count else { return 0 }
        let value = data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return Int32(0) }
            return Int32(bigEndian: base.advanced(by: offset).loadUnaligned(as: Int32.self))
        }
        offset += 4
        return value
    }
    
    private static func readInt64(_ data: Data, at offset: inout Int) -> Int64 {
        guard offset + 8 <= data.count else { return 0 }
        let value = data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return Int64(0) }
            return Int64(bigEndian: base.advanced(by: offset).loadUnaligned(as: Int64.self))
        }
        offset += 8
        return value
    }
    
    private static func readFloat64(_ data: Data, at offset: inout Int) -> Double {
        guard offset + 8 <= data.count else { return 0 }
        let bits = data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return UInt64(0) }
            return UInt64(bigEndian: base.advanced(by: offset).loadUnaligned(as: UInt64.self))
        }
        offset += 8
        return Double(bitPattern: bits)
    }
}
