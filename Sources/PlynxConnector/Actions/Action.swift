import Foundation

public enum Action: Sendable {

    // MARK: - Authentication

    case register(email: String, password: String, appName: String)
    case login(email: String, password: String, appName: String)
    case shareLogin(token: String)
    case logout(uid: String?)
    case resetPasswordStart(email: String, appName: String)
    case resetPasswordVerify(token: String)
    case resetPasswordComplete(token: String, email: String, newPassword: String, appName: String)
    case getServer(email: String)

    // MARK: - Dashboard Management

    case createDashboard(dashboard: DashBoard, generateToken: Bool)
    case updateDashboard(dashboard: DashBoard)
    case deleteDashboard(dashId: Int)
    case activateDashboard(dashId: Int)
    case deactivateDashboard(dashId: Int?)
    case updateDashboardSettings(dashId: Int, settings: DashBoard)
    case loadProfile(dashId: Int?, published: Bool)

    // MARK: - Widget Management

    case createWidget(dashId: Int, widget: Widget, tileId: Int?)
    case updateWidget(dashId: Int, widget: Widget)
    case deleteWidget(dashId: Int, widgetId: Int)
    case getWidget(dashId: Int, widgetId: Int)
    case setWidgetProperty(dashId: Int, deviceId: Int, pin: Int, property: WidgetProperty, value: String)

    // MARK: - Device Management

    case createDevice(dashId: Int, device: Device)
    case updateDevice(dashId: Int, device: Device)
    case deleteDevice(dashId: Int, deviceId: Int)
    case getDevices(dashId: Int)
    case getDevice(dashId: Int, deviceId: Int)
    case deleteDeviceData(dashId: Int, deviceId: Int, pins: [PinInfo]?)

    /// Plynx linked devices: collega nel progetto target una scheda di un
    /// altro progetto (alias senza token); scollega un alias dal progetto.
    case linkDevice(targetDashId: Int, ownerDashId: Int, ownerDeviceId: Int)
    case unlinkDevice(dashId: Int, deviceId: Int)

    // MARK: - Tag Management

    case createTag(dashId: Int, tag: Tag)
    case updateTag(dashId: Int, tag: Tag)
    case deleteTag(dashId: Int, tagId: Int)
    case getTags(dashId: Int)

    // MARK: - Tile Template Management

    case createTileTemplate(dashId: Int, widgetId: Int, template: TileTemplate)
    case updateTileTemplate(dashId: Int, widgetId: Int, template: TileTemplate)
    case deleteTileTemplate(dashId: Int, widgetId: Int, templateId: Int)

    // MARK: - Token Management

    case refreshToken(dashId: Int, deviceId: Int?)
    case assignToken(dashId: Int, deviceId: Int, token: String)
    case getProvisionToken(dashId: Int, deviceId: Int)

    // MARK: - Hardware Communication

    case hardware(dashId: Int, deviceId: Int, body: String)
    case writeVirtualPin(dashId: Int, deviceId: Int, pin: Int, value: String)
    case readVirtualPin(dashId: Int, deviceId: Int, pin: Int)
    case hardwareSync(dashId: Int, target: String?)
    case appSync(dashId: Int, widgetIds: [Int]?)
    case resendFromBluetooth(dashId: Int, deviceId: Int, body: String)

    // MARK: - Sharing

    case setSharing(dashId: Int, enabled: Bool)
    case getShareToken(dashId: Int)
    case refreshShareToken(dashId: Int)

    // MARK: - Graph & Data

    case getEnhancedGraphData(dashId: Int, widgetId: Int, targetId: Int?, period: GraphPeriod, page: Int?)
    case deleteEnhancedGraphData(dashId: Int, widgetId: Int, dataStreamIds: [Int]?)
    case exportGraphData(dashId: Int, widgetId: Int, pinType: PinType, pin: Int, deviceId: Int)

    // MARK: - Reports

    case createReport(dashId: Int, widgetId: Int, report: Report)
    case updateReport(dashId: Int, widgetId: Int, report: Report)
    case deleteReport(dashId: Int, widgetId: Int, reportId: Int)
    case exportReport(dashId: Int, widgetId: Int, reportId: Int)

    // MARK: - Email

    case emailToken(dashId: Int, deviceId: Int?)
    case email(dashId: Int, deviceId: Int, to: String?, subject: String?, body: String?)
    case emailQR(dashId: Int, widgetId: Int)

    // MARK: - Push Notifications

    case addPushToken(dashId: Int, uid: String, token: String)

    // MARK: - App Management

    case createApp(app: App)
    case updateApp(app: App)
    case deleteApp(appId: Int)
    case updateFace(appId: Int, dashJson: String)

    // MARK: - Clone & Project

    case getCloneCode(dashId: Int)
    case getProjectByCloneCode(code: String, create: Bool)
    case getProjectByToken(token: String)
    /// Pubblica un progetto come entità persistente (ID stabile + versione).
    case publishProject(dashId: Int)
    /// Scarica un progetto pubblicato dato il suo ID pubblico stabile.
    case getPublishedProject(publishedId: String)
    /// Elenca/rimuove un proprio progetto pubblicato dal catalogo pubblico,
    /// denormalizzando lo username autore e una descrizione sulla card.
    case setProjectPublic(publishedId: String, isPublic: Bool, username: String, description: String)
    /// Sfoglia/cerca il catalogo pubblico (query nil/vuota = più recenti).
    case listPublicProjects(query: String?, offset: Int, limit: Int)
    /// Stato di listing del proprio progetto pubblicato (owner-guarded).
    case getProjectPublic(publishedId: String)
    /// Commenta un progetto elencato nel catalogo pubblico.
    case postProjectComment(publishedId: String, username: String, body: String)
    /// Elenca i commenti di un progetto del catalogo (paginati).
    case listProjectComments(publishedId: String, offset: Int, limit: Int)
    /// Cancella un commento (autore o proprietario del progetto).
    case deleteProjectComment(commentId: String)

    // MARK: - Energy

    case getEnergy
    case addEnergy(amount: Int, transactionId: String)
    case redeem(code: String)

    // MARK: - Account Management

    case deleteAccount(email: String, password: String)

    // MARK: - Utility

    case ping

    /// Capability handshake: chiede versione e feature opzionali del server
    case getServerInfo
}

public struct PinInfo: Sendable {
    public let pin: Int
    public let pinType: PinType

    public init(pin: Int, pinType: PinType = .virtual) {
        self.pin = pin
        self.pinType = pinType
    }
}
