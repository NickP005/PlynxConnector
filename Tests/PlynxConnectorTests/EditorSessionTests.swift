import XCTest
@testable import PlynxConnector

/// Comandi 119/120 (elenco e revoca delle sessioni dell'editor web) e forma
/// del payload che manda il server.
final class EditorSessionTests: XCTestCase {

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let testMsgId: UInt16 = 7

    // MARK: - Azioni

    func testEditorSessionsWithoutFilter() throws {
        let msg = try Action.editorSessions(dashId: nil).toMessage(messageId: testMsgId, encoder: encoder)
        XCTAssertEqual(msg.command, .editorSessions)
        XCTAssertEqual(msg.command.rawValue, 119)
        //body vuoto = tutte le sessioni dell'utente
        XCTAssertEqual(msg.body, "")
    }

    func testEditorSessionsFilteredByDash() throws {
        let msg = try Action.editorSessions(dashId: 7).toMessage(messageId: testMsgId, encoder: encoder)
        XCTAssertEqual(msg.command, .editorSessions)
        XCTAssertEqual(msg.body, "7")
    }

    func testEditorSessionRevoke() throws {
        let msg = try Action.editorSessionRevoke(sessionId: "92250a3a24ba1dafed0e65939e5ae9ad")
            .toMessage(messageId: testMsgId, encoder: encoder)
        XCTAssertEqual(msg.command, .editorSessionRevoke)
        XCTAssertEqual(msg.command.rawValue, 120)
        XCTAssertEqual(msg.body, "92250a3a24ba1dafed0e65939e5ae9ad")
    }

    func testCommandNames() {
        XCTAssertEqual(CommandCode.editorSessions.name, "EDITOR_SESSIONS")
        XCTAssertEqual(CommandCode.editorSessionRevoke.name, "EDITOR_SESSION_REVOKE")
    }

    // MARK: - Decodifica del payload

    func testDecodeSessionList() throws {
        let json = """
        {"sessions":[{"id":"92250a3a24ba1dafed0e65939e5ae9ad","dashId":7,\
        "dashName":"Serra","ip":"203.0.113.77",\
        "userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/126.0.0.0 Safari/537.36",\
        "browser":"Chrome","os":"macOS","createdAt":1785400114524,\
        "lastSeenAt":1785400115914,"expiresAt":1785443314524}]}
        """
        let list = try decoder.decode(EditorSessionList.self, from: Data(json.utf8))
        XCTAssertEqual(list.sessions.count, 1)

        let session = list.sessions[0]
        XCTAssertEqual(session.id, "92250a3a24ba1dafed0e65939e5ae9ad")
        XCTAssertEqual(session.dashId, 7)
        XCTAssertEqual(session.dashName, "Serra")
        XCTAssertEqual(session.ip, "203.0.113.77")
        XCTAssertEqual(session.browser, "Chrome")
        XCTAssertEqual(session.os, "macOS")
        XCTAssertEqual(session.createdAt, 1785400114524)
        XCTAssertEqual(session.lastSeenAt, 1785400115914)
        XCTAssertEqual(session.expiresAt, 1785443314524)
        XCTAssertEqual(session.expiresAt - session.createdAt, 43_200_000) //12h
    }

    /// Il server dichiara di mandare sempre tutti i campi, ma con `null`
    /// espliciti: non devono far fallire la riga.
    func testDecodeSessionWithNulls() throws {
        let json = """
        {"sessions":[{"id":"abc","dashId":3,"dashName":null,"ip":null,\
        "userAgent":null,"browser":null,"os":null,"createdAt":1,\
        "lastSeenAt":1,"expiresAt":2}]}
        """
        let session = try decoder.decode(EditorSessionList.self, from: Data(json.utf8)).sessions[0]
        XCTAssertNil(session.dashName)
        XCTAssertNil(session.ip)
        XCTAssertNil(session.browser)
        XCTAssertNil(session.os)
    }

    func testDecodeEmptyList() throws {
        let list = try decoder.decode(EditorSessionList.self, from: Data(#"{"sessions":[]}"#.utf8))
        XCTAssertTrue(list.sessions.isEmpty)
        //e anche una risposta senza la chiave (jar più vecchio) non deve buttare
        let missing = try decoder.decode(EditorSessionList.self, from: Data("{}".utf8))
        XCTAssertTrue(missing.sessions.isEmpty)
    }

    func testExpiryUsesServerClockStamp() {
        let past = EditorSession(id: "a", dashId: 1, expiresAt: 1_000)
        XCTAssertTrue(past.isExpired(now: Date(timeIntervalSince1970: 100)))

        let future = Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        let alive = EditorSession(id: "b", dashId: 1, expiresAt: future)
        XCTAssertFalse(alive.isExpired())

        //senza scadenza dal server non si inventa una sessione morta
        XCTAssertFalse(EditorSession(id: "c", dashId: 1).isExpired())
    }

    func testCapability() {
        XCTAssertTrue(ServerInfo(version: "0.41.22", caps: ["editorPair", "editorSessions"])
            .supportsEditorSessions)
        XCTAssertFalse(ServerInfo(version: "0.41.21", caps: ["editorPair"])
            .supportsEditorSessions)
    }
}
