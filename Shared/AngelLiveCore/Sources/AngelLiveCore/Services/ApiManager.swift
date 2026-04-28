//
//  ApiManager.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/12/29.
//

import Foundation

public enum ApiManager {
    /**
     获取当前房间直播状态。

    - Returns: 直播状态
    */
    public static func getCurrentRoomLiveState(roomId: String, userId: String?, liveType: LiveType) async throws -> LiveState {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return .unknow
        }
        return try await LiveParseJSPlatformManager.getLiveState(platform: platform, roomId: roomId, userId: userId)
    }

    public static func fetchRoomList(liveCategory: LiveCategoryModel, page: Int, liveType: LiveType) async throws -> [LiveModel] {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return []
        }
        if liveType == .bilibili {
            return try await fetchBilibiliRoomListWithRetry(platform: platform, id: liveCategory.id, parentId: liveCategory.parentId, page: page)
        }
        return try await LiveParseJSPlatformManager.getRoomList(platform: platform, id: liveCategory.id, parentId: liveCategory.parentId, page: page)
    }

    /// B站请求带重试
    private static func fetchBilibiliRoomListWithRetry(platform: LiveParseJSPlatform, id: String, parentId: String?, page: Int, maxRetries: Int = 3) async throws -> [LiveModel] {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await LiveParseJSPlatformManager.getRoomList(platform: platform, id: id, parentId: parentId, page: page)
            } catch {
                lastError = error

                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                }
            }
        }

        throw lastError ?? LiveParseError.liveParseError("B站请求失败", "连续 \(maxRetries) 次请求失败")
    }

    public static func fetchCategoryList(liveType: LiveType) async throws -> [LiveMainListModel] {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return []
        }
        return try await LiveParseJSPlatformManager.getCategoryList(platform: platform)
    }

    public static func fetchLastestLiveInfo(liveModel: LiveModel) async throws -> LiveModel {
        print("[ApiManager] fetchLastestLiveInfo: \(liveModel.userName) liveType=\(liveModel.liveType.rawValue) roomId=\(liveModel.roomId)")
        guard let platform = SandboxPluginCatalog.platform(for: liveModel.liveType) else {
            print("[ApiManager] fetchLastestLiveInfo: SandboxPluginCatalog.platform 返回 nil, liveType=\(liveModel.liveType.rawValue)")
            throw LiveParseError.liveParseError("不支持的平台", "\(liveModel.liveType)")
        }
        print("[ApiManager] fetchLastestLiveInfo: 找到平台 pluginId=\(platform.pluginId), 准备调用 getLiveLastestInfo")
        do {
            let result = try await LiveParseJSPlatformManager.getLiveLastestInfo(platform: platform, roomId: liveModel.roomId, userId: liveModel.userId)
            print("[ApiManager] fetchLastestLiveInfo: getLiveLastestInfo 返回成功 \(liveModel.userName)")
            return result
        }catch {
            print("[ApiManager] fetchLastestLiveInfo: getLiveLastestInfo 返回失败 \(liveModel.userName)：\(error)")
            throw error
        }
        
    }

    /// 轻量版房间信息获取，用于收藏同步场景
    public static func fetchLastestLiveInfoFast(liveModel: LiveModel) async throws -> LiveModel {
        return try await fetchLastestLiveInfo(liveModel: liveModel)
    }

    public static func fetchSearchWithShareCode(shareCode: String) async throws -> LiveModel? {
        let platforms = matchedShareResolvePlatforms(for: shareCode)
        guard !platforms.isEmpty else {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }

        var lastError: Error?
        for platform in platforms {
            do {
                return try await LiveParseJSPlatformManager.getRoomInfoFromShareCode(platform: platform, shareCode: shareCode)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
    }

    private static func matchedShareResolvePlatforms(for text: String) -> [LiveParseJSPlatform] {
        let normalizedText = text.lowercased()
        let inputHosts = extractHosts(from: normalizedText)

        return SandboxPluginCatalog.availablePlatforms().filter { platform in
            guard PlatformCapability.supports(.shareResolve, for: platform.liveType),
                  let rule = platform.shareResolve else {
                return false
            }

            let hostMatched = normalizedValues(rule.hosts).contains { ruleHost in
                inputHosts.contains { inputHost in
                    inputHost == ruleHost || inputHost.hasSuffix(".\(ruleHost)")
                }
            }

            if hostMatched {
                return true
            }

            return normalizedValues(rule.keywords).contains { keyword in
                normalizedText.contains(keyword)
            }
        }
    }

    private static func normalizedValues(_ values: [String]?) -> [String] {
        values?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty } ?? []
    }

    private static func extractHosts(from text: String) -> [String] {
        let pattern = #"(?:(?:[a-z][a-z0-9+\-.]*):\/\/)?(?:www\.)?([a-z0-9-]+(?:\.[a-z0-9-]+)+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        var hosts: [String] = []
        var seen = Set<String>()

        for match in matches where match.numberOfRanges > 1 {
            guard let hostRange = Range(match.range(at: 1), in: text) else { continue }
            let host = String(text[hostRange]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard !host.isEmpty, !seen.contains(host) else { continue }
            seen.insert(host)
            hosts.append(host)
        }

        return hosts
    }
}
