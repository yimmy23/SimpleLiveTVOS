//
//  PlatformIconProvider.swift
//  AngelLive
//
//  统一解析平台图标：只读取沙盒已安装插件 assets，不读取 LiveParse 内置资源。
//

import UIKit
import AngelLiveCore

enum PlatformIconProvider {
    private static let installedCardIconPrefix = "assets/tv_"
    private static let installedTabIconPrefix = "assets/live_card_"
    private static let installedListIconPrefix = "assets/pad_live_card_"

    /// 内存缓存：避免滚动时反复进行磁盘 I/O
    private static var tabImageCache: [String: UIImage] = [:]
    private static var cardImageCache: [String: UIImage] = [:]
    private static var listImageCache: [String: UIImage] = [:]

    /// 清除缓存（插件更新后调用）
    static func clearCache() {
        tabImageCache.removeAll()
        cardImageCache.removeAll()
        listImageCache.removeAll()
    }

    static func tabImage(for liveType: LiveType) -> UIImage? {
        let cacheKey = liveType.rawValue
        if let cached = tabImageCache[cacheKey] {
            return cached
        }

        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: installedTabIconPrefix + pluginId) {
            let normalizedImage = normalizedTabImage(installedImage)
            tabImageCache[cacheKey] = normalizedImage
            return normalizedImage
        }

        let legacyImage = legacyTabImage(liveType: liveType)
        if let legacyImage {
            let normalizedImage = normalizedTabImage(legacyImage)
            tabImageCache[cacheKey] = normalizedImage
            return normalizedImage
        }
        return nil
    }

    static func configCardImage(for liveType: LiveType, isDarkMode: Bool) -> UIImage? {
        let cacheKey = "\(liveType.rawValue)_\(isDarkMode)"
        if let cached = cardImageCache[cacheKey] {
            return cached
        }

        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId
        let primaryName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big_dark" : "_big")
        let fallbackName = installedCardIconPrefix + pluginId + (isDarkMode ? "_big" : "_big_dark")

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: primaryName)
            ?? loadInstalledIcon(pluginId: pluginId, fileName: fallbackName) {
            cardImageCache[cacheKey] = installedImage
            return installedImage
        }

        let legacyImage = legacyCardImage(liveType: liveType, isDarkMode: isDarkMode)
        if let legacyImage {
            cardImageCache[cacheKey] = legacyImage
        }
        return legacyImage
    }

    static func pluginManagementImage(for liveType: LiveType) -> UIImage? {
        let cacheKey = liveType.rawValue
        if let cached = listImageCache[cacheKey] {
            return cached
        }

        guard let platform = SandboxPluginCatalog.platform(for: liveType) else {
            return nil
        }
        let pluginId = platform.pluginId

        if let installedImage = loadInstalledIcon(pluginId: pluginId, fileName: installedListIconPrefix + pluginId) {
            listImageCache[cacheKey] = installedImage
            return installedImage
        }

        let legacyImage = legacyListImage(liveType: liveType)
        if let legacyImage {
            listImageCache[cacheKey] = legacyImage
        }
        return legacyImage
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
            LiveType.bilibili.rawValue: "live_card_bilibili",
            LiveType.douyu.rawValue: "live_card_douyu",
            LiveType.huya.rawValue: "live_card_huya",
            LiveType.douyin.rawValue: "live_card_douyin",
            LiveType.yy.rawValue: "live_card_yy",
            LiveType.cc.rawValue: "live_card_cc",
            LiveType.ks.rawValue: "live_card_ks",
            LiveType.soop.rawValue: "live_card_soop",
            LiveType.youtube.rawValue: "live_card_youtube"
        ]
        let legacyName = legacyNameByType[liveType.rawValue] ?? "live_card_bilibili"

        return UIImage(named: legacyName)
    }

    private static func normalizedTabImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let targetPoints: CGFloat = 25
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let scale = max(pixelWidth, pixelHeight) / targetPoints

        guard scale.isFinite, scale > 0 else { return image }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
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

    private static func legacyListImage(liveType: LiveType) -> UIImage? {
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

}
