//
//  OtaDeviceRef.swift
//  PlynxConnector
//
//  Come si nomina una scheda nei comandi OTA: il server la risolve dal token
//  della scheda oppure dalla coppia `dashId:deviceId` (accetta anche l'id nudo
//  quando è univoco tra i progetti, ma noi mandiamo sempre la coppia: zero
//  ambiguità e nessun segreto in giro quando basta l'id).
//

import Foundation

public enum OtaDeviceRef: Sendable, Hashable {
    /// Token di autenticazione della scheda (quello compilato nello sketch).
    case boardToken(String)
    /// Coppia progetto/scheda, la forma preferita dall'app.
    case device(dashId: Int, deviceId: Int)

    /// Rappresentazione da mettere nel body del comando / nella query di upload.
    public var wireValue: String {
        switch self {
        case .boardToken(let token):
            return token
        case .device(let dashId, let deviceId):
            return "\(dashId):\(deviceId)"
        }
    }
}
