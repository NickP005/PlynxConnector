import Foundation

// MARK: - BlynkMessage Conversion

extension Action {

    func toMessage(messageId: UInt16, encoder: JSONEncoder) throws -> BlynkMessage {
        switch self {
        case .register(let email, let password, let appName):
            let passwordHash = SHA256Helper.makeHash(password: password, email: email)
            return BlynkMessage(command: .register, messageId: messageId,
                              bodyParts: [email, passwordHash, appName])

        case .login(let email, let password, let appName):
            let passwordHash = SHA256Helper.makeHash(password: password, email: email)
            return BlynkMessage(command: .login, messageId: messageId,
                              bodyParts: [email, passwordHash, "iOS", "1.0.0", appName])

        case .shareLogin(let token):
            return BlynkMessage(command: .shareLogin, messageId: messageId, body: token)

        case .logout(let uid):
            return BlynkMessage(command: .logout, messageId: messageId, body: uid ?? "")

        case .resetPasswordStart(let email, let appName):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: ["start", email, appName])

        case .resetPasswordVerify(let token):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: ["verify", token])

        case .resetPasswordComplete(let token, let email, let newPassword, let appName):
            return BlynkMessage(command: .resetPassword, messageId: messageId,
                              bodyParts: [token, email, newPassword, appName])

        case .getServer(let email):
            return BlynkMessage(command: .getServer, messageId: messageId, body: email)

        case .createDashboard(let dashboard, let generateToken):
            let json = try encoder.encode(dashboard)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            let body = generateToken ? jsonString : "no_token\0\(jsonString)"
            return BlynkMessage(command: .createDash, messageId: messageId, body: body)

        case .updateDashboard(let dashboard):
            let json = try encoder.encode(dashboard)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateDash, messageId: messageId, body: jsonString)

        case .deleteDashboard(let dashId):
            return BlynkMessage(command: .deleteDash, messageId: messageId, body: "\(dashId)")

        case .activateDashboard(let dashId):
            return BlynkMessage(command: .activateDashboard, messageId: messageId, body: "\(dashId)")

        case .deactivateDashboard(let dashId):
            let body = dashId.map { "\($0)" } ?? ""
            return BlynkMessage(command: .deactivateDashboard, messageId: messageId, body: body)

        case .updateDashboardSettings(let dashId, let settings):
            let json = try encoder.encode(settings)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateProjectSettings, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .loadProfile(let dashId, let published):
            var body = ""
            if let dashId = dashId {
                body = "\(dashId)"
                if published {
                    body += "\0published"
                }
            }
            return BlynkMessage(command: .loadProfileGzipped, messageId: messageId, body: body)

        case .createWidget(let dashId, let widget, let tileId):
            let json = try encoder.encode(widget)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            var bodyParts = ["\(dashId)", jsonString]
            if let tileId = tileId {
                bodyParts.append("\(tileId)")
            }
            return BlynkMessage(command: .createWidget, messageId: messageId, bodyParts: bodyParts)

        case .updateWidget(let dashId, let widget):
            let json = try encoder.encode(widget)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .deleteWidget(let dashId, let widgetId):
            return BlynkMessage(command: .deleteWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])

        case .getWidget(let dashId, let widgetId):
            return BlynkMessage(command: .getWidget, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])

        case .setWidgetProperty(let dashId, let deviceId, let pin, let property, let value):
            return BlynkMessage(command: .setWidgetProperty, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", "\(pin)", property.rawValue, value])

        case .createDevice(let dashId, let device):
            let json = try encoder.encode(device)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .updateDevice(let dashId, let device):
            let json = try encoder.encode(device)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .deleteDevice(let dashId, let deviceId):
            return BlynkMessage(command: .deleteDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])

        case .getDevices(let dashId):
            return BlynkMessage(command: .getDevices, messageId: messageId, body: "\(dashId)")

        case .getDevice(let dashId, let deviceId):
            return BlynkMessage(command: .mobileGetDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])

        case .deleteDeviceData(let dashId, let deviceId, let pins):
            var bodyParts = ["\(dashId)", "\(deviceId)"]
            if let pins = pins {
                let pinStrings = pins.map { "\($0.pinType.code)\($0.pin)" }
                bodyParts.append(contentsOf: pinStrings)
            }
            return BlynkMessage(command: .deleteDeviceData, messageId: messageId, bodyParts: bodyParts)

        case .createTag(let dashId, let tag):
            let json = try encoder.encode(tag)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createTag, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .updateTag(let dashId, let tag):
            let json = try encoder.encode(tag)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateTag, messageId: messageId,
                              bodyParts: ["\(dashId)", jsonString])

        case .deleteTag(let dashId, let tagId):
            return BlynkMessage(command: .deleteTag, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(tagId)"])

        case .getTags(let dashId):
            return BlynkMessage(command: .getTags, messageId: messageId, body: "\(dashId)")

        case .createTileTemplate(let dashId, let widgetId, let template):
            let json = try encoder.encode(template)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])

        case .updateTileTemplate(let dashId, let widgetId, let template):
            let json = try encoder.encode(template)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])

        case .deleteTileTemplate(let dashId, let widgetId, let templateId):
            return BlynkMessage(command: .deleteTileTemplate, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(templateId)"])

        case .refreshToken(let dashId, let deviceId):
            if let deviceId = deviceId {
                return BlynkMessage(command: .refreshToken, messageId: messageId,
                                  bodyParts: ["\(dashId)", "\(deviceId)"])
            } else {
                return BlynkMessage(command: .refreshToken, messageId: messageId, body: "\(dashId)")
            }

        case .assignToken(let dashId, let deviceId, let token):
            return BlynkMessage(command: .assignToken, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)", token])

        case .getProvisionToken(let dashId, let deviceId):
            return BlynkMessage(command: .getProvisionToken, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])

        case .hardware(let dashId, let deviceId, let body):
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", body])

        case .writeVirtualPin(let dashId, let deviceId, let pin, let value):
            let hwBody = "vw\0\(pin)\0\(value)"
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", hwBody])

        case .readVirtualPin(let dashId, let deviceId, let pin):
            let hwBody = "vr\0\(pin)"
            return BlynkMessage(command: .hardware, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", hwBody])

        case .hardwareSync(let dashId, let target):
            if let target = target {
                return BlynkMessage(command: .hardwareSync, messageId: messageId,
                                  bodyParts: ["\(dashId)", target])
            } else {
                return BlynkMessage(command: .hardwareSync, messageId: messageId, body: "\(dashId)")
            }

        case .appSync(let dashId, let widgetIds):
            if let widgetIds = widgetIds {
                let idsStr = widgetIds.map { "\($0)" }.joined(separator: "\0")
                return BlynkMessage(command: .appSync, messageId: messageId,
                                  bodyParts: ["\(dashId)", idsStr])
            } else {
                return BlynkMessage(command: .appSync, messageId: messageId, body: "\(dashId)")
            }

        case .resendFromBluetooth(let dashId, let deviceId, let body):
            return BlynkMessage(command: .hardwareResendFromBluetooth, messageId: messageId,
                              bodyParts: ["\(dashId)-\(deviceId)", body])

        case .setSharing(let dashId, let enabled):
            return BlynkMessage(command: .sharing, messageId: messageId,
                              bodyParts: ["\(dashId)", enabled ? "on" : "off"])

        case .getShareToken(let dashId):
            return BlynkMessage(command: .getShareToken, messageId: messageId, body: "\(dashId)")

        case .refreshShareToken(let dashId):
            return BlynkMessage(command: .refreshShareToken, messageId: messageId, body: "\(dashId)")

        case .getEnhancedGraphData(let dashId, let widgetId, let targetId, let period, let page):
            let dashPart = targetId.map { "\(dashId)-\($0)" } ?? "\(dashId)"
            var bodyParts = [dashPart, "\(widgetId)", period.rawValue]
            if let page = page {
                bodyParts.append("\(page)")
            }
            return BlynkMessage(command: .getEnhancedGraphData, messageId: messageId, bodyParts: bodyParts)

        case .deleteEnhancedGraphData(let dashId, let widgetId, let dataStreamIds):
            var bodyParts = ["\(dashId)", "\(widgetId)"]
            if let ids = dataStreamIds {
                bodyParts.append(contentsOf: ids.map { "\($0)" })
            }
            return BlynkMessage(command: .deleteEnhancedGraphData, messageId: messageId, bodyParts: bodyParts)

        case .exportGraphData(let dashId, let widgetId, let pinType, let pin, let deviceId):
            return BlynkMessage(command: .exportGraphData, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", pinType.rawValue, "\(pin)", "\(deviceId)"])

        case .createReport(let dashId, let widgetId, let report):
            let json = try encoder.encode(report)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])

        case .updateReport(let dashId, let widgetId, let report):
            let json = try encoder.encode(report)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", jsonString])

        case .deleteReport(let dashId, let widgetId, let reportId):
            return BlynkMessage(command: .deleteReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(reportId)"])

        case .exportReport(let dashId, let widgetId, let reportId):
            return BlynkMessage(command: .exportReport, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)", "\(reportId)"])

        case .emailToken(let dashId, let deviceId):
            if let deviceId = deviceId {
                return BlynkMessage(command: .email, messageId: messageId,
                                  bodyParts: ["\(dashId)", "\(deviceId)"])
            } else {
                return BlynkMessage(command: .email, messageId: messageId, body: "\(dashId)")
            }

        case .email(let dashId, let deviceId, let to, let subject, let body):
            var parts = ["\(dashId)-\(deviceId)"]
            if let to = to {
                parts.append(to)
                parts.append(subject ?? "")
                parts.append(body ?? "")
            }
            return BlynkMessage(command: .email, messageId: messageId, bodyParts: parts)

        case .emailQR(let dashId, let widgetId):
            return BlynkMessage(command: .emailQR, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(widgetId)"])

        case .addPushToken(let dashId, let uid, let token):
            return BlynkMessage(command: .addPushToken, messageId: messageId,
                              bodyParts: ["\(dashId)", uid, token])

        case .createApp(let app):
            let json = try encoder.encode(app)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .createApp, messageId: messageId, body: jsonString)

        case .updateApp(let app):
            let json = try encoder.encode(app)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return BlynkMessage(command: .updateApp, messageId: messageId, body: jsonString)

        case .deleteApp(let appId):
            return BlynkMessage(command: .deleteApp, messageId: messageId, body: "\(appId)")

        case .updateFace(let appId, let dashJson):
            return BlynkMessage(command: .updateFace, messageId: messageId,
                              bodyParts: ["\(appId)", dashJson])

        case .getCloneCode(let dashId):
            return BlynkMessage(command: .getCloneCode, messageId: messageId, body: "\(dashId)")

        case .getProjectByCloneCode(let code, let create):
            if create {
                return BlynkMessage(command: .getProjectByCloneCode, messageId: messageId,
                                  bodyParts: [code, "1"])
            } else {
                return BlynkMessage(command: .getProjectByCloneCode, messageId: messageId, body: code)
            }

        case .getProjectByToken(let token):
            return BlynkMessage(command: .getProjectByToken, messageId: messageId, body: token)

        case .publishProject(let dashId):
            return BlynkMessage(command: .publishProject, messageId: messageId, body: "\(dashId)")

        case .getPublishedProject(let publishedId, let countsAsDownload):
            //Flag additivo "0" = solo anteprima (non contare come download).
            //Omesso nel caso download per restare byte-identici ai client
            //storici (i server vecchi ignorano comunque la parte extra).
            return countsAsDownload
                ? BlynkMessage(command: .getPublishedProject, messageId: messageId, body: publishedId)
                : BlynkMessage(command: .getPublishedProject, messageId: messageId,
                               bodyParts: [publishedId, "0"])

        case .setProjectPublic(let publishedId, let isPublic, let username, let description):
            return BlynkMessage(command: .setProjectPublic, messageId: messageId,
                              bodyParts: [publishedId, isPublic ? "1" : "0", username, description])

        case .listPublicProjects(let query, let offset, let limit):
            return BlynkMessage(command: .listPublicProjects, messageId: messageId,
                              bodyParts: ["\(offset)", "\(limit)", query ?? ""])

        case .getProjectPublic(let publishedId):
            return BlynkMessage(command: .getProjectPublic, messageId: messageId, body: publishedId)

        case .postProjectComment(let publishedId, let username, let body):
            return BlynkMessage(command: .postProjectComment, messageId: messageId,
                              bodyParts: [publishedId, username, body])

        case .listProjectComments(let publishedId, let offset, let limit):
            return BlynkMessage(command: .listProjectComments, messageId: messageId,
                              bodyParts: [publishedId, "\(offset)", "\(limit)"])

        case .deleteProjectComment(let commentId):
            return BlynkMessage(command: .deleteProjectComment, messageId: messageId, body: commentId)
        case .rateProject(let publishedId, let stars):
            return BlynkMessage(command: .rateProject, messageId: messageId,
                              bodyParts: [publishedId, "\(stars)"])
        case .getProjectRating(let publishedId):
            return BlynkMessage(command: .getProjectRating, messageId: messageId, body: publishedId)

        case .otaUploadToken:
            return BlynkMessage(command: .otaUploadToken, messageId: messageId)

        case .otaList:
            return BlynkMessage(command: .otaList, messageId: messageId)

        case .otaPush(let deviceRef, let versionId):
            return BlynkMessage(command: .otaPush, messageId: messageId,
                              bodyParts: [deviceRef, versionId])

        case .otaPromote(let versionId):
            return BlynkMessage(command: .otaPromote, messageId: messageId, body: versionId)

        case .otaFollow(let deviceRef, let lineageId):
            //lineage vuoto = "smetti di seguire" (il server accetta anche "0"):
            //la seconda parte va comunque mandata, sennò il body non ha campi.
            return BlynkMessage(command: .otaFollow, messageId: messageId,
                              bodyParts: [deviceRef, lineageId ?? ""])

        case .otaSetTest(let deviceRef, let isTestBoard):
            return BlynkMessage(command: .otaSetTest, messageId: messageId,
                              bodyParts: [deviceRef, isTestBoard ? "true" : "false"])

        case .otaStatus(let deviceRef):
            return BlynkMessage(command: .otaStatus, messageId: messageId, body: deviceRef)

        case .otaDeleteVersion(let versionId):
            return BlynkMessage(command: .otaDeleteVersion, messageId: messageId, body: versionId)

        case .editorPairClaim(let pairCode, let dashId):
            return BlynkMessage(command: .editorPairClaim, messageId: messageId,
                              bodyParts: [pairCode, "\(dashId)"])

        case .editorSessions(let dashId):
            //body vuoto = tutte le sessioni dell'utente; con un dashId il
            //server filtra lui, così la lista non passa dalla rete intera.
            return BlynkMessage(command: .editorSessions, messageId: messageId,
                              body: dashId.map { "\($0)" } ?? "")

        case .editorSessionRevoke(let sessionId):
            return BlynkMessage(command: .editorSessionRevoke, messageId: messageId,
                              body: sessionId)

        case .getEnergy:
            return BlynkMessage(command: .getEnergy, messageId: messageId)

        case .addEnergy(let amount, let transactionId):
            return BlynkMessage(command: .addEnergy, messageId: messageId,
                              bodyParts: ["\(amount)", transactionId])

        case .redeem(let code):
            return BlynkMessage(command: .redeem, messageId: messageId, body: code)

        case .deleteAccount(let email, let password):
            let passwordHash = SHA256Helper.makeHash(password: password, email: email)
            return BlynkMessage(command: .deleteAccount, messageId: messageId, body: passwordHash)

        case .ping:
            return BlynkMessage(command: .ping, messageId: messageId)

        case .getServerInfo:
            return BlynkMessage(command: .getServerInfo, messageId: messageId)

        case .linkDevice(let targetDashId, let ownerDashId, let ownerDeviceId):
            return BlynkMessage(command: .linkDevice, messageId: messageId,
                              bodyParts: ["\(targetDashId)", "\(ownerDashId)", "\(ownerDeviceId)"])

        case .unlinkDevice(let dashId, let deviceId):
            return BlynkMessage(command: .unlinkDevice, messageId: messageId,
                              bodyParts: ["\(dashId)", "\(deviceId)"])
        }
    }
}
