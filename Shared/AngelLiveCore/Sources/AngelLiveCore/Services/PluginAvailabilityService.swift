//
//  PluginAvailabilityService.swift
//  AngelLiveCore
//
//  检测 sandbox 中是否有用户安装的远程 LiveParse JS 插件。
//  只检查 sandbox（用户安装的），不检查 builtIn（bundle 内置的）。
//  根据检测结果决定显示完整 UI 还是壳 UI。
//

import Foundation
import Observation
import LiveParse

@Observable
public final class PluginAvailabilityService {

    /// sandbox 中是否有已安装的插件
    public private(set) var hasAvailablePlugins: Bool = false

    /// 已安装插件的 pluginId 列表（如 ["bilibili", "douyu", "huya"]）
    public private(set) var installedPluginIds: [String] = []

    /// 当前正在检测中
    public private(set) var isChecking: Bool = false

    public init() {}

    /// 检测 sandbox 目录下是否有任何已安装的插件
    @MainActor
    public func checkAvailability() async {
        isChecking = true
        defer { isChecking = false }

        let storage = LiveParsePlugins.shared.storage
        let pluginsRoot = storage.pluginsRootDirectory

        // 直接检查 sandbox 插件目录是否有内容
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: pluginsRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            // 收集子目录名（即 pluginId）
            var pluginIds: [String] = []
            for url in contents {
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues?.isDirectory == true {
                    pluginIds.append(url.lastPathComponent)
                }
            }
            installedPluginIds = pluginIds
            hasAvailablePlugins = !pluginIds.isEmpty
        } catch {
            // 目录不存在或无法读取，说明没有安装过任何插件
            installedPluginIds = []
            hasAvailablePlugins = false
        }
    }

    /// 刷新状态（插件安装成功后调用）
    @MainActor
    public func refresh() async {
        // 重新加载插件管理器
        try? LiveParsePlugins.shared.reload()
        await checkAvailability()
    }
}
