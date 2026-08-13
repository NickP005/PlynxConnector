//
//  ImageCacheError.swift
//  PlynxConnector
//
//  Errori della lettura di un'immagine depositata sul server.
//
//  🔴 La distinzione che questo tipo esiste per fare è **scaduta ≠ rotta**.
//  Il server risponde `410 Gone` quando i 5 giorni sono finiti e `404` quando
//  quel ref non è mai esistito: sono due frasi diverse da dire all'utente
//  («l'immagine non c'è più» contro «qualcosa non ha funzionato»), e schiacciarle
//  su un errore solo vorrebbe dire mandare qualcuno a controllare la rete per
//  una foto che il server ha cancellato apposta.
//

import Foundation

public enum ImageCacheError: Error, LocalizedError, Sendable {

    /// 410 Gone: il TTL di 5 giorni è finito (la data comanda sul disco: il
    /// server risponde così anche se il file fosse ancora lì).
    case expired

    /// 403: firma sbagliata o assente. Il ref da solo non basta ed è voluto —
    /// un riferimento finito in un log non deve aprire la foto di casa di
    /// qualcuno.
    case forbidden

    /// 404: quel ref non è mai esistito su questo server.
    case notFound

    /// Il ref/la firma non compongono un URL valido, o il server non è
    /// raggiungibile a un indirizzo HTTP (BLE diretto, per esempio).
    case invalidReference

    /// Risposta HTTP inattesa (altro codice, corpo vuoto).
    case invalidResponse(status: Int)

    /// Errore di rete/TLS.
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .expired:
            return "This image has expired."
        case .forbidden:
            return "This image link is not valid for this account."
        case .notFound:
            return "Image not found."
        case .invalidReference:
            return "Malformed image reference."
        case .invalidResponse(let status):
            return "Unexpected server response (\(status))."
        case .transport(let error):
            return "Image download failed: \(error.localizedDescription)"
        }
    }

    /// Mappa il codice HTTP nel caso corrispondente.
    /// ⚠️ 410 e 404 restano separati apposta: vedi il perché in testa al file.
    static func from(status: Int) -> ImageCacheError {
        switch status {
        case 410: return .expired
        case 403: return .forbidden
        case 404: return .notFound
        default: return .invalidResponse(status: status)
        }
    }
}
