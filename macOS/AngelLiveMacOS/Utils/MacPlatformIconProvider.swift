//
//  MacPlatformIconProvider.swift
//  AngelLiveMacOS
//
//  macOS 平台图标读取：优先沙盒插件 assets，失败时返回 nil。
//

import AppKit
import AngelLiveCore
import LiveParse

enum MacPlatformIconProvider {
    private static let tabIconPrefix = "assets/mini_live_card_"

    static func tabImage(for liveType: LiveType) -> NSImage? {
        // 直接按沙盒已安装插件目录匹配 liveType -> pluginId，避免依赖内置资源映射。
        if let pluginId = resolveInstalledPluginId(for: liveType),
           let image = loadInstalledIcon(pluginId: pluginId, fileName: tabIconPrefix + pluginId) {
            return image
        }

        // 兜底：保持与现有平台映射行为一致。
        if let platform = SandboxPluginCatalog.platform(for: liveType) {
            return loadInstalledIcon(pluginId: platform.pluginId, fileName: tabIconPrefix + platform.pluginId)
        }

        return nil
    }

    private static func resolveInstalledPluginId(for liveType: LiveType) -> String? {
        let rawValue = liveType.rawValue

        for (pluginId, metadata) in SandboxPluginCatalog.installedPluginMap() {
            if metadata.liveTypes.contains(rawValue) || metadata.liveTypes.isEmpty && pluginId == rawValue {
                return pluginId
            }
        }

        return nil
    }

    private static func loadInstalledIcon(pluginId: String, fileName: String) -> NSImage? {
        let storage = LiveParsePlugins.shared.storage
        let versionDirs = storage.listInstalledVersions(pluginId: pluginId)
            .sorted { semverCompare($0.lastPathComponent, $1.lastPathComponent) > 0 }

        for versionDir in versionDirs {
            let iconURL = versionDir
                .appendingPathComponent(fileName)
                .appendingPathExtension("png")
            if FileManager.default.fileExists(atPath: iconURL.path),
               let image = NSImage(contentsOf: iconURL) {
                // 强制设定逻辑尺寸为 16pt，让 sidebar tab 以正确大小渲染
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        }

        return nil
    }

}
