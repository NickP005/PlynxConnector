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

    /// Il server sa elencare e scollegare i browser già abbinati all'editor.
    /// Senza questa cap la schermata "Modifica sul computer" può solo
    /// proporre un nuovo abbinamento: non c'è modo di sapere se una sessione
    /// è già aperta.
    public var supportsEditorSessions: Bool {
        caps.contains("editorSessions")
    }

    /// Il server ospita le immagini dei pin virtuali (cap "imageCache"):
    /// `POST /v1/img/{token}/V{pin}` deposita i byte e scrive da sé sul pin il
    /// valore `plynx-img:<ref>.<sig>`, `GET /v1/img/{ref}?t={sig}` li ridà per
    /// 5 giorni.
    ///
    /// 🔴 **Senza questa cap il widget immagine non si offre nemmeno.** Il jar
    /// legacy non avrà mai questo endpoint: un widget che aspetta per sempre un
    /// valore che nessuno scriverà è una promessa a vuoto, esattamente come il
    /// pulsante «Accedi con Apple» su un server che non sa riceverlo.
    public var supportsImageCache: Bool {
        caps.contains("imageCache")
    }

    /// Il server sa accettare un'identità Apple: l'app gli manda il token
    /// firmato che Apple restituisce, e lui crea o ritrova l'account.
    ///
    /// 🔴 **Finché questa cap non c'è, il pulsante non deve nemmeno comparire.**
    /// Non è prudenza: un «Accedi con Apple» che porta a un errore del server
    /// è peggio che non averlo — chi lo tocca ha già dato il consenso ad Apple,
    /// e si ritrova con un'identità concessa e nessun account. Il posto giusto
    /// per dire «qui non si può» è **prima** del tocco, cioè non disegnandolo.
    public var supportsAppleSignIn: Bool {
        caps.contains("appleSignIn")
    }
}
