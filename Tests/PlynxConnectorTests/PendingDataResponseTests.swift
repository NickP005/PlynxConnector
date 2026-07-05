//
//  PendingDataResponseTests.swift
//  PlynxConnectorTests
//
//  Tests per il matching comando/risposta delle richieste dati:
//  - collisione msgId con push HARDWARE inoltrati dal server
//  - .response di errore che deve risolvere (fallendo) la richiesta dati
//  - decoding lossy con warning
//

import XCTest
@testable import PlynxConnector

final class PendingDataResponseTests: XCTestCase {

    /// Registra una richiesta dati pendente sul connector e ritorna il task che la attende.
    private func registerDataRequest(on connector: Connector, msgId: UInt16, expecting command: CommandCode) async throws -> Task<BlynkMessage, Error> {
        let task = Task<BlynkMessage, Error> {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BlynkMessage, Error>) in
                Task {
                    await connector.registerPendingDataResponse(msgId: msgId, expecting: command, continuation: continuation)
                }
            }
        }

        // Attende che la continuation sia registrata
        var attempts = 0
        while await connector.pendingDataResponseCount == 0 && attempts < 200 {
            try await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
        let pending = await connector.pendingDataResponseCount
        XCTAssertEqual(pending, 1, "La richiesta dati doveva essere registrata")

        return task
    }

    /// FIX 1: un push HARDWARE inoltrato con lo stesso msgId di una richiesta
    /// dati pendente NON deve essere restituito come risposta; deve cadere
    /// nel normale event path.
    func testHardwarePushCollisionDoesNotResumeDataRequest() async throws {
        let connector = Connector(host: "127.0.0.1", useSSL: false)

        let dataTask = try await registerDataRequest(on: connector, msgId: 2, expecting: .loadProfileGzipped)

        // Consumer degli eventi (AsyncStream bufferizza, nessuna race)
        let eventTask = Task<Bool, Never> {
            for await event in connector.events {
                if case .virtualPinUpdate(let dashId, _, let pin, let values) = event {
                    return dashId == 1 && pin == 5 && values == ["42"]
                }
            }
            return false
        }

        // Push hardware inoltrato dal server con msgId in collisione
        let push = BlynkMessage(command: .hardware, messageId: 2, body: "1-0\u{0}vw\u{0}5\u{0}42")
        await connector.handleMessage(.command(push))

        // La richiesta dati resta pendente
        let stillPending = await connector.pendingDataResponseCount
        XCTAssertEqual(stillPending, 1, "Il push hardware non deve consumare la richiesta dati")

        // Il push arriva come evento normale (attesa limitata)
        let deadline = Task { try? await Task.sleep(nanoseconds: 2_000_000_000); eventTask.cancel() }
        let gotEvent = await eventTask.value
        deadline.cancel()
        XCTAssertTrue(gotEvent, "Il push hardware doveva essere consegnato come virtualPinUpdate")

        // Il frame con il comando atteso risolve la richiesta
        let profileFrame = BlynkMessage(command: .loadProfileGzipped, messageId: 2, body: "", rawData: Data([0x01]))
        await connector.handleMessage(.command(profileFrame))

        let result = try await dataTask.value
        XCTAssertEqual(result.command, .loadProfileGzipped)
        let remaining = await connector.pendingDataResponseCount
        XCTAssertEqual(remaining, 0)
    }

    /// FIX 2: una .response di errore per una richiesta dati pendente deve
    /// risolverla subito con serverError(code), non lasciarla in timeout.
    func testErrorResponseFailsPendingDataRequest() async throws {
        let connector = Connector(host: "127.0.0.1", useSSL: false)

        let dataTask = try await registerDataRequest(on: connector, msgId: 7, expecting: .loadProfileGzipped)

        await connector.handleMessage(.response(BlynkResponse(messageId: 7, code: .noData)))

        do {
            _ = try await dataTask.value
            XCTFail("La richiesta dati doveva fallire con serverError")
        } catch let error as PlynxError {
            guard case .serverError(let code) = error else {
                return XCTFail("Errore inatteso: \(error)")
            }
            XCTAssertEqual(code, .noData)
        }

        let remaining = await connector.pendingDataResponseCount
        XCTAssertEqual(remaining, 0)
    }

    /// FIX 3: elementi/campi malformati vengono droppati con warning invece
    /// di far cadere dashboard o widget interi.
    func testLossyDecodeRecordsWarnings() throws {
        let json = """
        {
          "dashBoards": [
            {
              "id": 1,
              "name": "Casa",
              "tags": [ {"name": "senzaId"}, {"id": 100001, "name": "ok"} ],
              "widgets": [
                {"id": 10, "type": "BUTTON"},
                {"id": 11, "type": "TABLE", "rows": "notAnArray"},
                {"noId": true}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let warnings = DecodeWarnings()
        let decoder = JSONDecoder()
        decoder.userInfo[DecodeWarnings.userInfoKey] = warnings

        let profile = try decoder.decode(Profile.self, from: json)
        let dash = profile.dashBoards?.first

        XCTAssertEqual(profile.dashBoards?.count, 1)
        XCTAssertEqual(dash?.widgets?.count, 2, "Il widget senza id viene droppato, gli altri restano")
        XCTAssertNil(dash?.widgets?[1].rows, "Il campo rows malformato diventa nil senza droppare il widget")
        XCTAssertEqual(dash?.tags?.count, 1, "Il tag malformato viene droppato senza far cadere la dashboard")
        XCTAssertEqual(warnings.count, 3, "Un warning per tag droppato, campo rows droppato e widget droppato: \(warnings.warnings)")
    }
}
