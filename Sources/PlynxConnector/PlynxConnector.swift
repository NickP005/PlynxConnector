//
//  PlynxConnector.swift
//  PlynxConnector
//
//  Main interface for connecting to Plynx server.
//

import Foundation

/// Main class for connecting to and communicating with a Plynx server.
///
/// Example usage:
/// ```swift
/// let connector = Connector(host: "192.168.1.100")
///
/// // Listen for events
/// Task {
///     for await event in connector.events {
///         switch event {
///         case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
///             print("V\(pin) = \(values)")
///         default:
///             break
///         }
///     }
/// }
///
/// // Connect and login
/// try await connector.connect(email: "user@example.com", password: "password")
///
/// // Activate dashboard
/// _ = try await connector.send(.activateDashboard(dashId: 1))
///
/// // Write to virtual pin
/// _ = try await connector.send(.writeVirtualPin(dashId: 1, deviceId: 0, pin: 1, value: "255"))
/// ```
public actor Connector {
    
    // MARK: - Properties
    
    private let host: String
    private let port: UInt16
    private var socket: PlynxSocket?
    
    private var messageId: UInt16 = 0
    private var pendingResponses: [UInt16: CheckedContinuation<Event, Error>] = [:]
    private var pendingDataResponses: [UInt16: CheckedContinuation<BlynkMessage, Error>] = [:]
    
    /// Whether the user is authenticated with the server
    private(set) public var authenticated: Bool = false
    
    /// Whether the socket is connected (may not be authenticated yet)
    private(set) public var socketConnected: Bool = false
    
    private var pingTask: Task<Void, Never>?
    private var messageHandlerTask: Task<Void, Never>?
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Stored credentials for reconnection
    private var storedEmail: String?
    private var storedPassword: String?
    private var storedAppName: String?
    private var storedShareToken: String?
    
    // Active dashboard tracking
    private(set) public var activeDashboardId: Int?
    
    private var eventsContinuation: AsyncStream<Event>.Continuation?
    
    /// Stream of events from the server
    public nonisolated let events: AsyncStream<Event>
    
    /// Default port for Plynx server (SSL)
    public static let defaultPort: UInt16 = 9443
    
    /// Response timeout in seconds
    public var responseTimeout: TimeInterval = 10.0
    
    /// Ping interval in seconds
    public var pingInterval: TimeInterval = 10.0
    
    // MARK: - Callbacks (Alternative to events stream)
    
    /// Called when a virtual pin value is updated from hardware
    public var onVirtualPinUpdate: ((Int, Int, Int, [String]) -> Void)?
    
    /// Called when a digital pin value is updated from hardware
    public var onDigitalPinUpdate: ((Int, Int, Int, Int) -> Void)?
    
    /// Called when an analog pin value is updated from hardware
    public var onAnalogPinUpdate: ((Int, Int, Int, Int) -> Void)?
    
    /// Called when a widget property is changed from hardware
    public var onWidgetPropertyChanged: ((Int, Int, Int, WidgetProperty, String) -> Void)?
    
    /// Called when a hardware device connects
    public var onHardwareConnected: ((Int, Int) -> Void)?
    
    /// Called when a hardware device disconnects
    public var onHardwareDisconnected: ((Int, Int) -> Void)?
    
    /// Called when connection state changes
    public var onConnectionStateChanged: ((Bool, Bool) -> Void)?
    
    /// Called on any hardware message (raw)
    public var onHardwareMessage: ((Int, Int, String) -> Void)?
    
    // MARK: - Initialization
    
    /// Create a new PlynxConnector
    /// - Parameters:
    ///   - host: Server hostname or IP address
    ///   - port: Server port (default: 9443)
    public init(host: String, port: UInt16 = defaultPort) {
        self.host = host
        self.port = port
        
        var continuation: AsyncStream<Event>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
    }
    
    deinit {
        eventsContinuation?.finish()
    }
    
    // MARK: - Connection
    
    /// Connect to the server and login with email/password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    ///   - appName: Application name (default: "Plynx")
    public func connect(email: String, password: String, appName: String = "Plynx") async throws {
        // Store credentials for reconnection
        storedEmail = email
        storedPassword = password
        storedAppName = appName
        storedShareToken = nil
        
        // Create and connect socket
        let sock = PlynxSocket(host: host, port: port)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        // Start message handler
        startMessageHandler()
        
        // Emit connected event
        eventsContinuation?.yield(.connected)
        onConnectionStateChanged?(true, false)
        
        // Login
        let response = try await send(.login(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.loginSuccess)
                onConnectionStateChanged?(true, true)
                
                // Start ping timer
                startPingTimer()
            } else {
                authenticated = false
                eventsContinuation?.yield(.loginFailed(code))
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    /// Connect to the server with a share token
    /// - Parameter token: Share token for shared dashboard access
    public func connectWithShareToken(_ token: String) async throws {
        // Store for reconnection
        storedShareToken = token
        storedEmail = nil
        storedPassword = nil
        storedAppName = nil
        
        // Create and connect socket
        let sock = PlynxSocket(host: host, port: port)
        self.socket = sock
        
        try await sock.connect()
        
        // Start message handler
        startMessageHandler()
        
        // Emit connected event
        eventsContinuation?.yield(.connected)
        
        // Share login
        let response = try await send(.shareLogin(token: token))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                socketConnected = true
                onConnectionStateChanged?(true, true)
                eventsContinuation?.yield(.loginSuccess)
                startPingTimer()
            } else {
                authenticated = false
                eventsContinuation?.yield(.loginFailed(code))
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    /// Register a new user account
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    ///   - appName: Application name (default: "Plynx")
    /// - Note: This connects to the server, sends the register command, and disconnects.
    ///         After successful registration, use `connect()` to login.
    public func register(email: String, password: String, appName: String = "Plynx") async throws {
        // Create and connect socket
        let sock = PlynxSocket(host: host, port: port)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        // Start message handler
        startMessageHandler()
        
        // Send register command
        let response = try await send(.register(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                // Registration successful - disconnect and let user login
                await disconnect()
                eventsContinuation?.yield(.registered)
            } else if code == .userAlreadyRegistered {
                await disconnect()
                throw PlynxError.authenticationFailed(code)
            } else {
                await disconnect()
                throw PlynxError.serverError(code)
            }
        }
    }
    
    /// Disconnect from the server
    public func disconnect() async {
        pingTask?.cancel()
        pingTask = nil
        messageHandlerTask?.cancel()
        messageHandlerTask = nil
        
        await socket?.disconnect()
        socket = nil
        
        let wasAuthenticated = authenticated
        let wasConnected = socketConnected
        
        authenticated = false
        socketConnected = false
        activeDashboardId = nil
        
        // Cancel all pending responses
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingResponses.removeAll()
        
        eventsContinuation?.yield(.disconnected(nil))
        
        if wasConnected || wasAuthenticated {
            onConnectionStateChanged?(false, false)
        }
    }
    
    /// Whether currently connected and authenticated (convenience computed property)
    public var isConnected: Bool {
        get async {
            guard let socket = socket else { return false }
            return await socket.isConnected && authenticated
        }
    }
    
    // MARK: - Sending Actions
    
    /// Send an action to the server and wait for the response
    /// - Parameter action: The action to send
    /// - Returns: The response event
    @discardableResult
    public func send(_ action: Action) async throws -> Event {
        guard let socket = socket else {
            throw PlynxError.notConnected
        }
        
        // Generate message ID
        messageId = messageId &+ 1
        let msgId = messageId
        
        // Convert action to message
        let message: BlynkMessage
        do {
            message = try action.toMessage(messageId: msgId, encoder: encoder)
        } catch {
            throw PlynxError.encodingError(error)
        }
        
        // Send the message
        try await socket.send(message)
        
        // Wait for response with timeout
        return try await withTimeout(seconds: responseTimeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Event, Error>) in
                Task {
                    await self.registerPendingResponse(msgId: msgId, continuation: continuation)
                }
            }
        }
    }
    
    private func registerPendingResponse(msgId: UInt16, continuation: CheckedContinuation<Event, Error>) {
        pendingResponses[msgId] = continuation
    }
    
    private func registerPendingDataResponse(msgId: UInt16, continuation: CheckedContinuation<BlynkMessage, Error>) {
        pendingDataResponses[msgId] = continuation
    }
    
    /// Send an action and wait for a data response (for commands like loadProfileGzipped that return data)
    private func sendForData(_ action: Action) async throws -> BlynkMessage {
        guard let socket = socket else {
            throw PlynxError.notConnected
        }
        
        // Generate message ID
        messageId = messageId &+ 1
        let msgId = messageId
        
        // Convert action to message
        let message: BlynkMessage
        do {
            message = try action.toMessage(messageId: msgId, encoder: encoder)
        } catch {
            throw PlynxError.encodingError(error)
        }
        
        // Send the message
        try await socket.send(message)
        
        // Wait for data response with timeout
        return try await withTimeout(seconds: responseTimeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BlynkMessage, Error>) in
                Task {
                    await self.registerPendingDataResponse(msgId: msgId, continuation: continuation)
                }
            }
        }
    }
    
    // MARK: - Message Handling
    
    private func startMessageHandler() {
        guard let socket = socket else { return }
        
        print("[Connector] Starting message handler loop")
        
        messageHandlerTask = Task { [weak self] in
            for await parsedMessage in socket.messages {
                guard let self = self else { break }
                await self.handleMessage(parsedMessage)
            }
            
            // Loop terminated - socket disconnected
            print("[Connector] Message handler loop terminated - socket stream ended")
            guard let self = self else { return }
            await self.handleSocketDisconnected()
        }
    }
    
    /// Called when the socket disconnects unexpectedly
    private func handleSocketDisconnected() {
        let wasAuthenticated = authenticated
        let wasConnected = socketConnected
        
        socketConnected = false
        authenticated = false
        
        print("[Connector] handleSocketDisconnected - was connected: \(wasConnected), was authenticated: \(wasAuthenticated)")
        
        // Emit disconnected event
        print("[Connector] Emitting .disconnected event")
        eventsContinuation?.yield(.disconnected(nil))
        
        // Notify via callback
        if wasConnected || wasAuthenticated {
            print("[Connector] Calling onConnectionStateChanged(false, false)")
            onConnectionStateChanged?(false, false)
        }
        
        // Cancel all pending responses
        print("[Connector] Cancelling \(pendingResponses.count) pending responses")
        for (_, continuation) in pendingResponses {
            continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingResponses.removeAll()
        
        print("[Connector] Cancelling \(pendingDataResponses.count) pending data responses")
        for (_, continuation) in pendingDataResponses {
            continuation.resume(throwing: PlynxError.connectionClosed)
        }
        pendingDataResponses.removeAll()
        
        // Avvia riconnessione automatica se avevamo credenziali
        if wasAuthenticated && (storedEmail != nil || storedShareToken != nil) {
            print("[Connector] Starting automatic reconnection...")
            Task {
                await startAutoReconnect()
            }
        }
    }
    
    // MARK: - Auto Reconnection
    
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt: Int = 0
    private let maxReconnectAttempts: Int = 10
    private let baseReconnectDelay: TimeInterval = 2.0
    private let maxReconnectDelay: TimeInterval = 30.0
    
    private func startAutoReconnect() async {
        reconnectTask?.cancel()
        reconnectAttempt = 0
        
        reconnectTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                self.reconnectAttempt += 1
                
                guard self.reconnectAttempt <= self.maxReconnectAttempts else {
                    print("[Connector] Max reconnect attempts reached, giving up")
                    break
                }
                
                // Calculate delay with exponential backoff
                let delay = min(self.baseReconnectDelay * pow(1.5, Double(self.reconnectAttempt - 1)), self.maxReconnectDelay)
                print("[Connector] Reconnect attempt \(self.reconnectAttempt)/\(self.maxReconnectAttempts) in \(String(format: "%.1f", delay))s...")
                
                self.eventsContinuation?.yield(.reconnecting(attempt: self.reconnectAttempt))
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                
                // Try to reconnect
                do {
                    if let email = self.storedEmail, let password = self.storedPassword, let appName = self.storedAppName {
                        print("[Connector] Attempting reconnect with email credentials...")
                        try await self.reconnectWithCredentials(email: email, password: password, appName: appName)
                        print("[Connector] Reconnection successful!")
                        self.reconnectAttempt = 0
                        break
                    } else if let token = self.storedShareToken {
                        print("[Connector] Attempting reconnect with share token...")
                        try await self.reconnectWithShareToken(token)
                        print("[Connector] Reconnection successful!")
                        self.reconnectAttempt = 0
                        break
                    }
                } catch {
                    print("[Connector] Reconnect attempt \(self.reconnectAttempt) failed: \(error)")
                    // Continue to next attempt
                }
            }
        }
    }
    
    private func reconnectWithCredentials(email: String, password: String, appName: String) async throws {
        // Create new socket
        let sock = PlynxSocket(host: host, port: port)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        // Start message handler
        startMessageHandler()
        
        // Login
        let response = try await send(.login(email: email, password: password, appName: appName))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.reconnected)
                onConnectionStateChanged?(true, true)
                startPingTimer()
            } else {
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    private func reconnectWithShareToken(_ token: String) async throws {
        // Create new socket
        let sock = PlynxSocket(host: host, port: port)
        self.socket = sock
        
        try await sock.connect()
        socketConnected = true
        
        // Start message handler
        startMessageHandler()
        
        // Share login
        let response = try await send(.shareLogin(token: token))
        
        if case .response(_, let code) = response {
            if code == .ok {
                authenticated = true
                eventsContinuation?.yield(.reconnected)
                onConnectionStateChanged?(true, true)
                startPingTimer()
            } else {
                throw PlynxError.authenticationFailed(code)
            }
        }
    }
    
    /// Stop automatic reconnection attempts
    public func stopReconnecting() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }
    
    private func handleMessage(_ parsedMessage: ParsedMessage) {
        // Check if this is a response to a pending request
        if case .response(let response) = parsedMessage {
            if let continuation = pendingResponses.removeValue(forKey: response.messageId) {
                let event = Event.response(messageId: response.messageId, code: response.code)
                continuation.resume(returning: event)
                return
            }
        }
        
        // Check if this is a command that acts as a data response (e.g., loadProfileGzipped)
        if case .command(let message) = parsedMessage {
            // Some commands are actually responses with data (same msgId as request)
            if let continuation = pendingDataResponses.removeValue(forKey: message.messageId) {
                print("[Connector] Command \(message.command) is a data response for msgId \(message.messageId)")
                continuation.resume(returning: message)
                return
            }
        }
        
        // Parse as event and emit
        if let event = Event.from(message: parsedMessage, decoder: decoder) {
            // Handle special cases
            switch event {
            case .response(let msgId, let code):
                // Check if it's for a pending request
                if let continuation = pendingResponses.removeValue(forKey: msgId) {
                    continuation.resume(returning: event)
                    return
                }
                
            default:
                break
            }
            
            // Invoke callbacks for specific events
            invokeCallbacks(for: event)
            
            // Yield to async stream
            eventsContinuation?.yield(event)
        }
    }
    
    /// Invoke registered callbacks for specific event types
    private func invokeCallbacks(for event: Event) {
        switch event {
        case .virtualPinUpdate(let dashId, let deviceId, let pin, let values):
            onVirtualPinUpdate?(dashId, deviceId, pin, values)
            onHardwareMessage?(dashId, deviceId, "vw\0\(pin)\0\(values.joined(separator: "\0"))")
            
        case .digitalPinUpdate(let dashId, let deviceId, let pin, let value):
            onDigitalPinUpdate?(dashId, deviceId, pin, value)
            onHardwareMessage?(dashId, deviceId, "dw\0\(pin)\0\(value)")
            
        case .analogPinUpdate(let dashId, let deviceId, let pin, let value):
            onAnalogPinUpdate?(dashId, deviceId, pin, value)
            onHardwareMessage?(dashId, deviceId, "aw\0\(pin)\0\(value)")
            
        case .hardwareMessage(let dashId, let deviceId, let body):
            onHardwareMessage?(dashId, deviceId, body)
            
        case .widgetPropertyChanged(let dashId, let deviceId, let pin, let property, let value):
            onWidgetPropertyChanged?(dashId, deviceId, pin, property, value)
            
        case .hardwareConnected(let dashId, let deviceId):
            onHardwareConnected?(dashId, deviceId)
            
        case .hardwareDisconnected(let dashId, let deviceId):
            onHardwareDisconnected?(dashId, deviceId)
            
        case .disconnected:
            let wasConnected = socketConnected
            socketConnected = false
            authenticated = false
            if wasConnected {
                onConnectionStateChanged?(false, false)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Ping Timer
    
    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pingInterval ?? 10.0) * 1_000_000_000)
                
                guard !Task.isCancelled, let self = self else { break }
                
                do {
                    _ = try await self.send(.ping)
                } catch {
                    // Ping failed, connection might be dead
                    print("PlynxConnector: Ping failed - \(error)")
                }
            }
        }
    }
    
    // MARK: - Reconnection Handling
    
    /// Called when reconnection is needed
    private func handleReconnection() async {
        guard authenticated else { return }
        
        // Mark as disconnected temporarily during reconnection
        socketConnected = false
        authenticated = false
        onConnectionStateChanged?(false, false)
        
        eventsContinuation?.yield(.reconnecting(attempt: await socket?.currentReconnectAttempt ?? 0))
        
        // Re-authenticate after reconnection
        if let email = storedEmail, let password = storedPassword, let appName = storedAppName {
            do {
                let response = try await send(.login(email: email, password: password, appName: appName))
                if case .response(_, let code) = response, code == .ok {
                    socketConnected = true
                    authenticated = true
                    onConnectionStateChanged?(true, true)
                    eventsContinuation?.yield(.reconnected)
                    startPingTimer()
                }
            } catch {
                print("PlynxConnector: Re-authentication failed - \(error)")
            }
        } else if let token = storedShareToken {
            do {
                let response = try await send(.shareLogin(token: token))
                if case .response(_, let code) = response, code == .ok {
                    socketConnected = true
                    authenticated = true
                    onConnectionStateChanged?(true, true)
                    eventsContinuation?.yield(.reconnected)
                    startPingTimer()
                }
            } catch {
                print("PlynxConnector: Re-authentication failed - \(error)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Load and decode user profile
    /// - Returns: The user profile
    public func loadProfile() async throws -> Profile {
        // The server responds to loadProfile with a loadProfileGzipped command containing gzipped JSON
        let response = try await sendForData(.loadProfile(dashId: nil, published: false))
        
        guard response.command == .loadProfileGzipped else {
            print("[Connector] Unexpected response command: \(response.command)")
            throw PlynxError.unexpectedResponse
        }
        
        guard let rawData = response.rawData, !rawData.isEmpty else {
            print("[Connector] No data in profile response")
            return Profile()
        }
        
        print("[Connector] Received profile data: \(rawData.count) bytes")
        
        // Decompress gzip data
        let decompressedData: Data
        do {
            decompressedData = try GzipHelper.decompress(rawData)
            print("[Connector] Decompressed profile: \(decompressedData.count) bytes")
        } catch {
            print("[Connector] Failed to decompress: \(error)")
            throw PlynxError.decodingError(error)
        }
        
        // Debug: print raw JSON
        if let jsonString = String(data: decompressedData, encoding: .utf8) {
            print("[Connector] Profile JSON: \(jsonString.prefix(500))...")
        }
        
        // Decode JSON to Profile
        do {
            let profile = try decoder.decode(Profile.self, from: decompressedData)
            print("[Connector] Decoded profile with \(profile.dashBoards?.count ?? 0) dashboards")
            return profile
        } catch {
            print("[Connector] Failed to decode profile: \(error)")
            throw PlynxError.decodingError(error)
        }
    }
    
    /// Write a value to a virtual pin
    /// - Parameters:
    ///   - dashId: Dashboard ID
    ///   - deviceId: Device ID
    ///   - pin: Pin number
    ///   - value: Value to write
    @discardableResult
    public func writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String) async throws -> Event {
        return try await send(.writeVirtualPin(dashId: dashId, deviceId: deviceId, pin: pin, value: value))
    }
    
    /// Activate a dashboard
    /// - Parameter dashId: Dashboard ID
    @discardableResult
    public func activateDashboard(_ dashId: Int) async throws -> Event {
        let result = try await send(.activateDashboard(dashId: dashId))
        if case .response(_, let code) = result, code == .ok {
            activeDashboardId = dashId
        }
        return result
    }
    
    /// Deactivate all dashboards
    @discardableResult
    public func deactivateAllDashboards() async throws -> Event {
        let result = try await send(.deactivateDashboard(dashId: nil))
        if case .response(_, let code) = result, code == .ok {
            activeDashboardId = nil
        }
        return result
    }
}

// MARK: - Timeout Helper

private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw PlynxError.timeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
