//
//  ProjectRating.swift
//  PlynxConnector
//
//  Riepilogo voti stelle di un progetto del catalogo (Slice 4d). Ritornato da
//  getProjectRating(109) come testo plain "myStars\0avg\0count", non JSON.
//

import Foundation

public struct ProjectRating: Sendable, Equatable {
    /// Voto del chiamante (1..5), 0 se non ha ancora votato.
    public let myStars: Int
    /// Media dei voti (1 decimale), 0 se non ci sono voti.
    public let average: Double
    /// Numero di voti.
    public let count: Int

    public init(myStars: Int, average: Double, count: Int) {
        self.myStars = myStars
        self.average = average
        self.count = count
    }

    /// True se qualcuno ha votato (per decidere se mostrare la media).
    public var hasVotes: Bool { count > 0 }
}
