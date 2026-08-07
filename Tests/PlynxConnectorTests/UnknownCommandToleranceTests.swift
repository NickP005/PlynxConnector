import XCTest
@testable import PlynxConnector

/// Il parser deve tollerare un server piu' nuovo dell'app.
///
/// Prima di questi test un comando sconosciuto fermava `parseAll()`: il frame
/// veniva tolto dal buffer (quindi niente corruzione) ma il ciclo si
/// interrompeva, e tutto cio' che era arrivato DOPO nella stessa lettura TCP
/// restava in canna finche' non arrivavano altri byte. Se non ne arrivavano,
/// restava li'.
///
/// Conta perche' e' la condizione che permette al server di aggiungere comandi
/// senza rompere le app gia' sull'App Store — compreso il comando che un
/// domani portera' il consenso legale (R05).
final class UnknownCommandToleranceTests: XCTestCase {

    private let headerSize = 7

    /// Un frame del protocollo mobile: 1 byte comando, 2 id, 4 lunghezza corpo.
    private func frame(command: UInt8, messageId: UInt16, body: String) -> Data {
        var data = Data()
        data.append(command)
        data.append(UInt8(messageId >> 8))
        data.append(UInt8(messageId & 0xFF))
        let corpo = Data(body.utf8)
        let n = UInt32(corpo.count)
        data.append(UInt8((n >> 24) & 0xFF))
        data.append(UInt8((n >> 16) & 0xFF))
        data.append(UInt8((n >> 8) & 0xFF))
        data.append(UInt8(n & 0xFF))
        data.append(corpo)
        return data
    }

    /// Una risposta: comando 0, e i 4 byte finali sono il codice, non la lunghezza.
    private func response(messageId: UInt16, code: UInt32) -> Data {
        var data = Data()
        data.append(CommandCode.response.rawValue)
        data.append(UInt8(messageId >> 8))
        data.append(UInt8(messageId & 0xFF))
        data.append(UInt8((code >> 24) & 0xFF))
        data.append(UInt8((code >> 16) & 0xFF))
        data.append(UInt8((code >> 8) & 0xFF))
        data.append(UInt8(code & 0xFF))
        return data
    }

    /// Un codice comando che nessuna `CommandCode` usa: e' il comando che il
    /// server di domani potrebbe mandare a un'app di oggi.
    ///
    /// Si cerca il primo libero invece di cablarne uno, cosi' il giorno in cui
    /// quel numero viene davvero assegnato il test non diventa una bugia
    /// silenziosa: continua a provare cio' che dice di provare.
    private var codiceSconosciuto: UInt8 {
        for candidato in (UInt8(200)...UInt8(254)).reversed()
        where CommandCode(rawValue: candidato) == nil {
            return candidato
        }
        XCTFail("nessun codice libero per la prova")
        return 254
    }

    // MARK: - Il difetto che questi test esistono per impedire

    func testUnComandoSconosciutoNonFermaLaConsegnaDiQuelliDopo() throws {
        let parser = MessageParser()
        var pacchetto = Data()
        pacchetto.append(frame(command: codiceSconosciuto, messageId: 1, body: "roba futura"))
        pacchetto.append(response(messageId: 2, code: 200))   // l'ok di login
        parser.append(pacchetto)

        let messaggi = parser.parseAll()

        XCTAssertEqual(messaggi.count, 1,
                       "il frame sconosciuto si salta, ma quello che lo segue va consegnato")
        guard case .response(let risposta) = messaggi[0] else {
            return XCTFail("atteso l'ok di login dopo il comando sconosciuto, arrivato \(messaggi[0])")
        }
        XCTAssertEqual(risposta.messageId, 2)
    }

    func testUnComandoSconosciutoInMezzoNonMangiaNiente() throws {
        let parser = MessageParser()
        var pacchetto = Data()
        pacchetto.append(response(messageId: 1, code: 200))
        pacchetto.append(frame(command: codiceSconosciuto, messageId: 2, body: "x"))
        pacchetto.append(response(messageId: 3, code: 200))
        parser.append(pacchetto)

        let ids = parser.parseAll().map(\.messageId)
        XCTAssertEqual(ids, [1, 3], "si perde solo il frame sconosciuto, non i suoi vicini")
    }

    func testPiuComandiSconosciutiDiFilaNonBloccano() throws {
        let parser = MessageParser()
        var pacchetto = Data()
        for i in 0..<5 {
            pacchetto.append(frame(command: codiceSconosciuto, messageId: UInt16(100 + i), body: "y"))
        }
        pacchetto.append(response(messageId: 9, code: 200))
        parser.append(pacchetto)

        XCTAssertEqual(parser.parseAll().map(\.messageId), [9])
    }

    // MARK: - Che non abbia rotto il comportamento normale

    func testUnMessaggioIncompletoSiAspettaAncora() throws {
        let parser = MessageParser()
        let intero = frame(command: CommandCode.hardware.rawValue, messageId: 1, body: "vw\01\0100")
        parser.append(intero.prefix(intero.count - 3))   // arriva a meta'

        XCTAssertTrue(parser.parseAll().isEmpty, "un messaggio a meta' non si butta: si aspetta")

        parser.append(intero.suffix(3))
        let messaggi = parser.parseAll()
        XCTAssertEqual(messaggi.count, 1, "completato il messaggio, arriva")
        XCTAssertEqual(messaggi[0].messageId, 1)
    }

    func testUnaSequenzaTuttaValidaArrivaTutta() throws {
        let parser = MessageParser()
        var pacchetto = Data()
        pacchetto.append(response(messageId: 1, code: 200))
        pacchetto.append(frame(command: CommandCode.hardware.rawValue, messageId: 2, body: "vw\01\01"))
        pacchetto.append(response(messageId: 3, code: 200))
        parser.append(pacchetto)

        XCTAssertEqual(parser.parseAll().map(\.messageId), [1, 2, 3])
    }

    func testIlBufferSiSvuotaSempreEIlCicloTermina() throws {
        // La garanzia di terminazione: ogni ramo che salta consuma almeno
        // un'intestazione, quindi il buffer si accorcia sempre.
        let parser = MessageParser()
        parser.append(frame(command: codiceSconosciuto, messageId: 1, body: "z"))
        _ = parser.parseAll()
        parser.append(response(messageId: 2, code: 200))
        XCTAssertEqual(parser.parseAll().map(\.messageId), [2],
                       "niente e' rimasto nel buffer a sporcare la lettura successiva")
    }
}
