//
//  OtaUploadResult.swift
//  PlynxConnector
//
//  Metadati restituiti dalla POST multipart del .bin: la versione appena
//  registrata (con il lineage in cui è finita), la quota aggiornata e
//  l'eventuale avviso "manca il connection manager".
//

import Foundation

public struct OtaUploadResult: Sendable, Codable, Hashable {

    /// Lineage in cui è finita la versione (creato al volo al primo upload).
    public let lineageId: String
    public let lineageName: String?
    /// Id della versione: è quello da passare a push/promote/delete.
    public let versionId: String
    /// Numero progressivo dentro il lineage.
    public let n: Int
    public let fileName: String?
    public let size: Int64
    public let sha256: String?
    public let fwVer: String?
    public let fwType: String?
    public let buildDate: String?
    /// Il binario dichiara il connection manager.
    public let cmFlag: Bool
    /// Quota consumata dopo questo upload.
    public let usedBytes: Int64
    public let quotaBytes: Int64
    /// Avviso del server: binario senza connection manager, il token compilato
    /// dentro può sovrascrivere le credenziali di una scheda già pairata.
    public let cmMissing: Bool

    public init(lineageId: String, lineageName: String?, versionId: String, n: Int,
                fileName: String?, size: Int64, sha256: String?, fwVer: String?,
                fwType: String?, buildDate: String?, cmFlag: Bool,
                usedBytes: Int64, quotaBytes: Int64, cmMissing: Bool) {
        self.lineageId = lineageId
        self.lineageName = lineageName
        self.versionId = versionId
        self.n = n
        self.fileName = fileName
        self.size = size
        self.sha256 = sha256
        self.fwVer = fwVer
        self.fwType = fwType
        self.buildDate = buildDate
        self.cmFlag = cmFlag
        self.usedBytes = usedBytes
        self.quotaBytes = quotaBytes
        self.cmMissing = cmMissing
    }

    /// La versione appena creata, nella stessa forma che poi arriva da OTA_LIST.
    public var version: OtaFirmwareVersion {
        OtaFirmwareVersion(id: versionId, lineageId: lineageId, n: n, fileName: fileName,
                           size: size, sha256: sha256, fwVer: fwVer, fwType: fwType,
                           buildDate: buildDate, cmFlag: cmFlag, uploadedAt: nil)
    }

    // Decoding difensivo: il server omette i campi null e manda `cmMissing`
    // solo quando l'avviso c'è.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lineageId = try c.decodeIfPresent(String.self, forKey: .lineageId) ?? ""
        self.lineageName = try c.decodeIfPresent(String.self, forKey: .lineageName)
        self.versionId = try c.decode(String.self, forKey: .versionId)
        self.n = try c.decodeIfPresent(Int.self, forKey: .n) ?? 1
        self.fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        self.size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        self.sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
        self.fwVer = try c.decodeIfPresent(String.self, forKey: .fwVer)
        self.fwType = try c.decodeIfPresent(String.self, forKey: .fwType)
        self.buildDate = try c.decodeIfPresent(String.self, forKey: .buildDate)
        self.cmFlag = try c.decodeIfPresent(Bool.self, forKey: .cmFlag) ?? false
        self.usedBytes = try c.decodeIfPresent(Int64.self, forKey: .usedBytes) ?? 0
        self.quotaBytes = try c.decodeIfPresent(Int64.self, forKey: .quotaBytes) ?? 0
        self.cmMissing = try c.decodeIfPresent(Bool.self, forKey: .cmMissing) ?? false
    }
}
