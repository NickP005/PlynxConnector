//
//  PlynxSocket.swift
//  PlynxConnector
//
//  SSL TCP socket for Plynx server communication with auto-reconnection.
//

import Foundation
import Network

/// Internal socket implementation for Plynx server communication.
actor PlynxSocket {
    
    // MARK: - Properties
    
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var parser = MessageParser()
    
    private var isConnecting = false
    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private var maxReconnectAttempts = 10
    private var baseReconnectDelay: TimeInterval = 1.0
    private var maxReconnectDelay: TimeInterval = 60.0
    
    private var messagesContinuation: AsyncStream<ParsedMessage>.Continuation?
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    
    /// Stream of parsed messages from the server
    nonisolated let messages: AsyncStream<ParsedMessage>
    
    // MARK: - Initialization
    
    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        
        var continuation: AsyncStream<ParsedMessage>.Continuation!
        self.messages = AsyncStream { continuation = $0 }
        self.messagesContinuation = continuation
    }
    
    // MARK: - Connection
    
    /// Connect to the server
    func connect() async throws {
        guard connection == nil && !isConnecting else { return }
        
        isConnecting = true
        shouldReconnect = true
        reconnectAttempt = 0
        
        try await establishConnection()
    }
    
    private func establishConnection() async throws {
        // Create TLS parameters that accept self-signed certificates
        let tlsOptions = NWProtocolTLS.Options()
        
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            // Accept all certificates (for self-signed server certs)
            // In production, you might want to implement proper certificate pinning
            sec_protocol_verify_complete(true)
        }, DispatchQueue.global())
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10
        tcpOptions.keepaliveInterval = 5
        tcpOptions.keepaliveCount = 3
        
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let conn = NWConnection(to: endpoint, using: parameters)
        
        self.connection = conn
        
        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            
            conn.stateUpdateHandler = { [weak self] state in
                Task { [weak self] in
                    await self?.handleStateChange(state)
                }
            }
            
            conn.start(queue: .global())
        }
    }
    
    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnecting = false
            reconnectAttempt = 0
            
            // Start receiving data
            startReceiving()
            
            // Complete the connection continuation
            connectionContinuation?.resume()
            connectionContinuation = nil
            
        case .failed(let error):
            isConnecting = false
            connection = nil
            
            // Complete with error if we were connecting
            connectionContinuation?.resume(throwing: PlynxError.connectionFailed(underlying: error))
            connectionContinuation = nil
            
            // Attempt reconnection if enabled
            Task {
                await attemptReconnect()
            }
            
        case .cancelled:
            isConnecting = false
            connection = nil
            connectionContinuation?.resume(throwing: PlynxError.cancelled)
            connectionContinuation = nil
            
        case .waiting(let error):
            // Network temporarily unavailable
            print("PlynxSocket: Waiting - \(error)")
            
        default:
            break
        }
    }
    
    /// Disconnect from the server
    func disconnect() {
        shouldReconnect = false
        connection?.cancel()
        connection = nil
        parser.reset()
        messagesContinuation?.finish()
    }
    
    // MARK: - Reconnection
    
    private func attemptReconnect() async {
        guard shouldReconnect && reconnectAttempt < maxReconnectAttempts else {
            return
        }
        
        reconnectAttempt += 1
        
        // Calculate delay with exponential backoff
        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1)), maxReconnectDelay)
        
        // Notify about reconnection attempt (via a special message or callback)
        // The PlynxConnector will handle this
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        guard shouldReconnect else { return }
        
        do {
            try await establishConnection()
        } catch {
            // Will trigger another reconnect attempt via state handler
        }
    }
    
    // MARK: - Sending
    
    /// Send data to the server
    func send(_ data: Data) async throws {
        guard let conn = connection else {
            throw PlynxError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: PlynxError.connectionFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    /// Send a message to the server
    func send(_ message: BlynkMessage) async throws {
        try await send(message.serialize())
    }
    
    // MARK: - Receiving
    
    private func startReceiving() {
        guard let conn = connection else { return }
        
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self = self else { return }
                
                if let data = data, !data.isEmpty {
                    await self.handleReceivedData(data)
                }
                
                if let error = error {
                    print("PlynxSocket: Receive error - \(error)")
                    return
                }
                
                if isComplete {
                    // Connection closed by server
                    await self.handleConnectionClosed()
                    return
                }
                
                // Continue receiving
                await self.startReceiving()
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        parser.append(data)
        
        // Parse all complete messages
        let messages = parser.parseAll()
        for message in messages {
            messagesContinuation?.yield(message)
        }
    }
    
    private func handleConnectionClosed() {
        connection?.cancel()
        connection = nil
        
        if shouldReconnect {
            Task {
                await attemptReconnect()
            }
        }
    }
    
    // MARK: - Status
    
    /// Whether currently connected
    var isConnected: Bool {
        connection?.state == .ready
    }
    
    /// Current reconnection attempt number (0 if connected)
    var currentReconnectAttempt: Int {
        reconnectAttempt
    }
    
    /// Set reconnection parameters
    func setReconnectionPolicy(maxAttempts: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) {
        self.maxReconnectAttempts = maxAttempts
        self.baseReconnectDelay = baseDelay
        self.maxReconnectDelay = maxDelay
    }
}
