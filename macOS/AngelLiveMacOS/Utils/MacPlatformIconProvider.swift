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
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        return loadInstalledIcon(pluginId: platform.pluginId, fileName: tabIconPrefix + platform.pluginId)
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
                return image
            }
        }

        return nil
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
