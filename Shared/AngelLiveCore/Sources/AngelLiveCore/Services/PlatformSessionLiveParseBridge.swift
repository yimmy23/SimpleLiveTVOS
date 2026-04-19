//
//  PlatformSessionLiveParseBridge.swift
//  AngelLiveCore
//
//  Created by Codex on 2026/2/18.
//

import Foundation

public enum PlatformSessionLiveParseBridge {
    public static func syncSessionToLiveParse(_ session: PlatformSession) {
        Task {
            await syncCredential(session)
        }
    }

    public static func clearForPlatform(pluginId: String) {
        Task {
            await clearCredential(pluginId: pluginId)
        }
    }

    public static func syncFromPersistedSessionsOnLaunch() async {
        // 基于已安装插件集合驱动：宿主端不再维护平台 enum。
        let pluginIds = SandboxPluginCatalog.installedPluginIds()
        for pluginId in pluginIds {
            if let session = await PlatformSessionManager.shared.getSession(pluginId: pluginId) {
                await syncCredential(session)
            } else {
                await clearCredential(pluginId: pluginId)
            }
        }
    }

    // MARK: - Internal

    private static func syncCredential(_ session: PlatformSession) async {
        let pluginId = session.pluginId
        guard SandboxPluginCatalog.isInstalled(pluginId: pluginId) else {
            return
        }

        let normalized = session.cookie?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard session.state == .authenticated, !normalized.isEmpty else {
            await clearCredential(pluginId: pluginId)
            return
        }

        var credential: [String: Any] = ["cookie": normalized]
        if let uid = session.uid, !uid.isEmpty {
            credential["uid"] = uid
        }

        // 优先 setCredential（新 API），失败则 fallback setCookie（老 API）。
        // 无论哪一条路径，LiveParsePluginManager 内部都已把 cookie 写入 vault。
        do {
            _ = try await LiveParsePlugins.shared.call(
                pluginId: pluginId,
                function: "setCredential",
                payload: ["credential": credential]
            )
            Logger.debug("Credential synced via setCredential: \(pluginId)", category: .plugin)
            return
        } catch {
            Logger.debug("setCredential failed for \(pluginId): \(error.localizedDescription). Falling back to setCookie.", category: .plugin)
        }

        do {
            var setCookiePayload: [String: Any] = ["cookie": normalized]
            if let uid = session.uid, !uid.isEmpty {
                setCookiePayload["uid"] = uid
            }
            _ = try await LiveParsePlugins.shared.call(
                pluginId: pluginId,
                function: "setCookie",
                payload: setCookiePayload
            )
            Logger.debug("Cookie synced via setCookie fallback: \(pluginId)", category: .plugin)
        } catch {
            Logger.error(error, message: "Failed to sync credential/cookie for plugin: \(pluginId)", category: .plugin)
        }
    }

    private static func clearCredential(pluginId: String) async {
        guard SandboxPluginCatalog.isInstalled(pluginId: pluginId) else {
            return
        }
        // 优先 clearCredential，失败则 fallback clearCookie。
        do {
            _ = try await LiveParsePlugins.shared.call(
                pluginId: pluginId,
                function: "clearCredential",
                payload: [:]
            )
            Logger.debug("Credential cleared via clearCredential: \(pluginId)", category: .plugin)
            return
        } catch {
            Logger.debug("clearCredential failed for \(pluginId): \(error.localizedDescription). Falling back to clearCookie.", category: .plugin)
        }

        do {
            _ = try await LiveParsePlugins.shared.call(
                pluginId: pluginId,
                function: "clearCookie",
                payload: [:]
            )
            Logger.debug("Cookie cleared via clearCookie fallback: \(pluginId)", category: .plugin)
        } catch {
            Logger.error(error, message: "Failed to clear credential/cookie for plugin: \(pluginId)", category: .plugin)
        }
    }
}
