import Foundation

public actor MockConnector {

    public private(set) var authenticated: Bool = false
    public private(set) var socketConnected: Bool = false
    public private(set) var activeDashboardId: Int?
    public nonisolated let events: AsyncStream<Event>

    private var eventsContinuation: AsyncStream<Event>.Continuation?
    public private(set) var sentActions: [Action] = []
    private var cannedResponses: [Event] = []
    private var defaultResponse: Event = .response(messageId: 0, code: .ok)

    public var onVirtualPinUpdate: ((Int, Int, Int, [String]) -> Void)?
    public var onDigitalPinUpdate: ((Int, Int, Int, Int) -> Void)?
    public var onAnalogPinUpdate: ((Int, Int, Int, Int) -> Void)?
    public var onWidgetPropertyChanged: ((Int, Int, Int, WidgetProperty, String) -> Void)?
    public var onHardwareConnected: ((Int, Int) -> Void)?
    public var onHardwareDisconnected: ((Int, Int) -> Void)?
    public var onConnectionStateChanged: ((Bool, Bool) -> Void)?
    public var onHardwareMessage: ((Int, Int, String) -> Void)?

    public var mockProfileData: Data?
    public var mockDevices: [Device] = []
    public var shouldFailConnect: Bool = false
    public var shouldFailSend: Bool = false

    public static let defaultPort: UInt16 = 9443
    public var responseTimeout: TimeInterval = 10.0
    public var pingInterval: TimeInterval = 10.0

    private var messageIdCounter: UInt16 = 0

    public init() {
        var continuation: AsyncStream<Event>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
    }

    deinit {
        eventsContinuation?.finish()
    }

    public func connect(email: String, password: String, appName: String = "Blynk") async throws {
        if shouldFailConnect {
            throw PlynxError.connectionFailed(underlying: nil)
        }
        socketConnected = true
        authenticated = true
        eventsContinuation?.yield(.connected)
        eventsContinuation?.yield(.loginSuccess)
        onConnectionStateChanged?(true, true)
    }

    public func connectWithShareToken(_ token: String) async throws {
        if shouldFailConnect {
            throw PlynxError.connectionFailed(underlying: nil)
        }
        socketConnected = true
        authenticated = true
        eventsContinuation?.yield(.connected)
        eventsContinuation?.yield(.loginSuccess)
        onConnectionStateChanged?(true, true)
    }

    public func register(email: String, password: String, appName: String = "Blynk") async throws {
        if shouldFailConnect {
            throw PlynxError.connectionFailed(underlying: nil)
        }
        eventsContinuation?.yield(.registered)
    }

    public func disconnect() async {
        authenticated = false
        socketConnected = false
        activeDashboardId = nil
        eventsContinuation?.yield(.disconnected(nil))
        onConnectionStateChanged?(false, false)
    }

    public var isConnected: Bool {
        socketConnected && authenticated
    }

    @discardableResult
    public func send(_ action: Action) async throws -> Event {
        sentActions.append(action)

        if shouldFailSend {
            throw PlynxError.notConnected
        }

        messageIdCounter = messageIdCounter &+ 1
        let msgId = messageIdCounter

        switch action {
        case .login:
            authenticated = true
            eventsContinuation?.yield(.loginSuccess)
            return .loginSuccess

        case .shareLogin:
            authenticated = true
            eventsContinuation?.yield(.loginSuccess)
            return .loginSuccess

        case .activateDashboard(let dashId):
            activeDashboardId = dashId
            return .response(messageId: msgId, code: .ok)

        case .deactivateDashboard:
            activeDashboardId = nil
            return .response(messageId: msgId, code: .ok)

        case .loadProfile:
            if let data = mockProfileData {
                return .profileLoaded(data)
            }
            let emptyProfile = Profile()
            let encoded = try JSONEncoder().encode(emptyProfile)
            return .profileLoaded(encoded)

        case .getDevices:
            return .devicesLoaded(mockDevices)

        default:
            if !cannedResponses.isEmpty {
                return cannedResponses.removeFirst()
            }
            return .response(messageId: msgId, code: .ok)
        }
    }

    public func sendData(_ action: Action) async throws -> BlynkMessage {
        sentActions.append(action)

        if shouldFailSend {
            throw PlynxError.notConnected
        }

        messageIdCounter = messageIdCounter &+ 1
        let msgId = messageIdCounter

        if case .loadProfile = action, let data = mockProfileData {
            return BlynkMessage(command: .loadProfileGzipped, messageId: msgId, body: "", rawData: data)
        }

        return BlynkMessage(command: .response, messageId: msgId, body: "")
    }

    // MARK: - Test Helpers

    public func emitEvent(_ event: Event) {
        eventsContinuation?.yield(event)
    }

    public func setDefaultResponse(_ response: Event) {
        defaultResponse = response
        cannedResponses.removeAll()
    }

    public func enqueueResponse(_ response: Event) {
        cannedResponses.append(response)
    }

    public func enqueueResponses(_ responses: [Event]) {
        cannedResponses.append(contentsOf: responses)
    }

    public func reset() {
        sentActions.removeAll()
        cannedResponses.removeAll()
        defaultResponse = .response(messageId: 0, code: .ok)
        authenticated = false
        socketConnected = false
        activeDashboardId = nil
        shouldFailConnect = false
        shouldFailSend = false
        mockProfileData = nil
        mockDevices.removeAll()
        messageIdCounter = 0
    }

    public func lastSentAction() -> Action? {
        sentActions.last
    }

    public func sentActionCount(matching filter: (Action) -> Bool) -> Int {
        sentActions.filter(filter).count
    }
}
