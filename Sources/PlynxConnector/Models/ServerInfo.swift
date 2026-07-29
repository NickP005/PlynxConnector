//
//  ServerInfo.swift
//  PlynxConnector
//
//  Risposta del capability handshake (GET_SERVER_INFO): versione del
//  server e lista delle feature opzionali supportate. I server legacy
//  non rispondono affatto a questo comando: l'app interpreta il timeout
//  come "server legacy" e degrada con garbo.
//

import Foundation

public struct ServerInfo: Sendable, Codable, Equatable {

    /// Versione del server (es. "0.41.19").
    public let version: String

    /// Feature opzionali dichiarate dal server. Ignora quelle sconosciute.
    public let caps: [String]

    public init(version: String, caps: [String]) {
        self.version = version
        self.caps = caps
    }

    /// Il server supporta le schede collegabili a più progetti.
    public var supportsLinkedDevices: Bool {
        caps.contains("linkedDevices")
    }

    /// Il server supporta l'export/import di progetti via codice di clonazione.
    public var supportsProjectClone: Bool {
        caps.contains("projectClone")
    }

    /// Il server supporta i progetti pubblicati persistenti (ID stabile +
    /// versione): pubblicazione, download read-only e mirror vivo.
    public var supportsPublishedProjects: Bool {
        caps.contains("publishedProjects")
    }

    /// Il server supporta il catalogo pubblico (Slice 4): elencare un proprio
    /// progetto pubblicato e sfogliare/cercare quelli altrui.
    public var supportsPublicCatalog: Bool {
        caps.contains("publicCatalog")
    }

    /// Il server supporta l'OTA utente: registro firmware, upload del .bin,
    /// push su una scheda, promote sul lineage. Senza questa cap la UI OTA
    /// non deve nemmeno comparire (server vecchio).
    public var supportsOta: Bool {
        caps.contains("ota")
    }

    /// Il server supporta il pairing dell'editor web (codice mostrato dal
    /// browser e rivendicato dall'app).
    public var supportsEditorPair: Bool {
        caps.contains("editorPair")
    }
}
