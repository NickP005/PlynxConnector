//
//  OtaUploadClient.swift
//  PlynxConnector
//
//  POST multipart del binario firmware su /ota/upload (stesso host e porta
//  della connessione TCP: sul Pi è l'HTTPS 9443 del server app).
//
//  Il certificato del server è self-signed come per il socket: qui si accetta
//  il trust esattamente come fa PlynxSocket col suo verify block, invece di
//  affidarsi a eccezioni ATS sparse nel plist dell'app.
//

import Foundation

final class OtaUploadClient: NSObject, URLSessionDelegate, @unchecked Sendable {

    private let acceptsAnyCertificate: Bool
    private let configuration: URLSessionConfiguration

    /// La sessione trattiene il delegate (cioè self) finché non la si invalida:
    /// per questo è per-upload e `invalidate()` va sempre chiamata.
    private lazy var session = URLSession(configuration: configuration,
                                          delegate: self, delegateQueue: nil)

    /// - Parameters:
    ///   - acceptsAnyCertificate: come il socket TLS del connector, accetta il
    ///     certificato self-signed del server (ha effetto solo su https).
    ///   - timeout: un .bin da 2MB su rete domestica può metterci parecchio.
    init(acceptsAnyCertificate: Bool, timeout: TimeInterval) {
        self.acceptsAnyCertificate = acceptsAnyCertificate
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.configuration = configuration
        super.init()
    }

    func invalidate() {
        session.finishTasksAndInvalidate()
    }

    /// Carica `data` come unica parte multipart.
    /// - Returns: codice HTTP e corpo della risposta (sempre JSON dal server).
    func upload(_ data: Data, to url: URL, fileName: String,
                fieldName: String = "file") async throws -> (status: Int, body: Data) {
        let boundary = "PlynxOta-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let body = Self.multipartBody(data: data, fileName: fileName,
                                      fieldName: fieldName, boundary: boundary)
        do {
            let (responseData, response) = try await session.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse else {
                throw OtaUploadError.invalidResponse
            }
            return (http.statusCode, responseData)
        } catch let error as OtaUploadError {
            throw error
        } catch {
            throw OtaUploadError.transport(error)
        }
    }

    private static func multipartBody(data: Data, fileName: String,
                                      fieldName: String, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
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

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
