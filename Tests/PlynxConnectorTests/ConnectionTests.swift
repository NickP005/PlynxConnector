//
//  ConnectionTests.swift
//  PlynxConnectorTests
//
//  Tests per verificare la connessione al server Plynx
//

import XCTest
@testable import PlynxConnector

final class ConnectionTests: XCTestCase {
    
    // MARK: - Configuration
    
    /// Indirizzo del server da testare
    let testHost = "127.0.0.1"
    let testPort: UInt16 = 9443
    
    // MARK: - Socket Connection Tests
    
    /// Test 1: Verifica che PlynxSocket possa connettersi al server
    func testSocketConnection() async throws {
        print("\n=== TEST: Socket Connection ===")
        print("Tentativo di connessione a \(testHost):\(testPort)")
        
        let socket = PlynxSocket(host: testHost, port: testPort)
        
        do {
            try await socket.connect()
            print("✅ Socket connesso con successo!")
            
            // Verifica che sia connesso
            let isConnected = await socket.isConnected
            XCTAssertTrue(isConnected, "Il socket dovrebbe essere connesso")
            
            // Disconnetti
            await socket.disconnect()
            print("✅ Socket disconnesso")
            
        } catch {
            print("❌ Errore di connessione: \(error)")
            XCTFail("Connessione fallita: \(error)")
        }
    }
    
    /// Test 2: Verifica timeout su connessione a server inesistente
    func testSocketConnectionTimeout() async throws {
        print("\n=== TEST: Socket Connection Timeout ===")
        
        // Usa un IP che non esiste sulla rete locale
        let badHost = "192.168.1.254"
        print("Tentativo di connessione a server inesistente: \(badHost):\(testPort)")
        
        let socket = PlynxSocket(host: badHost, port: testPort)
        
        let startTime = Date()
        
        do {
            try await socket.connect()
            print("❌ Non doveva connettersi!")
            XCTFail("La connessione non dovrebbe riuscire")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Errore ricevuto dopo \(String(format: "%.2f", elapsed))s: \(error)")
            // Il timeout dovrebbe essere ~5 secondi
            XCTAssertLessThan(elapsed, 10.0, "Il timeout dovrebbe essere ragionevole")
        }
    }
    
    /// Test 3: Verifica timeout su porta chiusa
    func testSocketConnectionPortClosed() async throws {
        print("\n=== TEST: Socket Connection Port Closed ===")
        
        // Usa una porta chiusa sul localhost
        let closedPort: UInt16 = 9999
        print("Tentativo di connessione a porta chiusa: \(testHost):\(closedPort)")
        
        let socket = PlynxSocket(host: testHost, port: closedPort)
        
        let startTime = Date()
        
        do {
            try await socket.connect()
            print("❌ Non doveva connettersi!")
            XCTFail("La connessione non dovrebbe riuscire")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Errore ricevuto dopo \(String(format: "%.2f", elapsed))s: \(error)")
        }
    }
    
    // MARK: - PlynxConnector Tests
    
    /// Test 4: Verifica connessione base con PlynxConnector
    func testConnectorBasicConnection() async throws {
        print("\n=== TEST: Connector Basic Connection ===")
        print("Tentativo di connessione a \(testHost):\(testPort)")
        
        let connector = PlynxConnector(host: testHost, port: testPort)
        
        // Imposta un timeout breve
        await connector.setResponseTimeout(5.0)
        
        do {
            // Prova a fare login con credenziali fasulle per vedere se il server risponde
            try await connector.connect(
                email: "test@test.com",
                password: "wrongpassword",
                appName: "TestApp"
            )
            
            let isAuth = await connector.authenticated
            print("Autenticato: \(isAuth)")
            
            // Se arriviamo qui, il server ha risposto
            // Il login probabilmente fallirà, ma la connessione funziona
            await connector.disconnect()
            
        } catch PlynxError.authenticationFailed(let code) {
            // Questo è OK - significa che il server ha risposto
            print("✅ Server ha risposto! Login fallito con codice: \(code)")
            print("   Questo è normale per credenziali errate.")
            await connector.disconnect()
            
        } catch {
            print("❌ Errore: \(error)")
            XCTFail("Errore di connessione: \(error)")
        }
    }
    
    /// Test 5: Verifica eventi di connessione
    func testConnectorEvents() async throws {
        print("\n=== TEST: Connector Events ===")
        
        let connector = PlynxConnector(host: testHost, port: testPort)
        
        // Traccia gli eventi ricevuti
        var receivedEvents: [String] = []
        
        // Avvia un task per ascoltare gli eventi
        let eventTask = Task {
            for await event in await connector.events {
                let eventName: String
                switch event {
                case .connected:
                    eventName = "connected"
                case .disconnected:
                    eventName = "disconnected"
                case .loginSuccess:
                    eventName = "loginSuccess"
                case .loginFailed(let code):
                    eventName = "loginFailed(\(code))"
                default:
                    eventName = "other"
                }
                print("📢 Evento ricevuto: \(eventName)")
                receivedEvents.append(eventName)
            }
        }
        
        do {
            try await connector.connect(
                email: "test@test.com",
                password: "test",
                appName: "TestApp"
            )
        } catch {
            // È OK se il login fallisce
        }
        
        await connector.disconnect()
        
        // Dai tempo agli eventi di essere processati
        try? await Task.sleep(nanoseconds: 500_000_000)
        eventTask.cancel()
        
        print("Eventi ricevuti: \(receivedEvents)")
        XCTAssertTrue(receivedEvents.contains("connected") || receivedEvents.contains { $0.starts(with: "loginFailed") },
                      "Dovrebbe ricevere almeno un evento")
    }
    
    /// Test 6: Test login con credenziali specifiche (se hai credenziali valide)
    func testConnectorLoginWithValidCredentials() async throws {
        print("\n=== TEST: Login con credenziali ===")
        
        // Modifica queste credenziali con quelle del tuo server
        let email = "test@example.com"
        let password = "password123"
        
        let connector = PlynxConnector(host: testHost, port: testPort)
        
        do {
            try await connector.connect(
                email: email,
                password: password,
                appName: "PlynxTest"
            )
            
            let isAuth = await connector.authenticated
            print("✅ Login riuscito! Autenticato: \(isAuth)")
            
            // Prova a recuperare le dashboards
            // let dashboards = try await connector.send(.getDashboards)
            // print("Dashboards: \(dashboards)")
            
            await connector.disconnect()
            
        } catch PlynxError.authenticationFailed(let code) {
            print("❌ Login fallito con codice: \(code)")
            // Non fallire il test - potrebbe non avere credenziali valide
            
        } catch {
            print("❌ Errore: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test 7: Misura il tempo di connessione
    func testConnectionPerformance() async throws {
        print("\n=== TEST: Connection Performance ===")
        
        var times: [TimeInterval] = []
        
        for i in 1...3 {
            let connector = PlynxConnector(host: testHost, port: testPort)
            
            let startTime = Date()
            
            do {
                try await connector.connect(
                    email: "perf@test.com",
                    password: "test",
                    appName: "PerfTest"
                )
            } catch {
                // OK
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            times.append(elapsed)
            
            await connector.disconnect()
            
            print("Tentativo \(i): \(String(format: "%.3f", elapsed))s")
        }
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        print("Tempo medio: \(String(format: "%.3f", avgTime))s")
    }
}

// MARK: - Helper extension

extension PlynxConnector {
    func setResponseTimeout(_ timeout: TimeInterval) async {
        // Se c'è un modo per impostare il timeout
        // self.responseTimeout = timeout
    }
}
