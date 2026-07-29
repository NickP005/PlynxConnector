//
//  OtaUploadTicket.swift
//  PlynxConnector
//
//  Il permesso di caricare un binario: token monouso a breve scadenza mintato
//  sulla sessione TCP già autenticata (comando OTA_UPLOAD_TOKEN) e speso poi
//  sulla POST multipart HTTPS. Porta con sé i limiti del server, così l'app può
//  scartare un file troppo grande PRIMA di iniziare a spedirlo.
//

import Foundation

public struct OtaUploadTicket: Sendable, Codable, Hashable {

    /// Token monouso da mettere in query string sulla POST di upload.
    public let token: String
    /// Validità residua del token.
    public let ttlSeconds: Int
    /// Taglia massima di un singolo .bin.
    public let maxBinBytes: Int64
    /// Tetto di storage firmware dell'utente.
    public let quotaBytes: Int64
    /// Byte già occupati, quando il server li dichiara nel ticket.
    public let usedBytes: Int64?
    /// Percorso HTTP dell'upload (il server lo dichiara: niente path hardcoded).
    public let uploadPath: String

    public init(token: String, ttlSeconds: Int, maxBinBytes: Int64, quotaBytes: Int64,
                usedBytes: Int64? = nil, uploadPath: String = "/ota/upload") {
        self.token = token
        self.ttlSeconds = ttlSeconds
        self.maxBinBytes = maxBinBytes
        self.quotaBytes = quotaBytes
        self.usedBytes = usedBytes
        self.uploadPath = uploadPath
    }

    /// Un binario di questa taglia è accettabile per taglia e (se nota) quota?
    public func accepts(byteCount: Int64) -> Bool {
        guard maxBinBytes <= 0 || byteCount <= maxBinBytes else { return false }
        guard let usedBytes = usedBytes, quotaBytes > 0 else { return true }
        return usedBytes + byteCount <= quotaBytes
    }

    private enum CodingKeys: String, CodingKey {
        case token, maxBinBytes, quotaBytes, usedBytes, uploadPath
        //il jar dichiara la scadenza in minuti; teniamo buono anche il secondo
        //nome nel caso il gobackend la mandi in secondi al cutover.
        case ttlMin, ttlSec, ttlSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try c.decode(String.self, forKey: .token)
        if let minutes = try c.decodeIfPresent(Int.self, forKey: .ttlMin) {
            self.ttlSeconds = minutes * 60
        } else if let seconds = try c.decodeIfPresent(Int.self, forKey: .ttlSec) {
            self.ttlSeconds = seconds
        } else {
            self.ttlSeconds = try c.decodeIfPresent(Int.self, forKey: .ttlSeconds) ?? 0
        }
        self.maxBinBytes = try c.decodeIfPresent(Int64.self, forKey: .maxBinBytes) ?? 0
        self.quotaBytes = try c.decodeIfPresent(Int64.self, forKey: .quotaBytes) ?? 0
        self.usedBytes = try c.decodeIfPresent(Int64.self, forKey: .usedBytes)
        self.uploadPath = try c.decodeIfPresent(String.self, forKey: .uploadPath) ?? "/ota/upload"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(token, forKey: .token)
        try c.encode(ttlSeconds, forKey: .ttlSeconds)
        try c.encode(maxBinBytes, forKey: .maxBinBytes)
        try c.encode(quotaBytes, forKey: .quotaBytes)
        try c.encodeIfPresent(usedBytes, forKey: .usedBytes)
        try c.encode(uploadPath, forKey: .uploadPath)
    }
}
