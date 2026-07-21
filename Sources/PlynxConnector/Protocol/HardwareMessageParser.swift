//
//  HardwareMessageParser.swift
//  PlynxConnector
//
//  Parser for the Plynx HARDWARE binary protocol (5-byte header, 2-byte length),
//  used by the BLE direct-connect transport. Devices speak the hardware framing
//  over BLE, not the 7-byte mobile framing that `MessageParser` handles.
//
//  Frame: command(1) + messageId(2, big-endian) + length(2, big-endian) + body.
//  For RESPONSE frames (command == 0) the "length" field carries the status
//  code and there is no body — same convention as the mobile protocol.
//

import Foundation

public final class HardwareMessageParser: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    /// Append received bytes (e.g. the payload of a BLE notification).
    public func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
    }

    private func parseNextInternal() -> ParsedMessage? {
        guard buffer.count >= BlynkMessage.hardwareHeaderSize else { return nil }

        let header = Array(buffer.prefix(BlynkMessage.hardwareHeaderSize))
        let command = header[0]
        let messageId = (UInt16(header[1]) << 8) | UInt16(header[2])
        let lengthOrStatus = (UInt16(header[3]) << 8) | UInt16(header[4])

        // RESPONSE: the length field is the status code, no body follows.
        if command == CommandCode.response.rawValue {
            buffer.removeFirst(BlynkMessage.hardwareHeaderSize)
            let code = ResponseCode(rawValue: Int(lengthOrStatus))
            return .response(BlynkResponse(messageId: messageId, code: code))
        }

        let bodyLength = Int(lengthOrStatus)
        let totalLength = BlynkMessage.hardwareHeaderSize + bodyLength
        guard buffer.count >= totalLength else { return nil }

        let bodyStart = buffer.startIndex + BlynkMessage.hardwareHeaderSize
        let bodyEnd = buffer.startIndex + totalLength
        let bodyData = Data(buffer[bodyStart..<bodyEnd])
        let body = String(data: bodyData, encoding: .utf8) ?? ""
        buffer.removeFirst(totalLength)

        guard let cmd = CommandCode(rawValue: command) else {
            // Unknown command (e.g. a hardware-only opcode not modelled here):
            // the frame is already consumed, keep going with the next one.
            return parseNextInternal()
        }
        return .command(BlynkMessage(command: cmd, messageId: messageId, body: body, rawData: bodyData))
    }

    public func parseNext() -> ParsedMessage? {
        lock.lock()
        defer { lock.unlock() }
        return parseNextInternal()
    }

    /// Parse every complete frame currently buffered (call after each append).
    public func parseAll() -> [ParsedMessage] {
        lock.lock()
        defer { lock.unlock() }
        var messages: [ParsedMessage] = []
        while let message = parseNextInternal() {
            messages.append(message)
        }
        return messages
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
    }
}
