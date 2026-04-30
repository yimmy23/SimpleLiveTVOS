//
//  AngelLiveDeepLink.swift
//  AngelLiveCore
//
//  应用自定义 URL Scheme(`angellive://`) 的解析。
//  iOS / macOS 在 `.onOpenURL` 中调用 `AngelLiveDeepLink.parse(_:)`,
//  匹配到具体动作后由各端宿主分发到对应业务流程(目前为插件订阅源安装)。
//

import Foundation

/// 应用受理的深链接动作。
public enum AngelLiveDeepLink: Equatable, Sendable {
    /// 添加并安装订阅源。`input` 接受完整索引 URL 或短 key,
    /// 由 `PluginSourceManager.addSourceFromInput(_:)` 进一步解析。
    case installSource(input: String)
}

public extension AngelLiveDeepLink {

    /// 应用使用的固定 scheme。
    static let scheme = "angellive"

    /// 解析外部传入的 URL,无法识别时返回 nil。
    static func parse(_ url: URL) -> AngelLiveDeepLink? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let host = url.host?.lowercased()
        switch host {
        case "install-source":
            return parseInstallSource(url)
        default:
            return nil
        }
    }

    private static func parseInstallSource(_ url: URL) -> AngelLiveDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let value = components.queryItems?
            .first(where: { $0.name == "source" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source = value, !source.isEmpty else { return nil }
        return .installSource(input: source)
    }
}
