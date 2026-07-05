//
//  DecodeWarnings.swift
//  PlynxConnector
//
//  Thread-safe collector for non-fatal decode warnings (dropped widgets,
//  devices, dashboards or single fields during lossy profile decoding).
//

import Foundation

/// Collects non-fatal warnings emitted while decoding a profile.
/// Attach an instance to `JSONDecoder.userInfo` via `DecodeWarnings.userInfoKey`
/// to receive descriptions of every element/field that was dropped.
public final class DecodeWarnings: @unchecked Sendable {
    /// Key used to pass the collector through `JSONDecoder.userInfo`.
    public static let userInfoKey = CodingUserInfoKey(rawValue: "PlynxDecodeWarnings")!

    private let lock = NSLock()
    private var messages: [String] = []

    public init() {}

    /// All warnings recorded so far.
    public var warnings: [String] {
        lock.lock(); defer { lock.unlock() }
        return messages
    }

    /// Number of warnings recorded so far.
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return messages.count
    }

    /// Record a warning.
    public func record(_ message: String) {
        lock.lock(); defer { lock.unlock() }
        messages.append(message)
    }

    /// Remove all recorded warnings.
    public func reset() {
        lock.lock(); defer { lock.unlock() }
        messages.removeAll()
    }

    /// Collector attached to the given decoder, if any.
    public static func from(_ decoder: Decoder) -> DecodeWarnings? {
        decoder.userInfo[userInfoKey] as? DecodeWarnings
    }
}
