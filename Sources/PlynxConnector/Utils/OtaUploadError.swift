//
//  OtaUploadError.swift
//  PlynxConnector
//
//  Errori tipizzati dell'upload firmware. Il server risponde sempre JSON con
//  un campo `reason`: qui diventa un caso enumerato, così la UI può dire
//  esattamente cosa è andato storto (quota piena, file troppo grande, binario
//  senza marker di build, token scaduto) invece di mostrare un codice HTTP.
//

import Foundation

public enum OtaUploadError: Error, LocalizedError, Sendable {

    /// Token di upload assente, già speso o scaduto: rifarne uno.
    case invalidToken

    /// Quota di storage dell'utente esaurita.
    case quotaExceeded(usedBytes: Int64, quotaBytes: Int64)

    /// Binario più grande del massimo consentito per singolo file.
    case fileTooLarge(sizeBytes: Int64, maxBytes: Int64)

    /// Raggiunto il numero massimo di versioni conservate: cancellarne qualcuna.
    case tooManyVersions(count: Int, limit: Int)

    /// Il .bin non ha il marker di build: il server non potrebbe mai confermare
    /// l'aggiornamento, quindi lo rifiuta a monte.
    case missingBuildMarker

    /// Scheda di destinazione non riconosciuta dal server.
    case unknownDevice

    /// File vuoto/illeggibile o multipart malformato.
    case invalidFile

    /// Altro errore riportato dal server.
    case serverRejected(status: Int, reason: String?)

    /// Risposta HTTP non interpretabile.
    case invalidResponse

    /// Errore di rete/TLS.
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Upload session expired. Try again."
        case .quotaExceeded(let used, let quota):
            return "Firmware storage full (\(used) of \(quota) bytes used). Delete an old version."
        case .fileTooLarge(let size, let max):
            return "Firmware too large (\(size) bytes, max \(max))."
        case .tooManyVersions(_, let limit):
            return "Too many stored firmware versions (limit \(limit)). Delete an old one."
        case .missingBuildMarker:
            return "This binary has no Plynx build marker: it was not built with the Plynx library."
        case .unknownDevice:
            return "Board not found."
        case .invalidFile:
            return "The firmware file could not be read."
        case .serverRejected(let status, let reason):
            if let reason = reason {
                return "Upload rejected by the server (\(status): \(reason))."
            }
            return "Upload rejected by the server (\(status))."
        case .invalidResponse:
            return "Unexpected server response"
        case .transport(let error):
            return "Upload failed: \(error.localizedDescription)"
        }
    }

    /// Mappa la risposta HTTP del server nel caso corrispondente.
    /// - Parameters:
    ///   - status: codice HTTP.
    ///   - body: corpo JSON della risposta (può essere vuoto).
    static func from(status: Int, body: Data) -> OtaUploadError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let reason = json?["reason"] as? String

        func int64(_ key: String) -> Int64 {
            if let value = json?[key] as? NSNumber { return value.int64Value }
            return 0
        }
        func int(_ key: String) -> Int {
            if let value = json?[key] as? NSNumber { return value.intValue }
            return 0
        }

        switch reason {
        case "token":
            return .invalidToken
        case "quota":
            return .quotaExceeded(usedBytes: int64("usedBytes"), quotaBytes: int64("quotaBytes"))
        case "size":
            return .fileTooLarge(sizeBytes: int64("sizeBytes"), maxBytes: int64("maxBytes"))
        case "versions":
            return .tooManyVersions(count: int("count"), limit: int("limit"))
        case "build":
            return .missingBuildMarker
        case "device":
            return .unknownDevice
        case "file", "multipart":
            return .invalidFile
        default:
            return .serverRejected(status: status, reason: reason)
        }
    }
}
