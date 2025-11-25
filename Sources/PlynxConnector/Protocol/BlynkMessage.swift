//
//  BlynkMessage.swift
//  PlynxConnector
//
//  Message structure and serialization for the Plynx binary protocol.
//

import Foundation

/// Represents a message in the Plynx binary protocol.
///
/// Message format for MOBILE apps (7-byte header):
/// - Command: 1 byte (unsigned)
/// - Message ID: 2 bytes (big-endian, unsigned)
/// - Length: 4 bytes (big-endian, unsigned) - body length
/// - Body: Variable length UTF-8 string
///
/// Note: Hardware devices use a 5-byte header with 2-byte length,
/// but mobile apps use 7-byte header with 4-byte length.
public struct BlynkMessage: Sendable {
    /// The command code
    public let command: CommandCode
    
    /// Unique message identifier (wraps at 65535)
    public let messageId: UInt16
    
    /// Message body (empty for some commands like PING)
    public let body: String
    
    /// For response messages, this contains the response code
    public var responseCode: ResponseCode? {
        guard command == .response else { return nil }
        // For responses, the "length" field is actually the status code
        return nil // Will be set during parsing
    }
    
    /// Header size in bytes for mobile protocol (command + messageId + length)
    /// Mobile uses 4-byte length, hardware uses 2-byte length
    public static let headerSize = 7  // 1 + 2 + 4 for mobile
    public static let hardwareHeaderSize = 5  // 1 + 2 + 2 for hardware
    
    /// Field separator used in message body
    public static let separator: Character = "\0"
    public static let separatorString = "\0"
    
    /// Create a new message
    public init(command: CommandCode, messageId: UInt16, body: String = "") {
        self.command = command
        self.messageId = messageId
        self.body = body
    }
    
    /// Create a message with multiple body parts joined by separator
    public init(command: CommandCode, messageId: UInt16, bodyParts: [String]) {
        self.command = command
        self.messageId = messageId
        self.body = bodyParts.joined(separator: Self.separatorString)
    }
    
    /// Serialize the message to bytes for transmission (mobile protocol - 7 byte header)
    public func serialize() -> Data {
        var data = Data()
        
        // Command (1 byte)
        data.append(command.rawValue)
        
        // Message ID (2 bytes, big-endian)
        data.append(UInt8((messageId >> 8) & 0xFF))
        data.append(UInt8(messageId & 0xFF))
        
        // Body as UTF-8
        let bodyData = body.data(using: .utf8) ?? Data()
        
        // Length (4 bytes, big-endian) - Mobile protocol uses 4-byte length
        let length = UInt32(bodyData.count)
        data.append(UInt8((length >> 24) & 0xFF))
        data.append(UInt8((length >> 16) & 0xFF))
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        
        // Body
        data.append(bodyData)
        
        return data
    }
    
    /// Serialize using hardware protocol (5 byte header with 2-byte length)
    public func serializeForHardware() -> Data {
        var data = Data()
        
        // Command (1 byte)
        data.append(command.rawValue)
        
        // Message ID (2 bytes, big-endian)
        data.append(UInt8((messageId >> 8) & 0xFF))
        data.append(UInt8(messageId & 0xFF))
        
        // Body as UTF-8
        let bodyData = body.data(using: .utf8) ?? Data()
        
        // Length (2 bytes, big-endian) - Hardware protocol uses 2-byte length
        let length = UInt16(bodyData.count)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        
        // Body
        data.append(bodyData)
        
        return data
    }
    
    /// Parse body into parts split by separator
    public var bodyParts: [String] {
        return body.split(separator: Self.separator, omittingEmptySubsequences: false)
            .map(String.init)
    }
}

/// Response message with status code
public struct BlynkResponse: Sendable {
    public let messageId: UInt16
    public let code: ResponseCode
    public let body: Data?
    
    public init(messageId: UInt16, code: ResponseCode, body: Data? = nil) {
        self.messageId = messageId
        self.code = code
        self.body = body
    }
}

/// Parsed incoming message
public enum ParsedMessage: Sendable {
    /// A response to a previous command
    case response(BlynkResponse)
    
    /// A command from the server (hardware updates, etc.)
    case command(BlynkMessage)
    
    /// The message ID of the parsed message
    public var messageId: UInt16 {
        switch self {
        case .response(let response): return response.messageId
        case .command(let message): return message.messageId
        }
    }
}

/// Message parser for the mobile binary protocol (7-byte header)
public final class MessageParser: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    
    public init() {}
    
    /// Add received data to the buffer
    public func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
    }
    
    /// Try to parse a complete message from the buffer (internal, assumes lock is held)
    private func parseNextInternal() -> ParsedMessage? {
        // Need at least header size (7 bytes for mobile protocol)
        guard buffer.count >= BlynkMessage.headerSize else {
            return nil
        }
        
        // Copy header bytes to local variables for safety
        let headerBytes = Array(buffer.prefix(BlynkMessage.headerSize))
        guard headerBytes.count >= 7 else {
            return nil
        }
        
        let command = headerBytes[0]
        let messageId = (UInt16(headerBytes[1]) << 8) | UInt16(headerBytes[2])
        
        // Length/Status is 4 bytes in mobile protocol (big-endian)
        let lengthOrStatus = (UInt32(headerBytes[3]) << 24) |
                            (UInt32(headerBytes[4]) << 16) |
                            (UInt32(headerBytes[5]) << 8) |
                            UInt32(headerBytes[6])
        
        // Debug logging
        print("[MessageParser] Parsing: cmd=\(command), msgId=\(messageId), lengthOrStatus=\(lengthOrStatus), bufferSize=\(buffer.count)")
        
        // Handle response (command == 0)
        if command == CommandCode.response.rawValue {
            // For responses, lengthOrStatus is the response code, no body
            buffer.removeFirst(BlynkMessage.headerSize)
            let code = ResponseCode(rawValue: Int(lengthOrStatus))
            print("[MessageParser] Parsed response: msgId=\(messageId), code=\(code)")
            return .response(BlynkResponse(messageId: messageId, code: code))
        }
        
        // For other commands, lengthOrStatus is the body length
        let bodyLength = Int(lengthOrStatus)
        
        // Sanity check: body length should be reasonable (max 10MB)
        guard bodyLength >= 0 && bodyLength < 10_000_000 else {
            print("[MessageParser] ⚠️ Invalid body length: \(bodyLength), skipping message")
            // Skip this malformed message header
            if buffer.count >= BlynkMessage.headerSize {
                buffer.removeFirst(BlynkMessage.headerSize)
            }
            return nil
        }
        
        let totalLength = BlynkMessage.headerSize + bodyLength
        
        guard buffer.count >= totalLength else {
            print("[MessageParser] Waiting for more data: need \(totalLength), have \(buffer.count)")
            return nil
        }
        
        // Extract body safely
        let bodyStartIndex = BlynkMessage.headerSize
        let bodyEndIndex = totalLength
        let bodyData = Data(buffer[bodyStartIndex..<bodyEndIndex])
        let body = String(data: bodyData, encoding: .utf8) ?? ""
        
        // Remove parsed message from buffer
        buffer.removeFirst(totalLength)
        
        guard let cmd = CommandCode(rawValue: command) else {
            print("[MessageParser] Unknown command: \(command)")
            return nil
        }
        
        print("[MessageParser] Parsed command: \(cmd), bodyLength=\(bodyLength)")
        let message = BlynkMessage(command: cmd, messageId: messageId, body: body)
        return .command(message)
    }
    
    /// Try to parse a complete message from the buffer
    /// Returns nil if not enough data is available
    public func parseNext() -> ParsedMessage? {
        lock.lock()
        defer { lock.unlock() }
        return parseNextInternal()
    }
    
    /// Parse all complete messages from buffer (thread-safe)
    public func parseAll() -> [ParsedMessage] {
        lock.lock()
        defer { lock.unlock() }
        
        var messages: [ParsedMessage] = []
        while let message = parseNextInternal() {
            messages.append(message)
        }
        return messages
    }
    
    /// Clear the buffer
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
    }
}
