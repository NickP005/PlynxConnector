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

    /// Da dove viene la durata attesa dell'installazione: una misura vera di
    /// questa scheda, oppure una stima dichiarata. Serve a non far passare per
    /// misurato un numero che è un'ipotesi.
    public enum InstallEstimateSource: String, Sendable, Codable, Hashable {
        /// Mediana degli aggiornamenti già misurati su QUESTA scheda.
        case measured
        /// Ricavata dalla taglia del binario: la scheda non l'ha mai fatto.
        case estimated
    }

    /// Aggiornamento in corso (o ultimo tentato) su questa scheda.
    ///
    /// Dopo i primi cinque campi, tutto è ADDITIVO: un server più vecchio non
    /// manda niente e i campi restano `nil`, quindi chi legge deve degradare al
    /// comportamento di prima invece di mostrare uno zero.
    ///
    /// Il server pubblica solo FATTI GREZZI (byte, timestamp, durate misurate)
    /// e lascia a chi disegna il calcolo di fasi, percentuali e attese: così
    /// nessuna stima nasce dentro il jar e la presentazione può cambiare senza
    /// un redeploy.
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

        // MARK: Progresso del download (additivo)

        /// Taglia del binario di destinazione. 0 = il server non ce l'ha più.
        public let totalBytes: Int64?
        /// MISURATO: byte del binario già passati verso questa scheda. Sono
        /// "consegnati al socket", non "scritti in flash": il TCP fa da freno,
        /// ma il server resta comunque un po' avanti rispetto alla scheda.
        /// È quindi sempre una sovrastima, mai una sottostima.
        public let sentBytes: Int64?
        /// Epoch millis del primo byte inviato (0 = download non ancora partito).
        public let downloadStartedAt: Int64?
        /// Epoch millis dell'ultimo avanzamento: fermo + `sentBytes` sotto il
        /// totale = trasferimento in stallo.
        public let lastByteAt: Int64?
        /// Epoch millis della fine del trasferimento (0 = ancora in volo).
        public let downloadCompletedAt: Int64?
        /// Il trasferimento si è rotto a metà: di norma la scheda riprova da sola.
        public let downloadFailed: Bool?
        /// MISURATA: durata dell'ultimo download completato da questa scheda.
        public let lastDownloadMs: Int64?
        /// Durata attesa della fase invisibile dopo il download (scrittura in
        /// flash, verifica, riavvio, rientro in rete). Misurata o stimata:
        /// lo dice `expectedInstallSource`.
        public let expectedInstallMs: Int64?
        public let expectedInstallSource: InstallEstimateSource?
        /// Finestra di tolleranza del server: sotto questa soglia un rientro
        /// con la build vecchia è ancora lo stesso aggiornamento in corso, non
        /// un fallimento.
        public let resendGraceMs: Int64?

        public init(targetVersionId: String?, state: State?, sentAt: Int64?,
                    attempts: Int, lastReportedBuild: String?,
                    totalBytes: Int64? = nil, sentBytes: Int64? = nil,
                    downloadStartedAt: Int64? = nil, lastByteAt: Int64? = nil,
                    downloadCompletedAt: Int64? = nil, downloadFailed: Bool? = nil,
                    lastDownloadMs: Int64? = nil, expectedInstallMs: Int64? = nil,
                    expectedInstallSource: InstallEstimateSource? = nil,
                    resendGraceMs: Int64? = nil) {
            self.targetVersionId = targetVersionId
            self.state = state
            self.sentAt = sentAt
            self.attempts = attempts
            self.lastReportedBuild = lastReportedBuild
            self.totalBytes = totalBytes
            self.sentBytes = sentBytes
            self.downloadStartedAt = downloadStartedAt
            self.lastByteAt = lastByteAt
            self.downloadCompletedAt = downloadCompletedAt
            self.downloadFailed = downloadFailed
            self.lastDownloadMs = lastDownloadMs
            self.expectedInstallMs = expectedInstallMs
            self.expectedInstallSource = expectedInstallSource
            self.resendGraceMs = resendGraceMs
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.targetVersionId = try c.decodeIfPresent(String.self, forKey: .targetVersionId)
            self.state = try c.decodeIfPresent(State.self, forKey: .state)
            self.sentAt = try c.decodeIfPresent(Int64.self, forKey: .sentAt)
            self.attempts = try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
            self.lastReportedBuild = try c.decodeIfPresent(String.self, forKey: .lastReportedBuild)
            self.totalBytes = try c.decodeIfPresent(Int64.self, forKey: .totalBytes)
            self.sentBytes = try c.decodeIfPresent(Int64.self, forKey: .sentBytes)
            self.downloadStartedAt = try c.decodeIfPresent(Int64.self, forKey: .downloadStartedAt)
            self.lastByteAt = try c.decodeIfPresent(Int64.self, forKey: .lastByteAt)
            self.downloadCompletedAt = try c.decodeIfPresent(Int64.self, forKey: .downloadCompletedAt)
            self.downloadFailed = try c.decodeIfPresent(Bool.self, forKey: .downloadFailed)
            self.lastDownloadMs = try c.decodeIfPresent(Int64.self, forKey: .lastDownloadMs)
            self.expectedInstallMs = try c.decodeIfPresent(Int64.self, forKey: .expectedInstallMs)
            // Sorgente sconosciuta = trattata come assente: un valore nuovo del
            // server non deve far fallire tutto lo snapshot.
            self.expectedInstallSource = (try c.decodeIfPresent(
                String.self, forKey: .expectedInstallSource)).flatMap(InstallEstimateSource.init)
            self.resendGraceMs = try c.decodeIfPresent(Int64.self, forKey: .resendGraceMs)
        }

        // MARK: Letture comode, senza inventare numeri

        /// Il server pubblica il progresso del download (jar recente).
        public var hasProgressData: Bool {
            totalBytes != nil || downloadStartedAt != nil
        }

        /// Il download è cominciato davvero (primo byte partito).
        public var downloadStarted: Bool {
            (downloadStartedAt ?? 0) > 0
        }

        /// Il trasferimento è concluso: da qui in poi la scheda scrive in flash
        /// e si riavvia, e il server non vede più niente.
        public var downloadCompleted: Bool {
            (downloadCompletedAt ?? 0) > 0
        }

        /// Frazione 0...1 del binario già trasferito. `nil` quando la taglia
        /// non è nota: meglio nessuna barra che una barra inventata.
        public var downloadFraction: Double? {
            guard let totalBytes, totalBytes > 0 else { return nil }
            let sent = max(0, sentBytes ?? 0)
            return min(1, Double(sent) / Double(totalBytes))
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

    // Additivi (jar recente): servono a distinguere una scheda che si sta
    // riavviando da una semplicemente ferma, senza fidarsi dell'orologio del
    // telefono.
    /// Epoch millis dell'ultima connessione della scheda (0 = mai).
    public let connectTime: Int64?
    /// Epoch millis dell'ultima disconnessione (0 = mai).
    public let disconnectTime: Int64?
    /// Orologio del server nel momento in cui ha costruito questa risposta:
    /// con questo i tempi trascorsi si calcolano nel fuso del server, senza
    /// ereditare lo scarto dell'orologio del telefono.
    public let serverNow: Int64?

    // MARK: Capacità di flash dichiarate dalla scheda (additive)
    //
    // Le riporta la scheda stessa nel `blnkinf` al login, e il server le
    // ripubblica solo quando le conosce davvero: chiave ASSENTE = mai riportate
    // (firmware vecchio, scheda mai connessa, target non-ESP). Assente non è
    // zero — `otaMaxBytes == 0` è la scheda che dichiara di NON poter fare OTA.

    /// La più grande immagine che questa scheda può accettare via OTA adesso
    /// (partizione OTA su ESP32, spazio sketch libero su ESP8266).
    /// `nil` = la scheda non l'ha mai detto; `0` = non può fare OTA.
    public let otaMaxBytes: Int64?
    /// Flash totale configurata per questo build. Solo informativa.
    public let flashBytes: Int64?
    /// Byte occupati dallo sketch in esecuzione. Solo informativa.
    public let sketchBytes: Int64?

    public var id: String { "\(dashId):\(deviceId)" }

    /// Riferimento pronto da rimandare ai comandi OTA.
    public var ref: OtaDeviceRef { .device(dashId: dashId, deviceId: deviceId) }

    // Scorciatoie sui campi dell'aggiornamento, per non far scendere la UI
    // dentro l'oggetto annidato a ogni riga di lista.
    public var state: State? { ota?.state }
    public var targetVersionId: String? { ota?.targetVersionId }
    public var lastReportedBuild: String? { ota?.lastReportedBuild }

    /// Le capacità di flash sono note per questa scheda.
    public var hasFlashCapabilities: Bool { otaMaxBytes != nil }

    /// Un binario di questa taglia ci sta? `nil` = **non si sa**, e allora non
    /// si blocca niente: una scheda che non ha mai riportato le sue capacità
    /// non deve trovarsi un divieto costruito su un numero inventato.
    /// `false` solo su un dato riportato davvero, confrontato senza margini
    /// (è lo stesso byte contro cui il dispositivo valida da solo).
    public func fits(byteCount: Int64) -> Bool? {
        guard let otaMaxBytes else { return nil }
        //taglia del binario ignota (il server non ce l'ha più): nessun verdetto.
        guard byteCount > 0 else { return nil }
        return byteCount <= otaMaxBytes
    }

    /// Come sopra, per una versione firmware caricata.
    public func fits(_ version: OtaFirmwareVersion) -> Bool? {
        fits(byteCount: version.size)
    }

    public init(dashId: Int, deviceId: Int, name: String? = nil, boardType: String? = nil,
                followLineageId: String? = nil, isTestBoard: Bool = false, online: Bool = false,
                currentBuild: String? = nil, ota: Update? = nil,
                connectTime: Int64? = nil, disconnectTime: Int64? = nil,
                serverNow: Int64? = nil, otaMaxBytes: Int64? = nil,
                flashBytes: Int64? = nil, sketchBytes: Int64? = nil) {
        self.dashId = dashId
        self.deviceId = deviceId
        self.name = name
        self.boardType = boardType
        self.followLineageId = followLineageId
        self.isTestBoard = isTestBoard
        self.online = online
        self.currentBuild = currentBuild
        self.ota = ota
        self.connectTime = connectTime
        self.disconnectTime = disconnectTime
        self.serverNow = serverNow
        self.otaMaxBytes = otaMaxBytes
        self.flashBytes = flashBytes
        self.sketchBytes = sketchBytes
    }

    private enum CodingKeys: String, CodingKey {
        case dashId, deviceId, name, boardType, followLineageId, isTestBoard
        case online, currentBuild, ota
        case connectTime, disconnectTime, serverNow
        case otaMaxBytes, flashBytes, sketchBytes
        //forma alternativa (campi dell'update sul livello alto)
        case targetVersionId, state, sentAt, attempts, lastReportedBuild
        case totalBytes, sentBytes, downloadStartedAt, lastByteAt
        case downloadCompletedAt, downloadFailed, lastDownloadMs
        case expectedInstallMs, expectedInstallSource, resendGraceMs
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
        self.connectTime = try c.decodeIfPresent(Int64.self, forKey: .connectTime)
        self.disconnectTime = try c.decodeIfPresent(Int64.self, forKey: .disconnectTime)
        self.serverNow = try c.decodeIfPresent(Int64.self, forKey: .serverNow)

        // Il server omette queste chiavi quando non sa: le teniamo `nil`.
        // Un negativo (jar che dovesse pubblicare il proprio "sconosciuto"
        // invece di omettere) vale sconosciuto, mai "non ci sta niente".
        func known(_ key: CodingKeys) throws -> Int64? {
            guard let value = try c.decodeIfPresent(Int64.self, forKey: key) else { return nil }
            return value >= 0 ? value : nil
        }
        self.otaMaxBytes = try known(.otaMaxBytes)
        self.flashBytes = try known(.flashBytes)
        self.sketchBytes = try known(.sketchBytes)

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
                    lastReportedBuild: try c.decodeIfPresent(String.self, forKey: .lastReportedBuild),
                    totalBytes: try c.decodeIfPresent(Int64.self, forKey: .totalBytes),
                    sentBytes: try c.decodeIfPresent(Int64.self, forKey: .sentBytes),
                    downloadStartedAt: try c.decodeIfPresent(Int64.self, forKey: .downloadStartedAt),
                    lastByteAt: try c.decodeIfPresent(Int64.self, forKey: .lastByteAt),
                    downloadCompletedAt: try c.decodeIfPresent(Int64.self,
                                                               forKey: .downloadCompletedAt),
                    downloadFailed: try c.decodeIfPresent(Bool.self, forKey: .downloadFailed),
                    lastDownloadMs: try c.decodeIfPresent(Int64.self, forKey: .lastDownloadMs),
                    expectedInstallMs: try c.decodeIfPresent(Int64.self, forKey: .expectedInstallMs),
                    expectedInstallSource: (try c.decodeIfPresent(
                        String.self, forKey: .expectedInstallSource))
                        .flatMap(InstallEstimateSource.init),
                    resendGraceMs: try c.decodeIfPresent(Int64.self, forKey: .resendGraceMs))
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
        try c.encodeIfPresent(connectTime, forKey: .connectTime)
        try c.encodeIfPresent(disconnectTime, forKey: .disconnectTime)
        try c.encodeIfPresent(serverNow, forKey: .serverNow)
        try c.encodeIfPresent(otaMaxBytes, forKey: .otaMaxBytes)
        try c.encodeIfPresent(flashBytes, forKey: .flashBytes)
        try c.encodeIfPresent(sketchBytes, forKey: .sketchBytes)
        try c.encodeIfPresent(ota, forKey: .ota)
    }
}
