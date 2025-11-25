//
//  Event.swift
//  PlynxConnector
//
//  All events that can be received from the Plynx server.
//

import Foundation

/// Events received from the Plynx server.
/// Subscribe to `PlynxConnector.events` to receive these.
public enum Event: Sendable {
    
    // MARK: - Connection Events
    
    /// Successfully connected to the server (before login)
    case connected
    
    /// Disconnected from the server
    case disconnected(Error?)
    
    /// Attempting to reconnect
    case reconnecting(attempt: Int)
    
    /// Reconnection successful
    case reconnected
    
    // MARK: - Authentication Events
    
    /// Login successful
    case loginSuccess
    
    /// Login failed
    case loginFailed(ResponseCode)
    
    /// Registration successful
    case registered
    
    /// Registration failed
    case registrationFailed(ResponseCode)
    
    /// Server address received (from getServer)
    case serverAddress(String)
    
    /// Logged out
    case loggedOut
    
    // MARK: - Response Events
    
    /// Generic response to a command
    case response(messageId: UInt16, code: ResponseCode)
    
    // MARK: - Profile Events
    
    /// User profile loaded (gzipped data)
    case profileLoaded(Data)
    
    // MARK: - Device Events
    
    /// Device created (includes token)
    case deviceCreated(Device)
    
    /// All devices loaded
    case devicesLoaded([Device])
    
    /// Single device loaded
    case deviceLoaded(Device)
    
    /// Hardware device connected
    case hardwareConnected(dashId: Int, deviceId: Int)
    
    /// Hardware device disconnected
    case hardwareDisconnected(dashId: Int, deviceId: Int)
    
    // MARK: - Tag Events
    
    /// Tag created
    case tagCreated(Tag)
    
    /// All tags loaded
    case tagsLoaded([Tag])
    
    // MARK: - Widget Events
    
    /// Widget loaded
    case widgetLoaded(Widget)
    
    /// Widget property changed (from hardware)
    case widgetPropertyChanged(dashId: Int, deviceId: Int, pin: Int, property: WidgetProperty, value: String)
    
    // MARK: - Token Events
    
    /// Token refreshed
    case tokenRefreshed(String)
    
    /// Provision token received
    case provisionToken(Device)
    
    // MARK: - Share Events
    
    /// Share token received
    case shareToken(String)
    
    // MARK: - Graph/Data Events
    
    /// Graph data received (gzipped)
    case graphData(Data)
    
    /// Graph data exported
    case graphDataExported
    
    // MARK: - Report Events
    
    /// Report created
    case reportCreated(Report)
    
    /// Report updated
    case reportUpdated(Report)
    
    /// Report exported
    case reportExported(Report)
    
    // MARK: - Clone Events
    
    /// Clone code received
    case cloneCode(String)
    
    /// Project received from clone
    case projectFromClone(Data)
    
    // MARK: - App Events
    
    /// App created
    case appCreated(App)
    
    // MARK: - Energy Events
    
    /// Energy balance received
    case energyBalance(Int)
    
    /// Energy added successfully
    case energyAdded
    
    /// Redemption successful
    case redeemed
    
    // MARK: - Hardware Message Events
    
    /// Raw hardware message received
    case hardwareMessage(dashId: Int, deviceId: Int, body: String)
    
    /// Virtual pin update from hardware
    case virtualPinUpdate(dashId: Int, deviceId: Int, pin: Int, values: [String])
    
    /// Digital pin update from hardware
    case digitalPinUpdate(dashId: Int, deviceId: Int, pin: Int, value: Int)
    
    /// Analog pin update from hardware
    case analogPinUpdate(dashId: Int, deviceId: Int, pin: Int, value: Int)
    
    // MARK: - Sync Events
    
    /// App sync data received
    case appSyncData(dashId: Int, body: String)
    
    // MARK: - Sharing Events
    
    /// Sharing state changed (another user started/stopped sharing)
    case sharingChanged(dashId: Int, active: Bool)
    
    /// Dashboard activated by another shared user
    case dashboardActivatedByOther(dashId: Int)
    
    /// Dashboard deactivated by another shared user
    case dashboardDeactivatedByOther(dashId: Int)
    
    // MARK: - App Version Events
    
    /// Outdated app notification from server
    case outdatedAppNotification(message: String)
    
    // MARK: - Notification Events
    
    /// Email sent successfully
    case emailSent
    
    /// Push token registered
    case pushTokenAdded
    
    // MARK: - Internal Events
    
    /// Internal message from server
    case internalMessage(String)
    
    /// Ping response received
    case pong
}

// MARK: - Event Parsing

extension Event {
    /// Parse a server message into an Event
    static func from(message: ParsedMessage, decoder: JSONDecoder) -> Event? {
        switch message {
        case .response(let response):
            return parseResponse(response)
            
        case .command(let blynkMessage):
            return parseCommand(blynkMessage, decoder: decoder)
        }
    }
    
    private static func parseResponse(_ response: BlynkResponse) -> Event {
        // Generic response - the PlynxConnector will match this to pending requests
        return .response(messageId: response.messageId, code: response.code)
    }
    
    private static func parseCommand(_ message: BlynkMessage, decoder: JSONDecoder) -> Event? {
        switch message.command {
        case .hardwareConnected:
            // Body: dashId-deviceId
            let parts = message.body.split(separator: "-")
            if parts.count >= 2,
               let dashId = Int(parts[0]),
               let deviceId = Int(parts[1]) {
                return .hardwareConnected(dashId: dashId, deviceId: deviceId)
            }
            
        case .deviceOffline:
            // Body: dashId-deviceId
            let parts = message.body.split(separator: "-")
            if parts.count >= 2,
               let dashId = Int(parts[0]),
               let deviceId = Int(parts[1]) {
                return .hardwareDisconnected(dashId: dashId, deviceId: deviceId)
            }
            
        case .hardware:
            return parseHardwareMessage(message)
            
        case .setWidgetProperty:
            return parseWidgetProperty(message)
            
        case .appSync:
            // Body: dashId\0body
            let parts = message.bodyParts
            if parts.count >= 2, let dashId = Int(parts[0]) {
                return .appSyncData(dashId: dashId, body: parts.dropFirst().joined(separator: "\0"))
            }
            
        case .sharing:
            // Body: dashId\0active (1 or 0)
            let parts = message.bodyParts
            if parts.count >= 2, let dashId = Int(parts[0]) {
                let active = parts[1] == "1"
                return .sharingChanged(dashId: dashId, active: active)
            }
            
        case .activateDashboard:
            // Body: dashId (from another shared user)
            if let dashId = Int(message.body) {
                return .dashboardActivatedByOther(dashId: dashId)
            }
            
        case .deactivateDashboard:
            // Body: dashId (from another shared user)
            if let dashId = Int(message.body) {
                return .dashboardDeactivatedByOther(dashId: dashId)
            }
            
        case .outdatedAppNotification:
            return .outdatedAppNotification(message: message.body)
            
        case .blynkInternal:
            return .internalMessage(message.body)
            
        case .ping:
            return .pong
            
        default:
            // Unknown command
            break
        }
        
        return nil
    }
    
    private static func parseHardwareMessage(_ message: BlynkMessage) -> Event? {
        // Body format: dashId-deviceId\0command\0pin\0value...
        let parts = message.bodyParts
        guard parts.count >= 1 else { return nil }
        
        // Parse dashId-deviceId
        let idParts = parts[0].split(separator: "-")
        guard idParts.count >= 2,
              let dashId = Int(idParts[0]),
              let deviceId = Int(idParts[1]) else {
            return .hardwareMessage(dashId: 0, deviceId: 0, body: message.body)
        }
        
        // Check if we have command parts
        if parts.count >= 3 {
            let command = parts[1]
            
            switch command {
            case "vw":
                // Virtual write: vw\0pin\0value1\0value2...
                if let pin = Int(parts[2]) {
                    let values = Array(parts.dropFirst(3))
                    return .virtualPinUpdate(dashId: dashId, deviceId: deviceId, pin: pin, values: values)
                }
                
            case "dw":
                // Digital write: dw\0pin\0value
                if parts.count >= 4,
                   let pin = Int(parts[2]),
                   let value = Int(parts[3]) {
                    return .digitalPinUpdate(dashId: dashId, deviceId: deviceId, pin: pin, value: value)
                }
                
            case "aw":
                // Analog write: aw\0pin\0value
                if parts.count >= 4,
                   let pin = Int(parts[2]),
                   let value = Int(parts[3]) {
                    return .analogPinUpdate(dashId: dashId, deviceId: deviceId, pin: pin, value: value)
                }
                
            default:
                break
            }
        }
        
        // Return raw hardware message
        let body = parts.count > 1 ? parts.dropFirst().joined(separator: "\0") : ""
        return .hardwareMessage(dashId: dashId, deviceId: deviceId, body: body)
    }
    
    private static func parseWidgetProperty(_ message: BlynkMessage) -> Event? {
        // Body format: dashId-deviceId\0pin\0property\0value
        let parts = message.bodyParts
        guard parts.count >= 4 else { return nil }
        
        // Parse dashId-deviceId
        let idParts = parts[0].split(separator: "-")
        guard idParts.count >= 2,
              let dashId = Int(idParts[0]),
              let deviceId = Int(idParts[1]),
              let pin = Int(parts[1]),
              let property = WidgetProperty(rawValue: parts[2]) else {
            return nil
        }
        
        return .widgetPropertyChanged(dashId: dashId, deviceId: deviceId, pin: pin, property: property, value: parts[3])
    }
}
