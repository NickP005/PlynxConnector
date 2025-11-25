//
//  BlynkMessage.swift
//  PlynxConnector
//
//  Message structure and serialization for the Plynx binary protocol.
//

import Foundation

/// Represents a message in the Plynx binary protocol.
///
/// Message format:
/// - Command: 1 byte (unsigned)
/// - Message ID: 2 bytes (big-endian, unsigned)
/// - Length: 2 bytes (big-endian, unsigned) - body length or response code
/// - Body: Variable length UTF-8 string
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
    
    /// Header size in bytes (command + messageId + length)
    public static let headerSize = 5
    
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
    
    /// Serialize the message to bytes for transmission
    public func serialize() -> Data {
        var data = Data()
        
        // Command (1 byte)
        data.append(command.rawValue)
        
        // Message ID (2 bytes, big-endian)
        data.append(UInt8((messageId >> 8) & 0xFF))
        data.append(UInt8(messageId & 0xFF))
        
        // Body as UTF-8
        let bodyData = body.data(using: .utf8) ?? Data()
        
        // Length (2 bytes, big-endian)
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

/// Message parser for the binary protocol
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
    
    /// Try to parse a complete message from the buffer
    /// Returns nil if not enough data is available
    public func parseNext() -> ParsedMessage? {
        lock.lock()
        defer { lock.unlock() }
        
        // Need at least header size
        guard buffer.count >= BlynkMessage.headerSize else {
            return nil
        }
        
        // Parse header
        let command = buffer[0]
        let messageId = (UInt16(buffer[1]) << 8) | UInt16(buffer[2])
        let lengthOrStatus = (UInt16(buffer[3]) << 8) | UInt16(buffer[4])
        
        // Handle response (command == 0)
        if command == CommandCode.response.rawValue {
            // For responses, lengthOrStatus is the response code, no body
            buffer.removeFirst(BlynkMessage.headerSize)
            let code = ResponseCode(rawValue: Int(lengthOrStatus))
            return .response(BlynkResponse(messageId: messageId, code: code))
        }
        
        // For other commands, lengthOrStatus is the body length
        let bodyLength = Int(lengthOrStatus)
        let totalLength = BlynkMessage.headerSize + bodyLength
        
        guard buffer.count >= totalLength else {
            return nil
        }
        
        // Extract body
        let bodyData = buffer.subdata(in: BlynkMessage.headerSize..<totalLength)
        let body = String(data: bodyData, encoding: .utf8) ?? ""
        
        // Remove parsed message from buffer
        buffer.removeFirst(totalLength)
        
        guard let cmd = CommandCode(rawValue: command) else {
            // Unknown command, skip
            return nil
        }
        
        let message = BlynkMessage(command: cmd, messageId: messageId, body: body)
        return .command(message)
    }
    
    /// Parse all complete messages from buffer
    public func parseAll() -> [ParsedMessage] {
        var messages: [ParsedMessage] = []
        while let message = parseNext() {
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
