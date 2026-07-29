//
//  OtaSnapshot.swift
//  PlynxConnector
//
//  Il quadro OTA completo di un utente in una sola risposta (comando
//  OTA_LIST, payload gzippato come loadProfileGzipped): quota consumata,
//  lineage firmware, versioni caricate e stato di ogni scheda.
//
//  Un "lineage" è la linea di versioni di un firmware (v1, v2, ...): nasce al
//  primo upload per una scheda, e le altre schede possono abbonarcisi (follow)
//  per ricevere le promote.
//

import Foundation

// MARK: - Quota

/// Budget di storage firmware dell'utente e limiti di upload del server.
public struct OtaQuota: Sendable, Codable, Hashable {
    /// Byte già occupati dai binari dell'utente.
    public let usedBytes: Int64
    /// Tetto per utente (direttiva anti-abuso: 5MB di default).
    public let quotaBytes: Int64
    /// Taglia massima di un singolo .bin.
    public let maxBinBytes: Int64
    /// Numero massimo di versioni conservate per utente.
    public let maxVersions: Int

    public init(usedBytes: Int64, quotaBytes: Int64, maxBinBytes: Int64, maxVersions: Int) {
        self.usedBytes = usedBytes
        self.quotaBytes = quotaBytes
        self.maxBinBytes = maxBinBytes
        self.maxVersions = maxVersions
    }

    /// Byte ancora caricabili (mai negativo).
    public var freeBytes: Int64 { max(0, quotaBytes - usedBytes) }

    /// Frazione 0...1 di quota consumata (0 se il server non dichiara un tetto).
    public var usedFraction: Double {
        guard quotaBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(quotaBytes))
    }

    /// C'è spazio per un binario di questa taglia?
    public func fits(byteCount: Int64) -> Bool {
        byteCount <= maxBinBytes && usedBytes + byteCount <= quotaBytes
    }
}

// MARK: - Lineage

/// Linea di versioni di un firmware. Le schede la "seguono" per ricevere le
/// promote; il contatore delle versioni non torna mai indietro.
public struct OtaLineage: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let name: String?
    /// Epoch millis di creazione (primo upload della linea).
    public let createdAt: Int64?
    /// Numero che verrà assegnato alla PROSSIMA versione caricata.
    public let nextN: Int?

    public init(id: String, name: String?, createdAt: Int64?, nextN: Int? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.nextN = nextN
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt)
        self.nextN = try c.decodeIfPresent(Int.self, forKey: .nextN)
    }
}

// MARK: - Versione firmware

/// Un binario caricato: metadati letti dal .bin stesso (fwVer/buildDate/cm),
/// taglia e sha256 sempre calcolati dal server.
public struct OtaFirmwareVersion: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let lineageId: String
    /// Numero progressivo dentro il lineage (1-based).
    public let n: Int
    /// Nome del file su disco, sempre "v{n}.bin".
    public let fileName: String?
    public let size: Int64
    /// sha256 esadecimale minuscolo, verificato dalla scheda in streaming.
    public let sha256: String?
    /// Versione firmware dichiarata nello sketch (tag `blnkinf`).
    public let fwVer: String?
    public let fwType: String?
    /// Marker di build: è il campo con cui il server conferma l'aggiornamento.
    public let buildDate: String?
    /// Il binario dichiara il connection manager. Senza, il token compilato
    /// dentro può sovrascrivere le credenziali di una scheda già pairata.
    public let cmFlag: Bool
    /// Epoch millis dell'upload.
    public let uploadedAt: Int64?

    public init(id: String, lineageId: String, n: Int, fileName: String? = nil,
                size: Int64 = 0, sha256: String? = nil, fwVer: String? = nil,
                fwType: String? = nil, buildDate: String? = nil, cmFlag: Bool = false,
                uploadedAt: Int64? = nil) {
        self.id = id
        self.lineageId = lineageId
        self.n = n
        self.fileName = fileName
        self.size = size
        self.sha256 = sha256
        self.fwVer = fwVer
        self.fwType = fwType
        self.buildDate = buildDate
        self.cmFlag = cmFlag
        self.uploadedAt = uploadedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.lineageId = try c.decodeIfPresent(String.self, forKey: .lineageId) ?? ""
        self.n = try c.decodeIfPresent(Int.self, forKey: .n) ?? 1
        self.fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        self.size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        self.sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
        self.fwVer = try c.decodeIfPresent(String.self, forKey: .fwVer)
        self.fwType = try c.decodeIfPresent(String.self, forKey: .fwType)
        self.buildDate = try c.decodeIfPresent(String.self, forKey: .buildDate)
        self.cmFlag = try c.decodeIfPresent(Bool.self, forKey: .cmFlag) ?? false
        self.uploadedAt = try c.decodeIfPresent(Int64.self, forKey: .uploadedAt)
    }
}

// MARK: - Snapshot

public struct OtaSnapshot: Sendable, Codable, Hashable {

    /// Quota consumata + limiti di upload.
    public let quota: OtaQuota
    /// Linee di firmware dell'utente.
    public let lineages: [OtaLineage]
    /// Tutte le versioni caricate (di tutti i lineage).
    public let versions: [OtaFirmwareVersion]
    /// Tutte le schede (escluse quelle collegate da altri progetti).
    public let devices: [OtaDeviceStatus]

    public init(quota: OtaQuota, lineages: [OtaLineage],
                versions: [OtaFirmwareVersion], devices: [OtaDeviceStatus]) {
        self.quota = quota
        self.lineages = lineages
        self.versions = versions
        self.devices = devices
    }

    // MARK: Consultazione

    /// Versioni di un lineage, dalla più recente alla più vecchia.
    public func versions(inLineage lineageId: String) -> [OtaFirmwareVersion] {
        versions.filter { $0.lineageId == lineageId }.sorted { $0.n > $1.n }
    }

    /// Ultima versione caricata in un lineage.
    public func latestVersion(inLineage lineageId: String) -> OtaFirmwareVersion? {
        versions(inLineage: lineageId).first
    }

    public func version(id: String) -> OtaFirmwareVersion? {
        versions.first { $0.id == id }
    }

    public func lineage(id: String) -> OtaLineage? {
        lineages.first { $0.id == id }
    }

    /// Schede abbonate a un lineage (quelle che una promote aggiornerebbe).
    public func devices(following lineageId: String) -> [OtaDeviceStatus] {
        devices.filter { $0.followLineageId == lineageId }
    }

    public func device(dashId: Int, deviceId: Int) -> OtaDeviceStatus? {
        devices.first { $0.dashId == dashId && $0.deviceId == deviceId }
    }

    private enum CodingKeys: String, CodingKey {
        case lineages, versions, devices
        //la quota arriva appiattita sulla radice…
        case usedBytes, quotaBytes, maxBinBytes, maxVersions
        //…ma tolleriamo anche la forma annidata.
        case quota
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lineages = try c.decodeIfPresent([OtaLineage].self, forKey: .lineages) ?? []
        self.versions = try c.decodeIfPresent([OtaFirmwareVersion].self, forKey: .versions) ?? []
        self.devices = try c.decodeIfPresent([OtaDeviceStatus].self, forKey: .devices) ?? []

        if let nested = try c.decodeIfPresent(OtaQuota.self, forKey: .quota) {
            self.quota = nested
        } else {
            self.quota = OtaQuota(
                usedBytes: try c.decodeIfPresent(Int64.self, forKey: .usedBytes) ?? 0,
                quotaBytes: try c.decodeIfPresent(Int64.self, forKey: .quotaBytes) ?? 0,
                maxBinBytes: try c.decodeIfPresent(Int64.self, forKey: .maxBinBytes) ?? 0,
                maxVersions: try c.decodeIfPresent(Int.self, forKey: .maxVersions) ?? 0)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lineages, forKey: .lineages)
        try c.encode(versions, forKey: .versions)
        try c.encode(devices, forKey: .devices)
        try c.encode(quota.usedBytes, forKey: .usedBytes)
        try c.encode(quota.quotaBytes, forKey: .quotaBytes)
        try c.encode(quota.maxBinBytes, forKey: .maxBinBytes)
        try c.encode(quota.maxVersions, forKey: .maxVersions)
    }
}

// MARK: - Esiti dei comandi di consegna

/// Esito di un push su una singola scheda: la scheda online riceve subito il
/// frame di trigger (`sent`), quella offline lo riceve al prossimo reconnect.
public struct OtaPushResult: Sendable, Codable, Hashable {
    public let state: OtaDeviceStatus.State

    public init(state: OtaDeviceStatus.State) {
        self.state = state
    }

    /// Il frame è già partito verso la scheda.
    public var isSent: Bool { state == .sent }
}

/// Esito di una promote: quante schede seguono il lineage, quante hanno già
/// ricevuto il trigger e quante lo riceveranno riconnettendosi.
public struct OtaPromoteResult: Sendable, Codable, Hashable {
    public let total: Int
    public let sent: Int
    public let pending: Int

    public init(total: Int, sent: Int, pending: Int) {
        self.total = total
        self.sent = sent
        self.pending = pending
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        self.sent = try c.decodeIfPresent(Int.self, forKey: .sent) ?? 0
        self.pending = try c.decodeIfPresent(Int.self, forKey: .pending) ?? 0
    }
}
