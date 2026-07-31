import XCTest
@testable import PlynxConnector

/// Le capacità di flash della scheda (`otaMaxBytes`/`flashBytes`/`sketchBytes`)
/// sono additive e OPZIONALI: il server le manda solo quando la scheda le ha
/// riportate davvero. Chiave assente = sconosciuto, e sconosciuto non blocca
/// niente — mai un divieto costruito su un numero che nessuno ha misurato.
final class OtaFlashCapabilityTests: XCTestCase {

    private let decoder = JSONDecoder()

    private func version(size: Int64) -> OtaFirmwareVersion {
        OtaFirmwareVersion(id: "v-1", lineageId: "l-1", n: 1, size: size)
    }

    // MARK: Decodifica

    /// Jar senza la feature: nessuna delle tre chiavi, e nessun verdetto.
    func testOldServerLeavesCapabilitiesUnknown() throws {
        let json = """
        {"dashId":1,"deviceId":0,"name":"Serra","online":true,"currentBuild":"Jul 25 2026"}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))

        XCTAssertNil(board.otaMaxBytes)
        XCTAssertNil(board.flashBytes)
        XCTAssertNil(board.sketchBytes)
        XCTAssertFalse(board.hasFlashCapabilities)
        XCTAssertNil(board.fits(version(size: 999_999_999)))
    }

    /// ESP32 con partizione OTA: i tre numeri arrivano come li ha riportati la
    /// scheda, senza rimaneggiamenti.
    func testCapabilitiesDecodeAsReported() throws {
        let json = """
        {"dashId":1,"deviceId":0,"name":"Serra","online":true,
         "otaMaxBytes":1310720,"flashBytes":4194304,"sketchBytes":912736}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))

        XCTAssertEqual(board.otaMaxBytes, 1_310_720)
        XCTAssertEqual(board.flashBytes, 4_194_304)
        XCTAssertEqual(board.sketchBytes, 912_736)
        XCTAssertTrue(board.hasFlashCapabilities)
    }

    /// `0` è un fatto, non un'assenza: la scheda dichiara di non poter fare OTA.
    func testZeroMeansCannotUpdateOverTheAir() throws {
        let json = """
        {"dashId":1,"deviceId":0,"otaMaxBytes":0,"flashBytes":1048576,"sketchBytes":389120}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))

        XCTAssertEqual(board.otaMaxBytes, 0)
        XCTAssertTrue(board.hasFlashCapabilities)
        XCTAssertEqual(board.fits(version(size: 1)), false)
    }

    /// Un negativo non deve mai diventare "non ci sta niente": vale sconosciuto,
    /// esattamente come l'assenza (il jar attuale omette, ma il modello non si
    /// fida di quello che gli manda un jar futuro o il gobackend al cutover).
    func testNegativeIsTreatedAsUnknown() throws {
        let json = """
        {"dashId":1,"deviceId":0,"otaMaxBytes":-1,"flashBytes":-1,"sketchBytes":-1}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))

        XCTAssertNil(board.otaMaxBytes)
        XCTAssertNil(board.flashBytes)
        XCTAssertNil(board.sketchBytes)
        XCTAssertNil(board.fits(version(size: 100)))
    }

    /// I campi nuovi convivono con l'update annidato senza rubargli niente.
    func testCapabilitiesCoexistWithNestedUpdate() throws {
        let json = """
        {"dashId":1,"deviceId":0,"online":true,"otaMaxBytes":1310720,
         "ota":{"targetVersionId":"v-1","state":"SENT","sentAt":1000,"attempts":1,
                "totalBytes":400000,"sentBytes":100000}}
        """
        let board = try decoder.decode(OtaDeviceStatus.self, from: Data(json.utf8))

        XCTAssertEqual(board.otaMaxBytes, 1_310_720)
        XCTAssertEqual(board.state, .sent)
        XCTAssertEqual(board.ota?.downloadFraction, 0.25)
    }

    /// Round-trip: quello che si ricodifica si rilegge uguale, e lo sconosciuto
    /// resta assente invece di diventare uno zero.
    func testRoundTripKeepsUnknownAbsent() throws {
        let board = OtaDeviceStatus(dashId: 1, deviceId: 0, otaMaxBytes: 1_310_720)
        let data = try JSONEncoder().encode(board)
        let back = try decoder.decode(OtaDeviceStatus.self, from: data)

        XCTAssertEqual(back.otaMaxBytes, 1_310_720)
        XCTAssertNil(back.flashBytes)
        XCTAssertNil(back.sketchBytes)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("flashBytes"))
    }

    // MARK: Verdetto

    /// Nessun margine: il byte esatto è il byte esatto, come nel controllo che
    /// la scheda fa da sola.
    func testFitIsStrictWithoutMargin() {
        let board = OtaDeviceStatus(dashId: 1, deviceId: 0, otaMaxBytes: 1_000_000)

        XCTAssertEqual(board.fits(version(size: 999_999)), true)
        XCTAssertEqual(board.fits(version(size: 1_000_000)), true)
        XCTAssertEqual(board.fits(version(size: 1_000_001)), false)
    }

    /// Taglia del binario ignota (il server non ce l'ha più): niente verdetto,
    /// né a favore né contro.
    func testUnknownBinarySizeGivesNoVerdict() {
        let board = OtaDeviceStatus(dashId: 1, deviceId: 0, otaMaxBytes: 1_000_000)
        XCTAssertNil(board.fits(version(size: 0)))
    }

    // MARK: Esito della promote

    /// `skipped` è additivo: un jar più vecchio non lo manda e vale 0, così il
    /// riepilogo non parla di schede saltate che non esistono.
    func testPromoteResultSkippedDefaultsToZero() throws {
        let old = try decoder.decode(OtaPromoteResult.self,
                                     from: Data(#"{"total":3,"sent":2,"pending":1}"#.utf8))
        XCTAssertEqual(old.skipped, 0)
        XCTAssertEqual(old.total, 3)

        let new = try decoder.decode(
            OtaPromoteResult.self,
            from: Data(#"{"total":6,"sent":2,"pending":2,"skipped":2}"#.utf8))
        XCTAssertEqual(new.skipped, 2)
        //il totale continua a contare TUTTI i follower.
        XCTAssertEqual(new.sent + new.pending + new.skipped, new.total)
    }
}
