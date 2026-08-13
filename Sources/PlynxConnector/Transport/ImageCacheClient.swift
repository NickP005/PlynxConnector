//
//  ImageCacheClient.swift
//  PlynxConnector
//
//  GET dei byte di un'immagine depositata sul server, sullo stesso host/porta
//  della connessione TCP (sul Pi: l'HTTPS 9443 del server app), esattamente
//  come fa `OtaUploadClient` per il firmware.
//
//  Non è la stessa classe per una ragione di sostanza, non di stile: l'upload
//  gira con `.reloadIgnoringLocalAndRemoteCacheData` perché carica, e la cache
//  di un'immagine qui **non serve** — la tiene l'app su disco per `ref`, e il
//  contenuto di un ref non cambia mai. Una URLCache in mezzo aggiungerebbe una
//  seconda copia degli stessi byte, con una scadenza sua che non c'entra con
//  i 5 giorni del server.
//
//  Il certificato self-signed si accetta come nel socket TLS, invece di
//  sparpagliare eccezioni ATS nel plist dell'app.
//

import Foundation

final class ImageCacheClient: NSObject, URLSessionDelegate, @unchecked Sendable {

    private let acceptsAnyCertificate: Bool
    private let configuration: URLSessionConfiguration

    /// La sessione trattiene il delegate (cioè self) finché non la si invalida:
    /// per questo è per-download e `invalidate()` va sempre chiamata.
    private lazy var session = URLSession(configuration: configuration,
                                          delegate: self, delegateQueue: nil)

    init(acceptsAnyCertificate: Bool, timeout: TimeInterval) {
        self.acceptsAnyCertificate = acceptsAnyCertificate
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.configuration = configuration
        super.init()
    }

    func invalidate() {
        session.finishTasksAndInvalidate()
    }

    /// - Returns: codice HTTP e corpo. Il corpo si legge **anche** quando il
    ///   codice non è 200: chi chiama decide, e un 410 con corpo vuoto resta
    ///   un 410 (non un errore di trasporto).
    func get(_ url: URL) async throws -> (status: Int, body: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ImageCacheError.invalidResponse(status: 0)
            }
            return (http.statusCode, data)
        } catch let error as ImageCacheError {
            throw error
        } catch {
            throw ImageCacheError.transport(error)
        }
    }

    // MARK: - URLSessionDelegate

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard acceptsAnyCertificate,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
