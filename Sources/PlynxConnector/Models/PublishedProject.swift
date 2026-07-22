//
//  PublishedProject.swift
//  PlynxConnector
//
//  Un progetto pubblicato scaricato: la sua versione corrente sul server e il
//  template (dashboard senza token). La versione serve al mirror vivo: chi ha
//  scaricato ri-scarica ogni tanto e, se la versione è aumentata, aggiorna il
//  layout preservando la mappatura delle proprie schede.
//

import Foundation

public struct PublishedProject: Sendable, Codable {
    /// Versione corrente del progetto pubblicato (monotona crescente).
    public let version: Int
    /// Template: dashboard senza token né valori (ruoli scheda + widget).
    public let project: DashBoard

    public init(version: Int, project: DashBoard) {
        self.version = version
        self.project = project
    }
}
