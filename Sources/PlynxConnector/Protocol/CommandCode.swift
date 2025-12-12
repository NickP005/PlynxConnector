//
//  CommandCode.swift
//  PlynxConnector
//
//  Binary protocol command codes for Plynx (Blynk) server communication.
//

import Foundation

/// All command codes supported by the Plynx server protocol.
/// These codes are sent as the first byte of each message.
public enum CommandCode: UInt8, Sendable {
    // MARK: - Response
    case response = 0
    
    // MARK: - Authentication
    case register = 1
    case login = 2
    case redeem = 3
    case ping = 6
    case getServer = 40
    case shareLogin = 32
    case logout = 66
    case resetPassword = 81
    
    // MARK: - Dashboard Management
    case activateDashboard = 7
    case deactivateDashboard = 8
    case createDash = 21
    case updateDash = 22
    case deleteDash = 23
    case loadProfileGzipped = 24
    case updateProjectSettings = 38
    
    // MARK: - Widget Management
    case setWidgetProperty = 19
    case createWidget = 33
    case updateWidget = 34
    case deleteWidget = 35
    case getWidget = 70
    
    // MARK: - Device Management
    case createDevice = 42
    case updateDevice = 43
    case deleteDevice = 44
    case getDevices = 45
    case mobileGetDevice = 50
    case deleteDeviceData = 76
    
    // MARK: - Tag Management
    case createTag = 46
    case updateTag = 47
    case deleteTag = 48
    case getTags = 49
    
    // MARK: - Tile Template Management
    case createTileTemplate = 67
    case updateTileTemplate = 68
    case deleteTileTemplate = 69
    
    // MARK: - Token Management
    case refreshToken = 9
    case assignToken = 39
    case getProvisionToken = 74
    
    // MARK: - Hardware Communication
    case hardwareConnected = 4
    case hardwareSync = 16
    case hardware = 20
    case appSync = 25
    case hardwareResendFromBluetooth = 65
    case deviceOffline = 71
    
    // MARK: - Sharing
    case sharing = 26
    case getShareToken = 30
    case refreshShareToken = 31
    
    // MARK: - Notifications
    case tweet = 12
    case email = 13
    case pushNotification = 14
    case addPushToken = 27
    case emailQR = 59
    
    // MARK: - Graph & Data
    case exportGraphData = 28
    case getEnhancedGraphData = 60
    case deleteEnhancedGraphData = 61
    
    // MARK: - Report Management
    case createReport = 77
    case updateReport = 78
    case deleteReport = 79
    case exportReport = 80
    
    // MARK: - App Management
    case createApp = 55
    case updateApp = 56
    case deleteApp = 57
    case updateFace = 51
    
    // MARK: - Clone & Project
    case getProjectByToken = 58
    case getCloneCode = 62
    case getProjectByCloneCode = 63
    
    // MARK: - Energy
    case getEnergy = 36
    case addEnergy = 37
    
    // MARK: - Internal
    case bridge = 15
    case blynkInternal = 17
    case sms = 18
    case connectRedirect = 41
    case webSockets = 52
    case eventor = 53
    case webHooks = 54
    case hardwareLogEvent = 64
    case outdatedAppNotification = 72
    case trackDevice = 73
    case resolveEvent = 75
    
    // MARK: - Account Management
    case deleteAccount = 95
    
    /// Human-readable name for debugging
    public var name: String {
        switch self {
        case .response: return "RESPONSE"
        case .register: return "REGISTER"
        case .login: return "LOGIN"
        case .redeem: return "REDEEM"
        case .hardwareConnected: return "HARDWARE_CONNECTED"
        case .ping: return "PING"
        case .activateDashboard: return "ACTIVATE_DASHBOARD"
        case .deactivateDashboard: return "DEACTIVATE_DASHBOARD"
        case .refreshToken: return "REFRESH_TOKEN"
        case .tweet: return "TWEET"
        case .email: return "EMAIL"
        case .pushNotification: return "PUSH_NOTIFICATION"
        case .bridge: return "BRIDGE"
        case .hardwareSync: return "HARDWARE_SYNC"
        case .blynkInternal: return "BLYNK_INTERNAL"
        case .sms: return "SMS"
        case .setWidgetProperty: return "SET_WIDGET_PROPERTY"
        case .hardware: return "HARDWARE"
        case .createDash: return "CREATE_DASH"
        case .updateDash: return "UPDATE_DASH"
        case .deleteDash: return "DELETE_DASH"
        case .loadProfileGzipped: return "LOAD_PROFILE_GZIPPED"
        case .appSync: return "APP_SYNC"
        case .sharing: return "SHARING"
        case .addPushToken: return "ADD_PUSH_TOKEN"
        case .exportGraphData: return "EXPORT_GRAPH_DATA"
        case .getShareToken: return "GET_SHARE_TOKEN"
        case .refreshShareToken: return "REFRESH_SHARE_TOKEN"
        case .shareLogin: return "SHARE_LOGIN"
        case .createWidget: return "CREATE_WIDGET"
        case .updateWidget: return "UPDATE_WIDGET"
        case .deleteWidget: return "DELETE_WIDGET"
        case .getEnergy: return "GET_ENERGY"
        case .addEnergy: return "ADD_ENERGY"
        case .updateProjectSettings: return "UPDATE_PROJECT_SETTINGS"
        case .assignToken: return "ASSIGN_TOKEN"
        case .getServer: return "GET_SERVER"
        case .connectRedirect: return "CONNECT_REDIRECT"
        case .createDevice: return "CREATE_DEVICE"
        case .updateDevice: return "UPDATE_DEVICE"
        case .deleteDevice: return "DELETE_DEVICE"
        case .getDevices: return "GET_DEVICES"
        case .createTag: return "CREATE_TAG"
        case .updateTag: return "UPDATE_TAG"
        case .deleteTag: return "DELETE_TAG"
        case .getTags: return "GET_TAGS"
        case .mobileGetDevice: return "MOBILE_GET_DEVICE"
        case .updateFace: return "UPDATE_FACE"
        case .webSockets: return "WEB_SOCKETS"
        case .eventor: return "EVENTOR"
        case .webHooks: return "WEB_HOOKS"
        case .createApp: return "CREATE_APP"
        case .updateApp: return "UPDATE_APP"
        case .deleteApp: return "DELETE_APP"
        case .getProjectByToken: return "GET_PROJECT_BY_TOKEN"
        case .emailQR: return "EMAIL_QR"
        case .getEnhancedGraphData: return "GET_ENHANCED_GRAPH_DATA"
        case .deleteEnhancedGraphData: return "DELETE_ENHANCED_GRAPH_DATA"
        case .getCloneCode: return "GET_CLONE_CODE"
        case .getProjectByCloneCode: return "GET_PROJECT_BY_CLONE_CODE"
        case .hardwareLogEvent: return "HARDWARE_LOG_EVENT"
        case .hardwareResendFromBluetooth: return "HARDWARE_RESEND_FROM_BLUETOOTH"
        case .logout: return "LOGOUT"
        case .createTileTemplate: return "CREATE_TILE_TEMPLATE"
        case .updateTileTemplate: return "UPDATE_TILE_TEMPLATE"
        case .deleteTileTemplate: return "DELETE_TILE_TEMPLATE"
        case .getWidget: return "GET_WIDGET"
        case .deviceOffline: return "DEVICE_OFFLINE"
        case .outdatedAppNotification: return "OUTDATED_APP_NOTIFICATION"
        case .trackDevice: return "TRACK_DEVICE"
        case .getProvisionToken: return "GET_PROVISION_TOKEN"
        case .resolveEvent: return "RESOLVE_EVENT"
        case .deleteDeviceData: return "DELETE_DEVICE_DATA"
        case .createReport: return "CREATE_REPORT"
        case .updateReport: return "UPDATE_REPORT"
        case .deleteReport: return "DELETE_REPORT"
        case .exportReport: return "EXPORT_REPORT"
        case .resetPassword: return "RESET_PASSWORD"
        case .deleteAccount: return "DELETE_ACCOUNT"
        }
    }
}
