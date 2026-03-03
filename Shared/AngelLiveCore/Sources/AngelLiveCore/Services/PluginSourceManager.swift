//
//  PluginSourceManager.swift
//  AngelLiveCore
//
//  管理用户添加的插件源 URL，拉取远程索引，安装插件。
//

import Foundation
import Observation
import LiveParse

/// 单个插件的安装状态
public enum PluginInstallState: Equatable, Sendable {
    case notInstalled
    case installing
    case installed
    case failed(String)
}

/// 带安装状态的远程插件条目
@Observable
public final class RemotePluginDisplayItem: Identifiable, @unchecked Sendable {
    public let item: LiveParseRemotePluginItem
    public var installState: PluginInstallState = .notInstalled

    public var id: String { item.pluginId }
    public var displayName: String { item.platformName ?? item.pluginId }

    public init(item: LiveParseRemotePluginItem) {
        self.item = item
    }
}

@Observable
public final class PluginSourceManager {

    /// 用户保存的插件源 URL 列表
    public private(set) var sourceURLs: [String] = []

    /// 当前拉取的远程插件列表
    public private(set) var remotePlugins: [RemotePluginDisplayItem] = []

    /// 各插件在订阅源中的最新版本（按 pluginId 索引）
    public private(set) var latestRemoteItemsByPluginId: [String: LiveParseRemotePluginItem] = [:]

    /// 是否正在拉取索引
    public private(set) var isFetchingIndex: Bool = false

    /// 是否正在检查更新
    public private(set) var isCheckingUpdates: Bool = false

    /// 正在更新中的插件 ID
    public private(set) var updatingPluginIds: Set<String> = []

    /// 错误信息
    public var errorMessage: String?

    /// 是否有插件正在安装
    public var isInstalling: Bool {
        remotePlugins.contains { $0.installState == .installing }
    }

    @ObservationIgnored
    private let sourceURLsKey = "AngelLive.PluginSource.URLs"

    @ObservationIgnored
    private let updater: LiveParsePluginUpdater

    public init() {
        self.updater = LiveParsePluginUpdater(
            storage: LiveParsePlugins.shared.storage,
            session: LiveParsePlugins.shared.session
        )
        loadSourceURLs()
    }

    // MARK: - 插件源管理

    private func loadSourceURLs() {
        sourceURLs = UserDefaults.standard.stringArray(forKey: sourceURLsKey) ?? []
    }

    private func saveSourceURLs() {
        UserDefaults.standard.set(sourceURLs, forKey: sourceURLsKey)
    }

    public func addSource(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sourceURLs.contains(trimmed) else { return }
        sourceURLs.append(trimmed)
        saveSourceURLs()
    }

    public func removeSource(_ urlString: String) {
        sourceURLs.removeAll { $0 == urlString }
        saveSourceURLs()
    }

    // MARK: - 拉取远程索引

    public func fetchIndex(from urlString: String) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的 URL"
            return
        }

        isFetchingIndex = true
        errorMessage = nil
        defer { isFetchingIndex = false }

        do {
            let index = try await updater.fetchIndex(url: url)
            remotePlugins = index.plugins.map { RemotePluginDisplayItem(item: $0) }
            mergeLatestRemoteItems(index.plugins)
        } catch {
            errorMessage = "拉取插件索引失败: \(error.localizedDescription)"
        }
    }

    /// 从所有订阅源检查可更新版本
    public func refreshAvailableUpdates() async {
        guard !sourceURLs.isEmpty else {
            latestRemoteItemsByPluginId = [:]
            return
        }

        errorMessage = nil
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        var latest: [String: LiveParseRemotePluginItem] = [:]

        for source in sourceURLs {
            guard let url = URL(string: source) else { continue }
            do {
                let index = try await updater.fetchIndex(url: url)
                for item in index.plugins {
                    guard let existing = latest[item.pluginId] else {
                        latest[item.pluginId] = item
                        continue
                    }
                    if semverCompare(item.version, existing.version) > 0 {
                        latest[item.pluginId] = item
                    }
                }
            } catch {
                // 单个源失败不影响其它源；保留最后一次错误用于页面提示
                errorMessage = "检查更新失败: \(error.localizedDescription)"
            }
        }

        latestRemoteItemsByPluginId = latest
    }

    // MARK: - 安装插件

    public func installPlugin(_ displayItem: RemotePluginDisplayItem) async -> Bool {
        displayItem.installState = .installing

        do {
            try await updater.installAndActivate(
                item: displayItem.item,
                manager: LiveParsePlugins.shared
            )
            displayItem.installState = .installed
            return true
        } catch {
            displayItem.installState = .failed(error.localizedDescription)
            return false
        }
    }

    /// 安装所有未安装的插件
    public func installAll() async -> Int {
        var successCount = 0
        for plugin in remotePlugins where plugin.installState == .notInstalled {
            if await installPlugin(plugin) {
                successCount += 1
            }
        }
        return successCount
    }

    // MARK: - 版本与更新状态

    public func installedVersion(for pluginId: String) -> String? {
        let versions = LiveParsePlugins.shared.storage.listInstalledVersions(pluginId: pluginId)
            .map(\.lastPathComponent)
            .filter { !$0.isEmpty }
            .sorted { semverCompare($0, $1) > 0 }
        return versions.first
    }

    public func hasUpdate(for pluginId: String) -> Bool {
        guard let installedVersion = installedVersion(for: pluginId),
              let remoteVersion = latestRemoteItemsByPluginId[pluginId]?.version else {
            return false
        }
        return semverCompare(remoteVersion, installedVersion) > 0
    }

    public func latestVersion(for pluginId: String) -> String? {
        latestRemoteItemsByPluginId[pluginId]?.version
    }

    @discardableResult
    public func updatePlugin(pluginId: String) async -> Bool {
        guard let item = latestRemoteItemsByPluginId[pluginId] else { return false }
        if updatingPluginIds.contains(pluginId) { return false }

        errorMessage = nil
        updatingPluginIds.insert(pluginId)
        defer { updatingPluginIds.remove(pluginId) }

        do {
            try await updater.installAndActivate(item: item, manager: LiveParsePlugins.shared)
            return true
        } catch {
            errorMessage = "更新插件失败: \(error.localizedDescription)"
            return false
        }
    }

    private func mergeLatestRemoteItems(_ items: [LiveParseRemotePluginItem]) {
        var merged = latestRemoteItemsByPluginId
        for item in items {
            guard let existing = merged[item.pluginId] else {
                merged[item.pluginId] = item
                continue
            }
            if semverCompare(item.version, existing.version) > 0 {
                merged[item.pluginId] = item
            }
        }
        latestRemoteItemsByPluginId = merged
    }

    private func semverCompare(_ lhs: String, _ rhs: String) -> Int {
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
