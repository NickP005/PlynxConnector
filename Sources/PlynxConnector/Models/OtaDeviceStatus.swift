//
//  OtaDeviceStatus.swift
//  PlynxConnector
//
//  Una scheda vista dall'OTA: che lineage segue, se è una scheda di test
//  (canary), se è online, che build sta girando e — quando un aggiornamento è
//  in corso — la macchina a stati per-scheda (PENDING → SENT → SUCCESS /
//  FAILED / ROLLED_BACK).
//
//  È la stessa forma sia dentro `OtaSnapshot.devices` (comando OTA_LIST) sia
//  come risposta singola di OTA_STATUS.
//

import Foundation

public struct OtaDeviceStatus: Sendable, Codable, Identifiable, Hashable {

    /// Stato dell'aggiornamento di una scheda. Stringa lato server (non enum),
    /// così un rollback del jar non rompe la decodifica: gli stati sconosciuti
    /// cadono in `.unknown` invece di far fallire tutto lo snapshot.
    public enum State: Sendable, Codable, Hashable {
        case pending
        case sent
        case success
        case failed
        case rolledBack
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue.uppercased() {
            case "PENDING": self = .pending
            case "SENT": self = .sent
            case "SUCCESS": self = .success
            case "FAILED": self = .failed
            case "ROLLED_BACK": self = .rolledBack
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .pending: return "PENDING"
            case .sent: return "SENT"
            case .success: return "SUCCESS"
            case .failed: return "FAILED"
            case .rolledBack: return "ROLLED_BACK"
            case .unknown(let raw): return raw
            }
        }

        /// L'aggiornamento è ancora in volo (nessun esito definitivo).
        public var isInFlight: Bool {
            switch self {
            case .pending, .sent: return true
            default: return false
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.init(rawValue: try container.decode(String.self))
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    /// Aggiornamento in corso (o ultimo tentato) su questa scheda.
    public struct Update: Sendable, Codable, Hashable {
        /// Versione firmware verso cui la scheda sta andando.
        public let targetVersionId: String?
        public let state: State?
        /// Epoch millis dell'invio del frame di trigger (0 se mai inviato).
        public let sentAt: Int64?
        /// Tentativi già fatti (il server mette in pausa dopo il limite).
        public let attempts: Int
        /// Ultima build riportata dalla scheda al login: è così che il server
        /// riconosce successo, fallimento e rollback.
        public let lastReportedBuild: String?

        public init(targetVersionId: String?, state: State?, sentAt: Int64?,
                    attempts: Int, lastReportedBuild: String?) {
            self.targetVersionId = targetVersionId
            self.state = state
            self.sentAt = sentAt
            self.attempts = attempts
            self.lastReportedBuild = lastReportedBuild
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.targetVersionId = try c.decodeIfPresent(String.self, forKey: .targetVersionId)
            self.state = try c.decodeIfPresent(State.self, forKey: .state)
            self.sentAt = try c.decodeIfPresent(Int64.self, forKey: .sentAt)
            self.attempts = try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
            self.lastReportedBuild = try c.decodeIfPresent(String.self, forKey: .lastReportedBuild)
        }
    }

    public let dashId: Int
    public let deviceId: Int
    public let name: String?
    /// Etichetta del tipo di scheda (es. "ESP32"), quando il server la conosce.
    public let boardType: String?
    /// Lineage seguito dalla scheda (nil = nessuno: non riceve le promote).
    public let followLineageId: String?
    /// Scheda di test: riceve per prima le promote (canary).
    public let isTestBoard: Bool
    /// La scheda è connessa al server in questo momento.
    public let online: Bool
    /// Build firmware riportata dalla scheda all'ultimo login.
    public let currentBuild: String?
    /// Aggiornamento in corso/ultimo tentato (nil = nessun OTA su questa scheda).
    public let ota: Update?

    public var id: String { "\(dashId):\(deviceId)" }

    /// Riferimento pronto da rimandare ai comandi OTA.
    public var ref: OtaDeviceRef { .device(dashId: dashId, deviceId: deviceId) }

    // Scorciatoie sui campi dell'aggiornamento, per non far scendere la UI
    // dentro l'oggetto annidato a ogni riga di lista.
    public var state: State? { ota?.state }
    public var targetVersionId: String? { ota?.targetVersionId }
    public var lastReportedBuild: String? { ota?.lastReportedBuild }

    public init(dashId: Int, deviceId: Int, name: String? = nil, boardType: String? = nil,
                followLineageId: String? = nil, isTestBoard: Bool = false, online: Bool = false,
                currentBuild: String? = nil, ota: Update? = nil) {
        self.dashId = dashId
        self.deviceId = deviceId
        self.name = name
        self.boardType = boardType
        self.followLineageId = followLineageId
        self.isTestBoard = isTestBoard
        self.online = online
        self.currentBuild = currentBuild
        self.ota = ota
    }

    private enum CodingKeys: String, CodingKey {
        case dashId, deviceId, name, boardType, followLineageId, isTestBoard
        case online, currentBuild, ota
        //forma alternativa (campi dell'update sul livello alto)
        case targetVersionId, state, sentAt, attempts, lastReportedBuild
    }

    // Decoding difensivo: il server omette i campi null, e i flag mancanti
    // valgono "no". L'update arriva annidato in `ota`, ma se un domani (o il
    // gobackend al cutover) lo appiattisse sul livello alto lo ricostruiamo lo
    // stesso invece di perderlo in silenzio.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dashId = try c.decode(Int.self, forKey: .dashId)
        self.deviceId = try c.decode(Int.self, forKey: .deviceId)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.boardType = try c.decodeIfPresent(String.self, forKey: .boardType)
        self.followLineageId = try c.decodeIfPresent(String.self, forKey: .followLineageId)
        self.isTestBoard = try c.decodeIfPresent(Bool.self, forKey: .isTestBoard) ?? false
        self.online = try c.decodeIfPresent(Bool.self, forKey: .online) ?? false
        self.currentBuild = try c.decodeIfPresent(String.self, forKey: .currentBuild)

        if let nested = try c.decodeIfPresent(Update.self, forKey: .ota) {
            self.ota = nested
        } else {
            let targetVersionId = try c.decodeIfPresent(String.self, forKey: .targetVersionId)
            let state = try c.decodeIfPresent(State.self, forKey: .state)
            if targetVersionId != nil || state != nil {
                self.ota = Update(
                    targetVersionId: targetVersionId,
                    state: state,
                    sentAt: try c.decodeIfPresent(Int64.self, forKey: .sentAt),
                    attempts: try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0,
                    lastReportedBuild: try c.decodeIfPresent(String.self, forKey: .lastReportedBuild))
            } else {
                self.ota = nil
            }
        }
    }

    //l'encoding usa sempre la forma canonica del server (update annidato).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dashId, forKey: .dashId)
        try c.encode(deviceId, forKey: .deviceId)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(boardType, forKey: .boardType)
        try c.encodeIfPresent(followLineageId, forKey: .followLineageId)
        try c.encode(isTestBoard, forKey: .isTestBoard)
        try c.encode(online, forKey: .online)
        try c.encodeIfPresent(currentBuild, forKey: .currentBuild)
        try c.encodeIfPresent(ota, forKey: .ota)
    }
}
