//
//  PlatformIconProvider.swift
//  AngelLive
//
//  统一解析平台图标：优先读取已安装插件 assets，其次读取 LiveParse 内置资源。
//

import UIKit
import LiveParse

enum PlatformIconProvider {
    private static let installedCardIconPrefix = "assets/tv_"
    private static let installedTabIconPrefix = "assets/pad_live_card_"
    private static let builtInCardIconPrefix = "tv_"
    private static let builtInTabIconPrefix = "pad_live_card_"

    static func tabImage(for liveType: LiveType) -> UIImage? {
        guard let platform = LiveParseJSPlatformManager.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: installedTabIconPrefix + pluginId) {
            return installedImage
        }

        if let builtInImage = loadBuiltInIcon(pluginId: pluginId, fileName: builtInTabIconPrefix + pluginId) {
            return builtInImage
        }

        return legacyTabImage(liveType: liveType)
    }

    static func configCardImage(for liveType: LiveType, isDarkMode: Bool) -> UIImage? {
        guard let platform = LiveParseJSPlatformManager.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId
        let primaryName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big_dark" : "_big")
        let fallbackName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big" : "_big_dark")

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: primaryName)
            ?? loadInstalledIcon(pluginId: pluginId, fileName: fallbackName) {
            return installedImage
        }

        let builtInPrimary = builtInCardIconPrefix + pluginId + (isDarkMode ? "_big_dark" : "_big")
        let builtInFallback = builtInCardIconPrefix + pluginId + (isDarkMode ? "_big" : "_big_dark")
        if let builtInImage = loadBuiltInIcon(pluginId: pluginId, fileName: builtInPrimary)
            ?? loadBuiltInIcon(pluginId: pluginId, fileName: builtInFallback) {
            return builtInImage
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

    private static func loadBuiltInIcon(pluginId: String, fileName: String) -> UIImage? {
        let resourceBundle = LiveParsePlugins.shared.bundle
        let iconURL =
            resourceBundle.url(
                forResource: fileName,
                withExtension: "png",
                subdirectory: "plugin_assets/\(pluginId)"
            ) ??
            resourceBundle.url(
                forResource: fileName,
                withExtension: "png"
            )

        if let iconURL {
            return UIImage(contentsOfFile: iconURL.path)
        }
        return nil
    }

    private static func legacyTabImage(liveType: LiveType) -> UIImage? {
        let legacyName: String = switch liveType {
        case .bilibili: "pad_live_card_bili"
        case .douyu: "pad_live_card_douyu"
        case .huya: "pad_live_card_huya"
        case .douyin: "pad_live_card_douyin"
        case .yy: "pad_live_card_yy"
        case .cc: "pad_live_card_cc"
        case .ks: "pad_live_card_ks"
        case .soop: "pad_live_card_soop"
        case .youtube: "pad_live_card_youtube"
        }

        return UIImage(named: legacyName)
    }

    private static func legacyCardImage(liveType: LiveType, isDarkMode: Bool) -> UIImage? {
        let darkSuffix = isDarkMode ? "_dark" : ""
        let legacyName: String = switch liveType {
        case .bilibili: "tv_bilibili_big\(darkSuffix)"
        case .douyu: "tv_douyu_big\(darkSuffix)"
        case .huya: "tv_huya_big\(darkSuffix)"
        case .douyin: "tv_douyin_big\(darkSuffix)"
        case .yy: "tv_yy_big\(darkSuffix)"
        case .cc: "tv_cc_big\(darkSuffix)"
        case .ks: "tv_ks_big\(darkSuffix)"
        case .soop: "tv_soop_big\(darkSuffix)"
        case .youtube: "tv_youtube_big\(darkSuffix)"
        }

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
