import Foundation
import Network

actor PlynxSocket {
    
    // MARK: - Properties
    
    private let host: String
    private let port: UInt16
    private let useSSL: Bool
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
    
    nonisolated let messages: AsyncStream<ParsedMessage>
    
    // MARK: - Initialization
    
    init(host: String, port: UInt16, useSSL: Bool = true) {
        self.host = host
        self.port = port
        self.useSSL = useSSL
        
        var continuation: AsyncStream<ParsedMessage>.Continuation!
        self.messages = AsyncStream { continuation = $0 }
        self.messagesContinuation = continuation
    }
    
    // MARK: - Connection
    
    func connect() async throws {
        guard connection == nil && !isConnecting else { return }
        
        isConnecting = true
        shouldReconnect = true
        reconnectAttempt = 0
        
        try await establishConnection()
    }
    
    private func establishConnection() async throws {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10
        tcpOptions.keepaliveInterval = 5
        tcpOptions.keepaliveCount = 3
        
        let parameters: NWParameters
        
        if useSSL {
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_verify_block(
                tlsOptions.securityProtocolOptions,
                { _, _, sec_protocol_verify_complete in
                    sec_protocol_verify_complete(true)
                },
                DispatchQueue.global()
            )
            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw PlynxError.connectionFailed(underlying: nil)
        }
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )
        
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
        case .setup, .preparing:
            break
            
        case .ready:
            isConnecting = false
            reconnectAttempt = 0
            startReceiving()
            connectionContinuation?.resume()
            connectionContinuation = nil
            
        case .failed(let error):
            isConnecting = false
            connection = nil
            connectionContinuation?.resume(throwing: PlynxError.connectionFailed(underlying: error))
            connectionContinuation = nil
            
            Task {
                await attemptReconnect()
            }
            
        case .cancelled:
            isConnecting = false
            connection = nil
            connectionContinuation?.resume(throwing: PlynxError.cancelled)
            connectionContinuation = nil
            
        case .waiting(let error):
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
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
        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1)), maxReconnectDelay)
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        guard shouldReconnect else { return }
        
        do {
            try await establishConnection()
        } catch {
        }
    }
    
    // MARK: - Sending
    
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
                    await self.handleConnectionLost(error: error)
                    return
                }
                
                if isComplete {
                    await self.handleConnectionClosed()
                    return
                }
                
                await self.startReceiving()
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        parser.append(data)
        
        let messages = parser.parseAll()
        for message in messages {
            messagesContinuation?.yield(message)
        }
    }
    
    private func handleConnectionClosed() {
        connection?.cancel()
        connection = nil
        messagesContinuation?.finish()
        messagesContinuation = nil
        
        if shouldReconnect {
            Task {
                await attemptReconnect()
            }
        }
    }
    
    private func handleConnectionLost(error: Error) {
        connection?.cancel()
        connection = nil
        messagesContinuation?.finish()
        messagesContinuation = nil
    }
    
    // MARK: - Status
    
    var isConnected: Bool {
        connection?.state == .ready
    }
    
    var currentReconnectAttempt: Int {
        reconnectAttempt
    }
    
    func setReconnectionPolicy(maxAttempts: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) {
        self.maxReconnectAttempts = maxAttempts
        self.baseReconnectDelay = baseDelay
        self.maxReconnectDelay = maxDelay
    }
}
