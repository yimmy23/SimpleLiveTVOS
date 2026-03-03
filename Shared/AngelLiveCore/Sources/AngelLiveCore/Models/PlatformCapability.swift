//
//  PlatformCapability.swift
//  AngelLiveCore
//
//  Created by Claude on 2026/2/25.
//

import Foundation
import LiveParse

// MARK: - 平台功能枚举

public enum PlatformFeature: String, CaseIterable, Sendable {
    case categories    // 分类列表
    case rooms         // 房间列表
    case playback      // 获取播放地址
    case search        // 搜索
    case roomDetail    // 主播详情
    case liveState     // 直播状态
    case shareResolve  // 分享码解析
    case danmaku       // 弹幕

    public var displayName: String {
        switch self {
        case .categories:   return "分类列表"
        case .rooms:        return "房间列表"
        case .playback:     return "获取播放地址"
        case .search:       return "搜索"
        case .roomDetail:   return "主播详情"
        case .liveState:    return "直播状态"
        case .shareResolve: return "分享码解析"
        case .danmaku:      return "弹幕"
        }
    }

    public var iconName: String {
        switch self {
        case .categories:   return "square.grid.2x2"
        case .rooms:        return "list.bullet"
        case .playback:     return "play.circle"
        case .search:       return "magnifyingglass"
        case .roomDetail:   return "person.text.rectangle"
        case .liveState:    return "dot.radiowaves.left.and.right"
        case .shareResolve: return "link"
        case .danmaku:      return "text.bubble"
        }
    }
}

// MARK: - 功能可用性状态

public enum FeatureStatus: Sendable {
    case available
    case partial(String)
    case unavailable
}

// MARK: - 平台功能可用性配置

public enum PlatformCapability {
    private struct PluginEntryCandidate {
        let version: String
        let entryURL: URL
    }

    private struct PluginCapabilityCandidate {
        let version: String
        let capabilities: [PlatformFeature: FeatureStatus]
    }

    private static let featureFunctionNames: [(PlatformFeature, [String])] = [
        (.categories, ["getCategories", "getCategoryList"]),
        (.rooms, ["getRooms", "getRoomList"]),
        (.playback, ["getPlayback", "getPlayArgs"]),
        (.search, ["search", "searchRooms"]),
        (.roomDetail, ["getRoomDetail", "getLiveLastestInfo"]),
        (.liveState, ["getLiveState"]),
        (.shareResolve, ["resolveShare", "getRoomInfoFromShareCode"]),
        (.danmaku, ["getDanmaku", "getDanmukuArgs"])
    ]

    public static func features(for liveType: LiveType) -> [(PlatformFeature, FeatureStatus)] {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return featureFunctionNames.map { ($0.0, .unavailable) }
        }

        if let capabilities = loadPluginCapabilities(pluginId: platform.pluginId) {
            return PlatformFeature.allCases.map { feature in
                (feature, capabilities[feature] ?? .unavailable)
            }
        }

        guard let entryScript = loadPluginEntryScript(pluginId: platform.pluginId) else {
            return featureFunctionNames.map { ($0.0, .unavailable) }
        }

        return featureFunctionNames.map { feature, functionNames in
            let isAvailable = functionNames.contains { containsFunction(named: $0, in: entryScript) }
            return (feature, isAvailable ? .available : .unavailable)
        }
    }

    private static func loadPluginCapabilities(pluginId: String) -> [PlatformFeature: FeatureStatus]? {
        loadSandboxPluginCapabilities(pluginId: pluginId)
    }

    private static func loadPluginEntryScript(pluginId: String) -> String? {
        loadSandboxPluginEntryScript(pluginId: pluginId)
    }

    private static func loadSandboxPluginEntryScript(pluginId: String) -> String? {
        let versionDirectories = LiveParsePlugins.shared.storage.listInstalledVersions(pluginId: pluginId)
        var candidates: [PluginEntryCandidate] = []

        for versionDirectory in versionDirectories {
            let manifestURL = versionDirectory.appendingPathComponent("manifest.json", isDirectory: false)
            guard let manifest = loadManifest(from: manifestURL), manifest.pluginId == pluginId else {
                continue
            }

            let entryURL = versionDirectory.appendingPathComponent(manifest.entry, isDirectory: false)
            guard FileManager.default.fileExists(atPath: entryURL.path) else { continue }
            candidates.append(PluginEntryCandidate(version: manifest.version, entryURL: entryURL))
        }

        guard let candidate = candidates.max(by: { semverCompare($0.version, $1.version) < 0 }) else {
            return nil
        }
        return try? String(contentsOf: candidate.entryURL, encoding: .utf8)
    }

    private static func loadSandboxPluginCapabilities(pluginId: String) -> [PlatformFeature: FeatureStatus]? {
        let versionDirectories = LiveParsePlugins.shared.storage.listInstalledVersions(pluginId: pluginId)
        var candidates: [PluginCapabilityCandidate] = []

        for versionDirectory in versionDirectories {
            let manifestURL = versionDirectory.appendingPathComponent("manifest.json", isDirectory: false)
            guard let manifest = loadManifest(from: manifestURL),
                  manifest.pluginId == pluginId,
                  let capabilities = parseCapabilities(from: manifestURL) else {
                continue
            }
            candidates.append(PluginCapabilityCandidate(version: manifest.version, capabilities: capabilities))
        }

        guard let candidate = candidates.max(by: { semverCompare($0.version, $1.version) < 0 }) else {
            return nil
        }
        return candidate.capabilities
    }

    private static func loadManifest(from url: URL) -> LiveParsePluginManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LiveParsePluginManifest.self, from: data)
    }

    private static func parseCapabilities(from manifestURL: URL) -> [PlatformFeature: FeatureStatus]? {
        guard let data = try? Data(contentsOf: manifestURL),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let json = jsonObject as? [String: Any],
              let rawCapabilities = json["capabilities"] as? [String: Any] else {
            return nil
        }

        var result: [PlatformFeature: FeatureStatus] = [:]
        for feature in PlatformFeature.allCases {
            guard let rawValue = rawCapabilities[feature.rawValue],
                  let status = parseFeatureStatus(rawValue) else {
                continue
            }
            result[feature] = status
        }

        return result.isEmpty ? nil : result
    }

    private static func parseFeatureStatus(_ raw: Any) -> FeatureStatus? {
        if let status = raw as? String {
            return mapFeatureStatus(status: status, reason: nil)
        }
        if let dictionary = raw as? [String: Any] {
            guard let status = dictionary["status"] as? String else { return nil }
            let reason = dictionary["reason"] as? String
            return mapFeatureStatus(status: status, reason: reason)
        }
        return nil
    }

    private static func mapFeatureStatus(status: String, reason: String?) -> FeatureStatus? {
        switch status.lowercased() {
        case "available":
            return .available
        case "partial":
            let normalizedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .partial((normalizedReason?.isEmpty == false ? normalizedReason : "部分可用") ?? "部分可用")
        case "unavailable":
            return .unavailable
        default:
            return nil
        }
    }

    private static func containsFunction(named name: String, in script: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            "\\b\(escaped)\\s*\\(",
            "\\b\(escaped)\\s*:",
            "[\"']\(escaped)[\"']\\s*:"
        ]

        let searchRange = NSRange(script.startIndex..<script.endIndex, in: script)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            if regex.firstMatch(in: script, options: [], range: searchRange) != nil {
                return true
            }
        }
        return false
    }

    private static func semverCompare(_ lhs: String, _ rhs: String) -> Int {
        func parts(_ text: String) -> [Int] {
            text.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
        }

        let left = parts(lhs)
        let right = parts(rhs)

        for index in 0..<3 where left[index] != right[index] {
            return left[index] < right[index] ? -1 : 1
        }
        return 0
    }
}
