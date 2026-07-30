//
//  EditorSession.swift
//  PlynxConnector
//
//  Un browser già abbinato all'editor web (comando EDITOR_SESSIONS): che
//  progetto sta modificando, da che indirizzo, con che browser e da quando.
//  Serve alla schermata "Modifica sul computer" per mostrare lo stato reale
//  invece di richiedere ogni volta un codice di abbinamento.
//
//  `id` è un handle opaco: NON è il token di sessione (quello resta solo nel
//  browser abbinato e non compare mai in questa risposta). È l'unica cosa da
//  rimandare indietro per scollegare la sessione (EDITOR_SESSION_REVOKE).
//

import Foundation

public struct EditorSession: Sendable, Codable, Identifiable, Hashable {

    /// Handle opaco della sessione, da passare a `revokeEditorSession`.
    public let id: String
    /// Progetto che quel browser può aprire e modificare.
    public let dashId: Int
    /// Nome del progetto risolto dal server al momento della risposta
    /// (nil se il progetto è stato cancellato nel frattempo).
    public let dashName: String?
    /// Indirizzo IP del browser al momento dell'abbinamento (nil se ignoto).
    public let ip: String?
    /// User-agent grezzo, già troncato e ripulito dal server (nil se ignoto).
    public let userAgent: String?
    /// Etichetta del browser: "Chrome", "Safari", "Firefox", "Edge", "Opera".
    /// nil quando lo user-agent non dice niente di riconoscibile.
    public let browser: String?
    /// Etichetta del sistema: "macOS", "Windows", "Linux", "iOS", "iPadOS",
    /// "Android". nil quando lo user-agent non dice niente di riconoscibile.
    public let os: String?
    /// Epoch millis dell'abbinamento.
    public let createdAt: Int64
    /// Epoch millis dell'ultima chiamata fatta da quel browser.
    public let lastSeenAt: Int64
    /// Epoch millis di scadenza (il server usa 12h dall'abbinamento).
    public let expiresAt: Int64

    public init(id: String, dashId: Int, dashName: String? = nil, ip: String? = nil,
                userAgent: String? = nil, browser: String? = nil, os: String? = nil,
                createdAt: Int64 = 0, lastSeenAt: Int64 = 0, expiresAt: Int64 = 0) {
        self.id = id
        self.dashId = dashId
        self.dashName = dashName
        self.ip = ip
        self.userAgent = userAgent
        self.browser = browser
        self.os = os
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.expiresAt = expiresAt
    }

    // Decoding difensivo come per lo snapshot OTA: il server dichiara di non
    // omettere mai un campo, ma un rollback del jar (o il gobackend al
    // cutover) non deve far fallire tutta la lista per un campo in meno.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.dashId = try c.decodeIfPresent(Int.self, forKey: .dashId) ?? -1
        self.dashName = try c.decodeIfPresent(String.self, forKey: .dashName)
        self.ip = try c.decodeIfPresent(String.self, forKey: .ip)
        self.userAgent = try c.decodeIfPresent(String.self, forKey: .userAgent)
        self.browser = try c.decodeIfPresent(String.self, forKey: .browser)
        self.os = try c.decodeIfPresent(String.self, forKey: .os)
        self.createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        self.lastSeenAt = try c.decodeIfPresent(Int64.self, forKey: .lastSeenAt) ?? 0
        self.expiresAt = try c.decodeIfPresent(Int64.self, forKey: .expiresAt) ?? 0
    }

    // MARK: - Consultazione

    /// Momento dell'abbinamento (nil se il server non l'ha mandato).
    public var createdDate: Date? {
        createdAt > 0 ? Date(timeIntervalSince1970: Double(createdAt) / 1000) : nil
    }

    /// Ultima attività del browser (nil se il server non l'ha mandata).
    public var lastSeenDate: Date? {
        lastSeenAt > 0 ? Date(timeIntervalSince1970: Double(lastSeenAt) / 1000) : nil
    }

    public var expiresDate: Date? {
        expiresAt > 0 ? Date(timeIntervalSince1970: Double(expiresAt) / 1000) : nil
    }

    /// La sessione è scaduta secondo l'orologio del telefono. Il server la
    /// scarta da solo, ma un elenco tenuto aperto qualche ora la mostrerebbe
    /// ancora viva.
    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresDate else { return false }
        return expiresDate <= now
    }
}

/// Risposta di EDITOR_SESSIONS: `{"sessions":[…]}`.
public struct EditorSessionList: Sendable, Codable, Hashable {

    public let sessions: [EditorSession]

    public init(sessions: [EditorSession]) {
        self.sessions = sessions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sessions = try c.decodeIfPresent([EditorSession].self, forKey: .sessions) ?? []
    }
}
