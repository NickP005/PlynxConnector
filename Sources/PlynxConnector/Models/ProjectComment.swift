//
//  ProjectComment.swift
//  PlynxConnector
//
//  Commento (Slice 4b) su un progetto elencato nel catalogo pubblico. L'email
//  dell'autore resta privata sul server: qui arriva solo lo username pubblico
//  denormalizzato (stessa convenzione della card catalogo). `canDelete` è
//  calcolato per-chiamante dal server: true se il commento è proprio o se si
//  possiede il progetto commentato (auto-moderazione leggera).
//

import Foundation

public struct ProjectComment: Sendable, Codable, Identifiable, Hashable {
    /// ID stabile del commento (uuid server-side).
    public let commentId: String
    /// Username pubblico dell'autore (può mancare su righe malformate).
    public let authorUsername: String?
    /// Testo del commento.
    public let body: String?
    /// Epoch millis di creazione (per ordinamento/"quando").
    public let createdAt: Int64?
    /// True se il chiamante può cancellare questo commento.
    public let canDelete: Bool

    public var id: String { commentId }

    public init(commentId: String, authorUsername: String?, body: String?,
                createdAt: Int64?, canDelete: Bool) {
        self.commentId = commentId
        self.authorUsername = authorUsername
        self.body = body
        self.createdAt = createdAt
        self.canDelete = canDelete
    }

    // Decoding difensivo: il mapper server omette i null/empty; canDelete
    // assente vale false.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.commentId = try c.decode(String.self, forKey: .commentId)
        self.authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        self.body = try c.decodeIfPresent(String.self, forKey: .body)
        self.createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt)
        self.canDelete = try c.decodeIfPresent(Bool.self, forKey: .canDelete) ?? false
    }
}
