// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


public final class LiveParsePlatformInfo: Codable {
    public let pluginId: String
    public let liveType: LiveType
    public let livePlatformName: String
    public let description: String

    init(pluginId: String, liveType: LiveType, livePlatformName: String, description: String) {
        self.pluginId = pluginId
        self.liveType = liveType
        self.livePlatformName = livePlatformName
        self.description = description
    }
}

public final class LiveParseTools {
    private static func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    public class func getLivePlatformName(_ liveType: LiveType) -> String {
        if let platform = LiveParseJSPlatformManager.platform(for: liveType),
           let name = normalizedText(platform.platformName) {
            return name
        }
        if let platform = LiveParseJSPlatformManager.platform(for: liveType) {
            return platform.displayName
        }
        return "平台\(liveType.rawValue)"
    }

    public class func getLivePlatformDescription(_ liveType: LiveType) -> String {
        if let platform = LiveParseJSPlatformManager.platform(for: liveType),
           let description = normalizedText(platform.platformDescription) {
            return description
        }
        return "由资源扩展提供"
    }

    public class func getAllSupportPlatform() -> [LiveParsePlatformInfo] {
        return LiveParseJSPlatformManager.availablePlatforms.map { platform in
            let liveType = platform.liveType
            return LiveParsePlatformInfo(
                pluginId: platform.pluginId,
                liveType: liveType,
                livePlatformName: getLivePlatformName(liveType),
                description: getLivePlatformDescription(liveType)
            )
        }
    }
}


public enum LiveParseError: Error, CustomStringConvertible, LocalizedError {

    case shareCodeParseError(String, String)
    case liveParseError(String, String)
    case liveStateParseError(String, String)
    case danmuArgsParseError(String, String)

    /// 错误标题（用于展示给用户或日志分类）
    public var title: String {
        switch self {
        case .shareCodeParseError(let title, _),
             .liveParseError(let title, _),
             .liveStateParseError(let title, _),
             .danmuArgsParseError(let title, _):
            return title
        }
    }

    /// 详细错误信息（包含网络请求详情等调试信息）
    public var detail: String {
        switch self {
        case .shareCodeParseError(_, let detail),
             .liveParseError(_, let detail),
             .liveStateParseError(_, let detail),
             .danmuArgsParseError(_, let detail):
            return detail
        }
    }

    /// 完整描述，用于打印或展示
    public var description: String {
        if detail.isEmpty {
            return title
        }
        if detail.contains(title) {
            return detail
        }
        return "\(title)\n\(detail)"
    }

    // MARK: - LocalizedError 协议实现

    /// 错误描述（用于 localizedDescription）
    public var errorDescription: String? {
        return title
    }

    /// 失败原因
    public var failureReason: String? {
        return detail.isEmpty ? nil : detail
    }
}
