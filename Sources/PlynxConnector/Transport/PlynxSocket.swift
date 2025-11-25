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
        print("[PlynxSocket] Establishing connection to \(host):\(port)...")
        
        // Create TLS parameters that accept self-signed certificates
        let tlsOptions = NWProtocolTLS.Options()
        
        print("[PlynxSocket] Configuring TLS (accept all certificates)...")
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            // Accept all certificates (for self-signed server certs)
            // In production, you might want to implement proper certificate pinning
            print("[PlynxSocket] TLS verify block called - accepting certificate")
            sec_protocol_verify_complete(true)
        }, DispatchQueue.global())
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10
        tcpOptions.keepaliveInterval = 5
        tcpOptions.keepaliveCount = 3
        
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        print("[PlynxSocket] Created endpoint: \(endpoint)")
        
        let conn = NWConnection(to: endpoint, using: parameters)
        
        self.connection = conn
        
        print("[PlynxSocket] Starting connection...")
        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            
            conn.stateUpdateHandler = { [weak self] state in
                Task { [weak self] in
                    await self?.handleStateChange(state)
                }
            }
            
            conn.start(queue: .global())
            print("[PlynxSocket] Connection started, waiting for state changes...")
        }
    }
    
    private func handleStateChange(_ state: NWConnection.State) {
        print("[PlynxSocket] State changed to: \(state)")
        
        switch state {
        case .setup:
            print("[PlynxSocket] Connection setup in progress...")
            
        case .preparing:
            print("[PlynxSocket] Connection preparing (DNS lookup, TCP handshake, TLS handshake)...")
            
        case .ready:
            print("[PlynxSocket] ✅ Connection READY!")
            isConnecting = false
            reconnectAttempt = 0
            
            // Start receiving data
            startReceiving()
            
            // Complete the connection continuation
            connectionContinuation?.resume()
            connectionContinuation = nil
            
        case .failed(let error):
            print("[PlynxSocket] ❌ Connection FAILED: \(error)")
            print("[PlynxSocket] Error details: \(error.localizedDescription)")
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
            print("[PlynxSocket] Connection CANCELLED")
            isConnecting = false
            connection = nil
            connectionContinuation?.resume(throwing: PlynxError.cancelled)
            connectionContinuation = nil
            
        case .waiting(let error):
            // Network temporarily unavailable - fail the connection after a short wait
            print("[PlynxSocket] ⏳ Connection WAITING: \(error)")
            print("[PlynxSocket] Waiting error details: \(error.localizedDescription)")
            
            // If we've been waiting too long, fail the connection
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds max waiting
                if case .waiting = self.connection?.state {
                    self.connection?.cancel()
                    self.connectionContinuation?.resume(throwing: PlynxError.connectionFailed(underlying: error))
                    self.connectionContinuation = nil
                }
            }
            
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
                    print("[PlynxSocket] Receive error - \(error)")
                    // Errore di ricezione - connessione persa
                    await self.handleConnectionLost(error: error)
                    return
                }
                
                if isComplete {
                    // Connection closed by server
                    print("[PlynxSocket] Connection closed by server (isComplete=true)")
                    await self.handleConnectionClosed()
                    return
                }
                
                // Continue receiving
                await self.startReceiving()
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        print("[PlynxSocket] Received \(data.count) bytes: \(data.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " "))\(data.count > 20 ? "..." : "")")
        parser.append(data)
        
        // Parse all complete messages
        let messages = parser.parseAll()
        print("[PlynxSocket] Parsed \(messages.count) messages")
        for message in messages {
            messagesContinuation?.yield(message)
        }
    }
    
    private func handleConnectionClosed() {
        print("[PlynxSocket] handleConnectionClosed called")
        connection?.cancel()
        connection = nil
        
        // Termina lo stream di messaggi per notificare il Connector
        print("[PlynxSocket] Finishing messages stream")
        messagesContinuation?.finish()
        messagesContinuation = nil
        
        if shouldReconnect {
            Task {
                await attemptReconnect()
            }
        }
    }
    
    /// Gestisce la perdita di connessione (errore di rete)
    private func handleConnectionLost(error: Error) {
        print("[PlynxSocket] handleConnectionLost called - error: \(error.localizedDescription)")
        connection?.cancel()
        connection = nil
        
        // Termina lo stream di messaggi per notificare il Connector
        print("[PlynxSocket] Finishing messages stream due to connection lost")
        messagesContinuation?.finish()
        messagesContinuation = nil
        
        // Non tentare riconnessione automatica dal socket - lascia che il Connector gestisca
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
