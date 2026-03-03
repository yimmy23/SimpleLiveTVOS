//
//  PlatformIconProvider.swift
//  AngelLive
//
//  统一解析平台图标：只读取沙盒已安装插件 assets，不读取 LiveParse 内置资源。
//

import UIKit
import AngelLiveCore
import LiveParse

enum PlatformIconProvider {
    private static let installedCardIconPrefix = "assets/tv_"
    private static let installedTabIconPrefix = "assets/mini_live_card_"

    static func tabImage(for liveType: LiveType) -> UIImage? {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: installedTabIconPrefix + pluginId) {
            return installedImage
        }

        return legacyTabImage(liveType: liveType)
    }

    static func configCardImage(for liveType: LiveType, isDarkMode: Bool) -> UIImage? {
        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId
        let primaryName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big_dark" : "_big")
        let fallbackName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big" : "_big_dark")

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: primaryName)
            ?? loadInstalledIcon(pluginId: pluginId, fileName: fallbackName) {
            return installedImage
        }

        return legacyCardImage(liveType: liveType, isDarkMode: isDarkMode)
    }

    private static func loadInstalledIcon(pluginId: String, fileName: String) -> UIImage? {
        let storage = LiveParsePlugins.shared.storage
        let versionDirs = storage.listInstalledVersions(pluginId: pluginId)
            .sorted { semverCompare($0.lastPathComponent, $1.lastPathComponent) > 0 }

        for versionDir in versionDirs {
            let iconURL = versionDir
                .appendingPathComponent(fileName)
                .appendingPathExtension("png")

            if FileManager.default.fileExists(atPath: iconURL.path),
               let image = UIImage(contentsOfFile: iconURL.path) {
                return image
            }
        }

        return nil
    }

    private static func legacyTabImage(liveType: LiveType) -> UIImage? {
        let legacyNameByType: [String: String] = [
            LiveType.bilibili.rawValue: "pad_live_card_bili",
            LiveType.douyu.rawValue: "pad_live_card_douyu",
            LiveType.huya.rawValue: "pad_live_card_huya",
            LiveType.douyin.rawValue: "pad_live_card_douyin",
            LiveType.yy.rawValue: "pad_live_card_yy",
            LiveType.cc.rawValue: "pad_live_card_cc",
            LiveType.ks.rawValue: "pad_live_card_ks",
            LiveType.soop.rawValue: "pad_live_card_soop",
            LiveType.youtube.rawValue: "pad_live_card_youtube"
        ]
        let legacyName = legacyNameByType[liveType.rawValue] ?? "pad_live_card_bili"

        return UIImage(named: legacyName)
    }

    private static func legacyCardImage(liveType: LiveType, isDarkMode: Bool) -> UIImage? {
        let darkSuffix = isDarkMode ? "_dark" : ""
        let legacyNameByType: [String: String] = [
            LiveType.bilibili.rawValue: "tv_bilibili_big\(darkSuffix)",
            LiveType.douyu.rawValue: "tv_douyu_big\(darkSuffix)",
            LiveType.huya.rawValue: "tv_huya_big\(darkSuffix)",
            LiveType.douyin.rawValue: "tv_douyin_big\(darkSuffix)",
            LiveType.yy.rawValue: "tv_yy_big\(darkSuffix)",
            LiveType.cc.rawValue: "tv_cc_big\(darkSuffix)",
            LiveType.ks.rawValue: "tv_ks_big\(darkSuffix)",
            LiveType.soop.rawValue: "tv_soop_big\(darkSuffix)",
            LiveType.youtube.rawValue: "tv_youtube_big\(darkSuffix)"
        ]
        let legacyName = legacyNameByType[liveType.rawValue] ?? "tv_bilibili_big\(darkSuffix)"

        return UIImage(named: legacyName)
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
