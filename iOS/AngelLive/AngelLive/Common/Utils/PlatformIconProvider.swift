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

        let legacyImage = UIImage(named: installedTabIconPrefix.replacingOccurrences(of: "assets/", with: "") + pluginId)
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

        let legacyImage = UIImage(named: primaryName.replacingOccurrences(of: "assets/", with: ""))
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

        let legacyImage = UIImage(named: installedListIconPrefix.replacingOccurrences(of: "assets/", with: "") + pluginId)
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

    private static func normalizedTabImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let targetPoints: CGFloat = 25
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let scale = max(pixelWidth, pixelHeight) / targetPoints

        guard scale.isFinite, scale > 0 else { return image }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }

}
