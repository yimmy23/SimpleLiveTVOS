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
public final class PluginSourceManager: @unchecked Sendable {

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

    /// 每个订阅源对应的插件 ID 集合（用于删除订阅源时联动删除插件）
    private var sourcePluginIds: [String: Set<String>] = [:]

    /// 是否有插件正在安装
    public var isInstalling: Bool {
        remotePlugins.contains { $0.installState == .installing }
    }

    @ObservationIgnored
    private let sourceURLsKey = "AngelLive.PluginSource.URLs"

    @ObservationIgnored
    private let updater: LiveParsePluginUpdater

    /// 网络请求超时时间（秒）
    @ObservationIgnored
    private let fetchTimeoutSeconds: UInt64 = 30

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
        // 同步到 CloudKit
        let urls = sourceURLs
        Task {
            await PluginSourceSyncService.syncToCloudStatic(sourceURLs: urls)
        }
    }

    public func addSource(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sourceURLs.contains(trimmed) else { return }
        sourceURLs.append(trimmed)
        sourcePluginIds[trimmed] = sourcePluginIds[trimmed] ?? Set<String>()
        saveSourceURLs()
    }

    public func removeSource(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceURLs.removeAll { $0 == trimmed }
        sourcePluginIds.removeValue(forKey: trimmed)
        saveSourceURLs()
    }

    /// 删除订阅源并移除该源对应的已安装插件
    public func removeSourceAndAssociatedPlugins(_ urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var pluginIds = sourcePluginIds[trimmed] ?? Set<String>()
        if pluginIds.isEmpty, let url = URL(string: trimmed) {
            do {
                let index = try await fetchIndexWithTimeout(url: url)
                pluginIds = Set(index.plugins.map(\.pluginId))
            } catch {
                // 删除订阅源时仍然继续，避免卡住 UI
            }
        }

        removeSource(trimmed)

        for pluginId in pluginIds {
            _ = uninstallPlugin(pluginId: pluginId)
        }
    }

    // MARK: - 拉取远程索引

    public func fetchIndex(from urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            errorMessage = "无效的 URL"
            return
        }

        isFetchingIndex = true
        errorMessage = nil
        defer { isFetchingIndex = false }

        do {
            let index = try await fetchIndexWithTimeout(url: url)
            sourcePluginIds[trimmed] = Set(index.plugins.map(\.pluginId))
            remotePlugins = index.plugins.map { item in
                let displayItem = RemotePluginDisplayItem(item: item)
                if installedVersion(for: item.pluginId) != nil {
                    displayItem.installState = .installed
                }
                return displayItem
            }
            mergeLatestRemoteItems(index.plugins)
        } catch {
            errorMessage = "拉取插件索引失败: \(error.localizedDescription)"
        }
    }

    /// 从所有订阅源检查可更新版本
    public func refreshAvailableUpdates() async {
        guard !sourceURLs.isEmpty else {
            latestRemoteItemsByPluginId = [:]
            sourcePluginIds = [:]
            return
        }

        errorMessage = nil
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        var latest: [String: LiveParseRemotePluginItem] = [:]
        var pluginIdsBySource = sourcePluginIds.filter { sourceURLs.contains($0.key) }

        for source in sourceURLs {
            guard let url = URL(string: source) else { continue }
            do {
                let index = try await fetchIndexWithTimeout(url: url)
                pluginIdsBySource[source] = Set(index.plugins.map(\.pluginId))
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
        sourcePluginIds = pluginIdsBySource
    }

    // MARK: - 安装插件

    /// 从所有已添加的订阅源拉取索引并合并到 remotePlugins（不覆盖，按 pluginId 去重）
    public func fetchAllSourceIndexes() async {
        isFetchingIndex = true
        errorMessage = nil
        defer { isFetchingIndex = false }

        var allItems: [LiveParseRemotePluginItem] = []
        var seenPluginIds = Set<String>()

        for source in sourceURLs {
            guard let url = URL(string: source) else { continue }
            do {
                let index = try await fetchIndexWithTimeout(url: url)
                sourcePluginIds[source] = Set(index.plugins.map(\.pluginId))
                for item in index.plugins {
                    if !seenPluginIds.contains(item.pluginId) {
                        seenPluginIds.insert(item.pluginId)
                        allItems.append(item)
                    }
                }
                mergeLatestRemoteItems(index.plugins)
            } catch {
                errorMessage = "拉取插件索引失败: \(error.localizedDescription)"
            }
        }

        remotePlugins = allItems.map { item in
            let displayItem = RemotePluginDisplayItem(item: item)
            if installedVersion(for: item.pluginId) != nil {
                displayItem.installState = .installed
            }
            return displayItem
        }
    }

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
            Logger.error(
                error,
                message: "安装插件失败: \(displayItem.id)@\(displayItem.item.version)",
                category: .general
            )
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
            if let remoteItem = remotePlugins.first(where: { $0.id == pluginId }) {
                remoteItem.installState = .installed
            }
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

    private func uninstallPlugin(pluginId: String) -> Bool {
        let storage = LiveParsePlugins.shared.storage
        let pluginDirectory = storage.pluginDirectory(pluginId: pluginId)

        // 1. 先从内存中驱逐插件，防止卸载过程中被调用
        LiveParsePlugins.shared.evict(pluginId: pluginId)

        // 2. 先更新持久化状态（标记移除），确保即使后续步骤崩溃，
        //    重启后也不会再加载该插件
        do {
            var state = storage.loadState()
            state.plugins.removeValue(forKey: pluginId)
            try storage.saveState(state)
        } catch {
            errorMessage = "删除插件状态失败: \(error.localizedDescription)"
            Logger.error(error, message: "Failed to update state for plugin uninstall: \(pluginId)", category: .plugin)
            return false
        }

        // 3. 删除文件（状态已安全，文件删除失败不影响一致性）
        do {
            if FileManager.default.fileExists(atPath: pluginDirectory.path) {
                try FileManager.default.removeItem(at: pluginDirectory)
            }
        } catch {
            Logger.warning("Failed to delete plugin files for \(pluginId): \(error.localizedDescription)", category: .plugin)
            // 文件删除失败不视为致命错误，状态已正确更新
        }

        // 4. 刷新运行时
        try? LiveParsePlugins.shared.reload()
        PlatformCapability.invalidateCache()

        if let item = remotePlugins.first(where: { $0.id == pluginId }) {
            item.installState = .notInstalled
        }
        return true
    }

    // MARK: - Timeout Helper

    private func fetchIndexWithTimeout(url: URL) async throws -> LiveParseRemotePluginIndex {
        let timeout = fetchTimeoutSeconds
        let localUpdater = updater
        return try await withThrowingTaskGroup(of: LiveParseRemotePluginIndex.self) { group in
            group.addTask {
                try await localUpdater.fetchIndex(url: url)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeout * 1_000_000_000)
                throw URLError(.timedOut)
            }
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            group.cancelAll()
            return result
        }
    }

}
