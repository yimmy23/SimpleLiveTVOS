//
//  PluginInstallConsent.swift
//  AngelLiveCore
//
//  插件订阅 / 安装时的用户确认协议。
//  当订阅源可能含有登录类插件,或单个插件确认需要登录时,
//  由各端注入实现弹原生 alert,询问用户是否继续。
//

import Foundation

/// 批量登录确认中单条插件信息。
public struct LoginPluginEntry: Sendable, Equatable {
    public let pluginId: String
    public let displayName: String

    public init(pluginId: String, displayName: String) {
        self.pluginId = pluginId
        self.displayName = displayName
    }
}

/// 触发确认的场景
public enum PluginInstallConsentReason: Sendable, Equatable {
    /// 用户主动添加订阅源(此阶段还未下载插件,无法精确知道哪些含登录,默认警告)
    case addingSubscriptionSource(url: String)
    /// 单个插件下载完成、激活前确认 — 已知该插件需要登录
    case installingLoginPlugin(pluginId: String, displayName: String)
    /// 一次性批量确认多个登录类插件(用于一键安装、批量安装等场景),
    /// 替代原本"每平台弹一次"的串行确认。
    case installingLoginPluginsBatch(plugins: [LoginPluginEntry])
    /// CloudKit 自动同步触发的批量安装
    case cloudKitAutoInstall(sourceURLs: [String])
}

/// 由 UI 层实现,接收确认请求并返回用户选择(true = 继续,false = 取消)。
/// 实现一定要在 MainActor 上(弹 alert 必须主线程)。
public protocol PluginInstallConsentRequesting: Sendable {
    @MainActor
    func requestConsent(reason: PluginInstallConsentReason) async -> Bool
}

/// 用户在安装确认环节选择取消时使用的错误,
/// 以便 `installAndActivate` 的 catch 路径触发回滚。
public enum PluginInstallConsentError: Error {
    case userDeclined
}
