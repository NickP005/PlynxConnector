//
//  PublicListingState.swift
//  PlynxConnector
//
//  Stato di listing (Slice 4) del PROPRIO progetto pubblicato: se è elencato
//  nel catalogo pubblico, con username autore e descrizione salvati sulla riga.
//  Letto owner-guarded via getProjectPublic(publishedId:) così la sheet di
//  condivisione ripristina il toggle "in catalogo" e pre-riempie la descrizione
//  invece di sovrascriverla con una vuota al re-list.
//

import Foundation

public struct PublicListingState: Sendable, Codable, Hashable {
    /// True se il progetto è attualmente elencato nel catalogo pubblico.
    public let isPublic: Bool
    /// Username pubblico denormalizzato sulla card (può mancare).
    public let authorUsername: String?
    /// Descrizione salvata sulla card (può mancare).
    public let description: String?

    public init(isPublic: Bool, authorUsername: String?, description: String?) {
        self.isPublic = isPublic
        self.authorUsername = authorUsername
        self.description = description
    }

    // Decoding difensivo: il mapper server omette i campi null/empty, e per
    // sicurezza anche isPublic assente vale "non elencato".
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        self.authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
    }
}
