//
//  Action.swift
//  PlynxConnector
//
//  All actions that can be sent to the Plynx server.
//

import Foundation

/// Actions that can be sent to the Plynx server.
/// Use `PlynxConnector.send(_:)` to execute these actions.
public enum Action: Sendable {
    
    // MARK: - Authentication
    
    /// Register a new user account
    case register(email: String, password: String, appName: String)
    
    /// Login with email and password
    case login(email: String, password: String, appName: String)
    
    /// Login with a share token (for shared dashboard access)
    case shareLogin(token: String)
    
    /// Logout the current user
    /// - Parameter uid: Optional push notification UID to clear
    case logout(uid: String?)
    
    /// Start password reset flow
    case resetPasswordStart(email: String, appName: String)
    
    /// Verify password reset token
    case resetPasswordVerify(token: String)
    
    /// Complete password reset
    case resetPasswordComplete(token: String, email: String, newPassword: String, appName: String)
    
    /// Get the server address for a user
    case getServer(email: String)
    
    // MARK: - Dashboard Management
    
    /// Create a new dashboard
    /// - Parameters:
    ///   - dashboard: The dashboard to create
    ///   - generateToken: If false, no tokens are generated for devices
    case createDashboard(dashboard: DashBoard, generateToken: Bool)
    
    /// Update an existing dashboard
    case updateDashboard(dashboard: DashBoard)
    
    /// Delete a dashboard
    case deleteDashboard(dashId: Int)
    
    /// Activate a dashboard (required before hardware commands work)
    case activateDashboard(dashId: Int)
    
    /// Deactivate a dashboard
    /// - Parameter dashId: Dashboard ID, or nil to deactivate all
    case deactivateDashboard(dashId: Int?)
    
    /// Update dashboard settings only (name, theme, etc.)
    case updateDashboardSettings(dashId: Int, settings: DashBoard)
    
    /// Load user profile (all dashboards)
    /// - Parameters:
    ///   - dashId: Specific dashboard ID, or nil for all
    ///   - published: If true, load published project
    case loadProfile(dashId: Int?, published: Bool)
    
    // MARK: - Widget Management
    
    /// Create a widget
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - widget: Widget to create
    ///   - tileId: Optional tile ID for DeviceTiles widgets
    case createWidget(dashId: Int, widget: Widget, tileId: Int?)
    
    /// Update a widget
    case updateWidget(dashId: Int, widget: Widget)
    
    /// Delete a widget
    case deleteWidget(dashId: Int, widgetId: Int)
    
    /// Get a widget by ID
    case getWidget(dashId: Int, widgetId: Int)
    
    /// Set a widget property (label, color, etc.)
    case setWidgetProperty(dashId: Int, deviceId: Int, pin: Int, property: WidgetProperty, value: String)
    
    // MARK: - Device Management
    
    /// Create a new device
    case createDevice(dashId: Int, device: Device)
    
    /// Update an existing device
    case updateDevice(dashId: Int, device: Device)
    
    /// Delete a device
    case deleteDevice(dashId: Int, deviceId: Int)
    
    /// Get all devices in a dashboard
    case getDevices(dashId: Int)
    
    /// Get a single device by ID
    case getDevice(dashId: Int, deviceId: Int)
    
    /// Delete device data
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Device ID
    ///   - pins: Optional specific pins to delete, nil for all data
    case deleteDeviceData(dashId: Int, deviceId: Int, pins: [PinInfo]?)
    
    // MARK: - Tag Management
    
    /// Create a tag
    case createTag(dashId: Int, tag: Tag)
    
    /// Update a tag
    case updateTag(dashId: Int, tag: Tag)
    
    /// Delete a tag
    case deleteTag(dashId: Int, tagId: Int)
    
    /// Get all tags for a dashboard
    case getTags(dashId: Int)
    
    // MARK: - Tile Template Management
    
    /// Create a tile template
    case createTileTemplate(dashId: Int, widgetId: Int, template: TileTemplate)
    
    /// Update a tile template
    case updateTileTemplate(dashId: Int, widgetId: Int, template: TileTemplate)
    
    /// Delete a tile template
    case deleteTileTemplate(dashId: Int, widgetId: Int, templateId: Int)
    
    // MARK: - Token Management
    
    /// Refresh device token
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Device ID, or nil to refresh all
    case refreshToken(dashId: Int, deviceId: Int?)
    
    /// Assign a pre-flashed token to a device
    case assignToken(dashId: Int, deviceId: Int, token: String)
    
    /// Get a temporary provision token
    case getProvisionToken(dashId: Int, deviceId: Int)
    
    // MARK: - Hardware Communication
    
    /// Send a hardware command
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Device ID
    ///   - body: Command body (e.g., "vw\01\0255" for virtual write)
    case hardware(dashId: Int, deviceId: Int, body: String)
    
    /// Write to a virtual pin (convenience for hardware command)
    case writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String)
    
    /// Read from a virtual pin (convenience for hardware command)
    case readVirtualPin(dashId: Int, deviceId: Int, pin: Int)
    
    /// Sync hardware state
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - target: Optional specific target (pin info)
    case hardwareSync(dashId: Int, target: String?)
    
    /// Sync app state (get widget values)
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - widgetIds: Optional specific widget IDs
    case appSync(dashId: Int, widgetIds: [Int]?)
    
    /// Resend hardware command from Bluetooth
    case resendFromBluetooth(dashId: Int, deviceId: Int, body: String)
    
    // MARK: - Sharing
    
    /// Enable or disable sharing for a dashboard
    case setSharing(dashId: Int, enabled: Bool)
    
    /// Get the share token for a dashboard
    case getShareToken(dashId: Int)
    
    /// Refresh (regenerate) the share token
    case refreshShareToken(dashId: Int)
    
    // MARK: - Graph & Data
    
    /// Get enhanced graph data
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Device ID
    ///   - dataStreams: Data stream IDs
    ///   - period: Time period
    ///   - page: Optional page number (for pagination)
    case getEnhancedGraphData(dashId: Int, deviceId: Int, dataStreams: [Int], period: GraphPeriod, page: Int?)
    
    /// Delete enhanced graph data
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - widgetId: Widget ID
    ///   - dataStreamIds: Optional specific data stream IDs, nil for all
    case deleteEnhancedGraphData(dashId: Int, widgetId: Int, dataStreamIds: [Int]?)
    
    /// Export graph data as CSV via email
    case exportGraphData(dashId: Int, widgetId: Int, pinType: PinType, pin: Int, deviceId: Int)
    
    // MARK: - Reports
    
    /// Create a report
    case createReport(dashId: Int, widgetId: Int, report: Report)
    
    /// Update a report
    case updateReport(dashId: Int, widgetId: Int, report: Report)
    
    /// Delete a report
    case deleteReport(dashId: Int, widgetId: Int, reportId: Int)
    
    /// Export a report immediately
    case exportReport(dashId: Int, widgetId: Int, reportId: Int)
    
    // MARK: - Email
    
    /// Send device token(s) via email
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Optional device ID (nil = all devices)
    case emailToken(dashId: Int, deviceId: Int?)
    
    /// Send a custom email
    case email(dashId: Int, deviceId: Int, to: String?, subject: String?, body: String?)
    
    /// Email QR codes for app publishing
    case emailQR(dashId: Int, widgetId: Int)
    
    // MARK: - Push Notifications
    
    /// Register a push notification token for a dashboard
    /// - Parameters:
    ///   - dashId: Dashboard ID to register notifications for
    ///   - uid: Unique device identifier (used to manage multiple devices)
    ///   - token: APNs/FCM push token
    case addPushToken(dashId: Int, uid: String, token: String)
    
    // MARK: - App Management
    
    /// Create an app configuration
    case createApp(app: App)
    
    /// Update an app configuration
    case updateApp(app: App)
    
    /// Delete an app
    case deleteApp(appId: Int)
    
    /// Update faces for child projects
    case updateFace(appId: Int, dashJson: String)
    
    // MARK: - Clone & Project
    
    /// Get a clone code for a dashboard
    case getCloneCode(dashId: Int)
    
    /// Get or create project from clone code
    /// - Parameters:
    ///   - code: Clone code
    ///   - create: If true, create the project
    case getProjectByCloneCode(code: String, create: Bool)
    
    /// Get published project by flashed token
    case getProjectByToken(token: String)
    
    // MARK: - Energy
    
    /// Get current energy balance
    case getEnergy
    
    /// Add energy from in-app purchase
    case addEnergy(amount: Int, transactionId: String)
    
    /// Redeem a promotional code
    case redeem(code: String)
    
    // MARK: - Utility
    
    /// Send a ping (keep-alive)
    case ping
}

/// Pin information for data operations.
public struct PinInfo: Sendable {
    public let pin: Int
    public let pinType: PinType
    
    public init(pin: Int, pinType: PinType = .virtual) {
        self.pin = pin
        self.pinType = pinType
    }
}

// MARK: - Internal conversion to BlynkMessage

extension Action {
    /// Convert action to a BlynkMessage for transmission
    func toMessage(messageId: UInt16, encoder: JSONEncoder) throws -> BlynkMessage {
        switch self {
        // Authentication
        case .register(let email, let password, let appName):
            // Password must be SHA256 hashed with email as salt
            let passwordHash = SHA256Helper.makeHash(password: password, email: email)
            return BlynkMessage(command: .register, messageId: messageId,
                              bodyParts: [email, passwordHash, appName])
            
        case .login(let email, let password, let appName):
            // Password must be SHA256 hashed with email as salt
            let passwordHash = SHA256Helper.makeHash(password: password, email: email)
            return BlynkMessage(command: .login, messageId: messageId,
                              bodyParts: [email, passwordHash, "iOS", "1.0.0", appName])
            
        case .shareLogin(let token):
            return BlynkMessage(command: .shareLogin, messageId: messageId, body: token)
            
        case .logout(let uid):
            return BlynkMessage(command: .logout, messageId: messageId, body: uid ?? "")
            
        case .resetPasswordStart(let email, let appName):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: ["start", email, appName])
            
        case .resetPasswordVerify(let token):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: ["verify", token])
            
        case .resetPasswordComplete(let token, let email, let newPassword, let appName):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: [token, email, newPassword, appName])
            
        case .getServer(let email):
            return BlynkMessage(command: .getServer, messageId: messageId, body: email)
            
        // Dashboard Management
        case .createDashboard(let dashboard, let generateToken):
            let json = try encoder.encode(dashboard)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            let body = generateToken ? jsonString : "no_token\0\(jsonString)"
            return BlynkMessage(command: .createDash, messageId: messageId, body: body)
            
        case .updateDashboard(let dashboard):
            let json = try encoder.encode(dashboard)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateDash, messageId: messageId, body: jsonString)
            
        case .deleteDashboard(let dashId):
            return BlynkMessage(command: .deleteDash, messageId: messageId, body: "\(dashId)")
            
        case .activateDashboard(let dashId):
            return BlynkMessage(command: .activateDashboard, messageId: messageId, body: "\(dashId)")
            
        case .deactivateDashboard(let dashId):
            let body = dashId.map { "\($0)" } ?? ""
            return BlynkMessage(command: .deactivateDashboard, messageId: messageId, body: body)
            
        case .updateDashboardSettings(let dashId, let settings):
            let json = try encoder.encode(settings)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateProjectSettings, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .loadProfile(let dashId, let published):
            var body = ""
            if let dashId = dashId {
                body = "\(dashId)"
                if published {
                    body += "\0published"
                }
            }
            return BlynkMessage(command: .loadProfileGzipped, messageId: messageId, body: body)
            
        // Widget Management
        case .createWidget(let dashId, let widget, let tileId):
            let json = try encoder.encode(widget)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            var bodyParts = ["\(dashId)", jsonString]
            if let tileId = tileId {
                bodyParts.append("\(tileId)")
            }
            return BlynkMessage(command: .createWidget, messageId: messageId, bodyParts: bodyParts)
            
        case .updateWidget(let dashId, let widget):
            let json = try encoder.encode(widget)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .deleteWidget(let dashId, let widgetId):
            return BlynkMessage(command: .deleteWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])
            
        case .getWidget(let dashId, let widgetId):
            return BlynkMessage(command: .getWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])
            
        case .setWidgetProperty(let dashId, let deviceId, let pin, let property, let value):
            return BlynkMessage(command: .setWidgetProperty, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", "\(pin)", property.rawValue, value])
            
        // Device Management
        case .createDevice(let dashId, let device):
            let json = try encoder.encode(device)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .updateDevice(let dashId, let device):
            let json = try encoder.encode(device)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .deleteDevice(let dashId, let deviceId):
            return BlynkMessage(command: .deleteDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])
            
        case .getDevices(let dashId):
            return BlynkMessage(command: .getDevices, messageId: messageId, body: "\(dashId)")
            
        case .getDevice(let dashId, let deviceId):
            return BlynkMessage(command: .mobileGetDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])
            
        case .deleteDeviceData(let dashId, let deviceId, let pins):
            var bodyParts = ["\(dashId)", "\(deviceId)"]
            if let pins = pins {
                let pinStrings = pins.map { "\($0.pinType.code)\($0.pin)" }
                bodyParts.append(contentsOf: pinStrings)
            }
            return BlynkMessage(command: .deleteDeviceData, messageId: messageId, bodyParts: bodyParts)
            
        // Tag Management
        case .createTag(let dashId, let tag):
            let json = try encoder.encode(tag)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createTag, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .updateTag(let dashId, let tag):
            let json = try encoder.encode(tag)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateTag, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])
            
        case .deleteTag(let dashId, let tagId):
            return BlynkMessage(command: .deleteTag, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(tagId)"])
            
        case .getTags(let dashId):
            return BlynkMessage(command: .getTags, messageId: messageId, body: "\(dashId)")
            
        // Tile Template Management
        case .createTileTemplate(let dashId, let widgetId, let template):
            let json = try encoder.encode(template)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])
            
        case .updateTileTemplate(let dashId, let widgetId, let template):
            let json = try encoder.encode(template)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])
            
        case .deleteTileTemplate(let dashId, let widgetId, let templateId):
            return BlynkMessage(command: .deleteTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(templateId)"])
            
        // Token Management
        case .refreshToken(let dashId, let deviceId):
            if let deviceId = deviceId {
                return BlynkMessage(command: .refreshToken, messageId: messageId,
                                  bodyParts: ["\(dashId)", "\(deviceId)"])
            } else {
                return BlynkMessage(command: .refreshToken, messageId: messageId, body: "\(dashId)")
            }
            
        case .assignToken(let dashId, let deviceId, let token):
            return BlynkMessage(command: .assignToken, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)", token])
            
        case .getProvisionToken(let dashId, let deviceId):
            return BlynkMessage(command: .getProvisionToken, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])
            
        // Hardware Communication
        case .hardware(let dashId, let deviceId, let body):
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", body])
            
        case .writeVirtualPin(let dashId, let deviceId, let pin, let value):
            let hwBody = "vw\0\(pin)\0\(value)"
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", hwBody])
            
        case .readVirtualPin(let dashId, let deviceId, let pin):
            let hwBody = "vr\0\(pin)"
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", hwBody])
            
        case .hardwareSync(let dashId, let target):
            if let target = target {
                return BlynkMessage(command: .hardwareSync, messageId: messageId,
                                  bodyParts: ["\(dashId)", target])
            } else {
                return BlynkMessage(command: .hardwareSync, messageId: messageId, body: "\(dashId)")
            }
            
        case .appSync(let dashId, let widgetIds):
            if let widgetIds = widgetIds {
                let idsStr = widgetIds.map { "\($0)" }.joined(separator: "\0")
                return BlynkMessage(command: .appSync, messageId: messageId,
                                  bodyParts: ["\(dashId)", idsStr])
            } else {
                return BlynkMessage(command: .appSync, messageId: messageId, body: "\(dashId)")
            }
            
        case .resendFromBluetooth(let dashId, let deviceId, let body):
            return BlynkMessage(command: .hardwareResendFromBluetooth, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", body])
            
        // Sharing
        case .setSharing(let dashId, let enabled):
            return BlynkMessage(command: .sharing, messageId: messageId,
                              bodyParts: ["\(dashId)", enabled ? "on" : "off"])
            
        case .getShareToken(let dashId):
            return BlynkMessage(command: .getShareToken, messageId: messageId, body: "\(dashId)")
            
        case .refreshShareToken(let dashId):
            return BlynkMessage(command: .refreshShareToken, messageId: messageId, body: "\(dashId)")
            
        // Graph & Data
        case .getEnhancedGraphData(let dashId, let deviceId, let dataStreams, let period, let page):
            var bodyParts = ["\(dashId)", "\(deviceId)"]
            bodyParts.append(contentsOf: dataStreams.map { "\($0)" })
            bodyParts.append(period.rawValue)
            if let page = page {
                bodyParts.append("\(page)")
            }
            return BlynkMessage(command: .getEnhancedGraphData, messageId: messageId, bodyParts: bodyParts)
            
        case .deleteEnhancedGraphData(let dashId, let widgetId, let dataStreamIds):
            var bodyParts = ["\(dashId)", "\(widgetId)"]
            if let ids = dataStreamIds {
                bodyParts.append(contentsOf: ids.map { "\($0)" })
            }
            return BlynkMessage(command: .deleteEnhancedGraphData, messageId: messageId, bodyParts: bodyParts)
            
        case .exportGraphData(let dashId, let widgetId, let pinType, let pin, let deviceId):
            return BlynkMessage(command: .exportGraphData, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", pinType.rawValue, "\(pin)", "\(deviceId)"])
            
        // Reports
        case .createReport(let dashId, let widgetId, let report):
            let json = try encoder.encode(report)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])
            
        case .updateReport(let dashId, let widgetId, let report):
            let json = try encoder.encode(report)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])
            
        case .deleteReport(let dashId, let widgetId, let reportId):
            return BlynkMessage(command: .deleteReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(reportId)"])
            
        case .exportReport(let dashId, let widgetId, let reportId):
            return BlynkMessage(command: .exportReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(reportId)"])
            
        // Email
        case .emailToken(let dashId, let deviceId):
            if let deviceId = deviceId {
                return BlynkMessage(command: .email, messageId: messageId,
                                  bodyParts: ["\(dashId)", "\(deviceId)"])
            } else {
                return BlynkMessage(command: .email, messageId: messageId, body: "\(dashId)")
            }
            
        case .email(let dashId, let deviceId, let to, let subject, let body):
            var parts = ["\(dashId)-\(deviceId)"]
            if let to = to {
                parts.append(to)
                parts.append(subject ?? "")
                parts.append(body ?? "")
            }
            return BlynkMessage(command: .email, messageId: messageId, bodyParts: parts)
            
        case .emailQR(let dashId, let widgetId):
            return BlynkMessage(command: .emailQR, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])
            
        // Push Notifications
        case .addPushToken(let dashId, let uid, let token):
            return BlynkMessage(command: .addPushToken, messageId: messageId,
                              bodyParts: ["\(dashId)", uid, token])
            
        // App Management
        case .createApp(let app):
            let json = try encoder.encode(app)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createApp, messageId: messageId, body: jsonString)
            
        case .updateApp(let app):
            let json = try encoder.encode(app)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateApp, messageId: messageId, body: jsonString)
            
        case .deleteApp(let appId):
            return BlynkMessage(command: .deleteApp, messageId: messageId, body: "\(appId)")
            
        case .updateFace(let appId, let dashJson):
            return BlynkMessage(command: .updateFace, messageId: messageId,
                              bodyParts: ["\(appId)", dashJson])
            
        // Clone & Project
        case .getCloneCode(let dashId):
            return BlynkMessage(command: .getCloneCode, messageId: messageId, body: "\(dashId)")
            
        case .getProjectByCloneCode(let code, let create):
            if create {
                return BlynkMessage(command: .getProjectByCloneCode, messageId: messageId,
                                  bodyParts: [code, "1"])
            } else {
                return BlynkMessage(command: .getProjectByCloneCode, messageId: messageId, body: code)
            }
            
        case .getProjectByToken(let token):
            return BlynkMessage(command: .getProjectByToken, messageId: messageId, body: token)
            
        // Energy
        case .getEnergy:
            return BlynkMessage(command: .getEnergy, messageId: messageId)
            
        case .addEnergy(let amount, let transactionId):
            return BlynkMessage(command: .addEnergy, messageId: messageId,
                              bodyParts: ["\(amount)", transactionId])
            
        case .redeem(let code):
            return BlynkMessage(command: .redeem, messageId: messageId, body: code)
            
        // Utility
        case .ping:
            return BlynkMessage(command: .ping, messageId: messageId)
        }
    }
}
