//
//  ConnectionType.swift
//  PlynxConnector
//
//  Device connection types.
//

import Foundation

/// How a device connects to the server.
public enum ConnectionType: String, Codable, Sendable {
    case wifi = "WI_FI"
    case ethernet = "ETHERNET"
    case usb = "USB"
    case bluetooth = "BLUETOOTH"
    case ble = "BLE"
    case gsm = "GSM"
}
