//
//  PublicCatalogEntry.swift
//  PlynxConnector
//
//  Card leggera del catalogo pubblico (Slice 4): il riassunto di un progetto
//  pubblicato ed elencato pubblicamente. NON porta il template completo della
//  dashboard — quello si scarica pigramente per `publishedId` con
//  `getPublishedProject(publishedId:)` solo quando si apre/importa la card.
//

import Foundation

public struct PublicCatalogEntry: Sendable, Codable, Identifiable, Hashable {
    /// ID pubblico stabile del progetto (chiave per scaricare/importare).
    public let publishedId: String
    /// Nome del progetto (può mancare se il creatore non lo aveva impostato).
    public let name: String?
    /// Username pubblico dell'autore, mostrato sulla card.
    public let authorUsername: String?
    /// Descrizione breve opzionale scritta dall'autore.
    public let description: String?
    /// Versione corrente del progetto pubblicato.
    public let version: Int
    /// Epoch millis dell'ultima pubblicazione (per ordinamento/"aggiornato").
    public let updatedAt: Int64?

    public var id: String { publishedId }

    public init(publishedId: String, name: String?, authorUsername: String?,
                description: String?, version: Int, updatedAt: Int64?) {
        self.publishedId = publishedId
        self.name = name
        self.authorUsername = authorUsername
        self.description = description
        self.version = version
        self.updatedAt = updatedAt
    }

    // Decoding difensivo: il server omette i campi null/empty (NON_NULL/NON_EMPTY),
    // quindi tutto tranne publishedId può mancare; version defaulta a 1.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.publishedId = try c.decode(String.self, forKey: .publishedId)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt)
    }
}
