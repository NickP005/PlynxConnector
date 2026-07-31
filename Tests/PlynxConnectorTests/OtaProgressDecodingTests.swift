import XCTest
@testable import PlynxConnector

/// Il progresso del download è additivo: un server più vecchio non manda
/// niente e chi legge deve trovarci `nil`, non uno zero che sembra una misura.
final class OtaProgressDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    /// Risposta di un jar senza la feature: si decodifica come prima, e tutti i
    /// campi di progresso restano assenti.
    func testOldServerLeavesProgressAbsent() throws {
        let json = """
        {"dashId":1,"deviceId":0,"name":"Serra","online":true,"currentBuild":"Jul 25 2026",
         "ota":{"targetVersionId":"v-1","state":"SENT","sentAt":1000,"attempts":1,
                "lastReportedBuild":null}}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))
        let ota = try XCTUnwrap(board.ota)

        XCTAssertEqual(ota.state, .sent)
        XCTAssertFalse(ota.hasProgressData)
        XCTAssertNil(ota.totalBytes)
        XCTAssertNil(ota.sentBytes)
        XCTAssertNil(ota.downloadFraction)
        XCTAssertFalse(ota.downloadStarted)
        XCTAssertFalse(ota.downloadCompleted)
        XCTAssertNil(ota.expectedInstallSource)
        XCTAssertNil(board.serverNow)
        XCTAssertNil(board.connectTime)
    }

    /// Jar recente, download a metà.
    func testProgressFieldsDecodeAndFractionIsMeasured() throws {
        let json = """
        {"dashId":1,"deviceId":0,"name":"Serra","online":false,"connectTime":900,
         "disconnectTime":1200,"serverNow":5000,
         "ota":{"targetVersionId":"v-1","state":"SENT","sentAt":1000,"attempts":1,
                "lastReportedBuild":null,"totalBytes":400000,"sentBytes":100000,
                "downloadStartedAt":1200,"lastByteAt":4800,"downloadCompletedAt":0,
                "downloadFailed":false,"lastDownloadMs":0,"expectedInstallMs":11000,
                "expectedInstallSource":"estimated","resendGraceMs":180000}}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))
        let ota = try XCTUnwrap(board.ota)

        XCTAssertTrue(ota.hasProgressData)
        XCTAssertEqual(ota.totalBytes, 400_000)
        XCTAssertEqual(ota.sentBytes, 100_000)
        XCTAssertEqual(ota.downloadFraction, 0.25)
        XCTAssertTrue(ota.downloadStarted)
        XCTAssertFalse(ota.downloadCompleted)
        XCTAssertEqual(ota.expectedInstallMs, 11000)
        XCTAssertEqual(ota.expectedInstallSource, .estimated)
        XCTAssertEqual(ota.resendGraceMs, 180_000)
        XCTAssertEqual(board.serverNow, 5000)
        XCTAssertEqual(board.disconnectTime, 1200)
    }

    /// Taglia sconosciuta (versione cancellata dal server): nessuna frazione
    /// inventata, e il download resta comunque riconoscibile come partito.
    func testUnknownSizeGivesNoFraction() throws {
        let json = """
        {"dashId":1,"deviceId":0,
         "ota":{"targetVersionId":"v-1","state":"SENT","totalBytes":0,"sentBytes":0,
                "downloadStartedAt":1200,"lastByteAt":1200}}
        """
        let ota = try XCTUnwrap(
            try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8)).ota)
        XCTAssertNil(ota.downloadFraction)
        XCTAssertTrue(ota.hasProgressData)
        XCTAssertTrue(ota.downloadStarted)
    }

    /// Il server è avanti rispetto alla scheda: la frazione non supera mai 1.
    func testFractionIsClamped() throws {
        let json = """
        {"dashId":1,"deviceId":0,
         "ota":{"targetVersionId":"v-1","state":"SENT","totalBytes":100,"sentBytes":140}}
        """
        let ota = try XCTUnwrap(
            try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8)).ota)
        XCTAssertEqual(ota.downloadFraction, 1)
    }

    /// Una sorgente di stima che oggi non conosciamo non deve far fallire tutto
    /// lo snapshot: vale come "non dichiarata".
    func testUnknownEstimateSourceDegradesToNil() throws {
        let json = """
        {"dashId":1,"deviceId":0,
         "ota":{"targetVersionId":"v-1","state":"SENT","expectedInstallMs":9000,
                "expectedInstallSource":"telepathy"}}
        """
        let ota = try XCTUnwrap(
            try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8)).ota)
        XCTAssertEqual(ota.expectedInstallMs, 9000)
        XCTAssertNil(ota.expectedInstallSource)
    }

    /// Forma appiattita (l'update sul livello alto): il progresso si ricostruisce
    /// lo stesso invece di sparire in silenzio.
    func testFlattenedFormKeepsProgress() throws {
        let json = """
        {"dashId":2,"deviceId":3,"state":"SENT","targetVersionId":"v-9",
         "totalBytes":2048,"sentBytes":1024,"downloadStartedAt":10,"lastByteAt":20,
         "downloadCompletedAt":0,"downloadFailed":false,"lastDownloadMs":4321,
         "expectedInstallMs":14000,"expectedInstallSource":"measured","resendGraceMs":180000}
        """
        let ota = try XCTUnwrap(
            try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8)).ota)
        XCTAssertEqual(ota.downloadFraction, 0.5)
        XCTAssertEqual(ota.lastDownloadMs, 4321)
        XCTAssertEqual(ota.expectedInstallSource, .measured)
    }

    /// Round-trip: quello che scriviamo si rilegge identico (forma canonica
    /// annidata, come la manda il server).
    func testRoundTripKeepsProgress() throws {
        let board = OtaDeviceStatus(
            dashId: 1, deviceId: 0, name: "Serra", online: true,
            ota: .init(targetVersionId: "v-1", state: .sent, sentAt: 1000, attempts: 1,
                       lastReportedBuild: nil, totalBytes: 400_000, sentBytes: 400_000,
                       downloadStartedAt: 1200, lastByteAt: 4800, downloadCompletedAt: 4900,
                       downloadFailed: false, lastDownloadMs: 3700, expectedInstallMs: 12000,
                       expectedInstallSource: .measured, resendGraceMs: 180_000),
            connectTime: 900, disconnectTime: 1200, serverNow: 5000)

        let data = try JSONEncoder().encode(board)
        let decoded = try decoder.decode(OtaDeviceStatus.self, from: data)

        XCTAssertEqual(decoded, board)
        XCTAssertTrue(try XCTUnwrap(decoded.ota).downloadCompleted)
        XCTAssertEqual(try XCTUnwrap(decoded.ota).downloadFraction, 1)
    }
}
