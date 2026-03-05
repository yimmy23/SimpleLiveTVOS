//
//  PlatformViewModel.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2024/6/14.
//

import Foundation
import Observation
import SwiftUI
import UIKit
import AngelLiveDependencies
import AngelLiveCore

@Observable
class PlatformViewModel {
    var platformInfo: [Platformdescription] = []

    init() {}

    func refreshPlatforms(installedPluginIds: [String]) {
        let platformBaseByType = Dictionary(
            uniqueKeysWithValues: LiveParseTools.getAllSupportPlatform().map { ($0.liveType, $0) }
        )
        let installedPlatforms = SandboxPluginCatalog.availablePlatforms(installedPluginIds: installedPluginIds)

        platformInfo = installedPlatforms.map { platform in
            let fallbackTitle = LiveParseTools.getLivePlatformName(platform.liveType)
            let title = platformBaseByType[platform.liveType]?.livePlatformName ?? fallbackTitle
            let description = platformBaseByType[platform.liveType]?.description ?? "由沙盒插件提供"

            return Platformdescription(
                title: title,
                pluginId: platform.pluginId,
                bigPic: "tv_\(platform.pluginId)_big",
                smallPic: "tv_\(platform.pluginId)_small",
                descripiton: description,
                liveType: platform.liveType
            )
        }
    }
}


struct Platformdescription {
    let title: String
    let pluginId: String
    let bigPic: String
    let smallPic: String
    let descripiton: String
    let liveType: LiveType
}

enum TVPlatformIconProvider {
    private static let installedCardIconPrefix = "assets/tv_"
    private static let imageCache = NSCache<NSString, UIImage>()

    static func bigCardImage(for platform: Platformdescription, isDarkMode: Bool) -> UIImage? {
        let primaryName = installedCardIconPrefix + platform.pluginId + (isDarkMode ? "_big_dark" : "_big")
        let fallbackName = installedCardIconPrefix + platform.pluginId + (isDarkMode ? "_big" : "_big_dark")

        if let image = loadInstalledIcon(
            pluginId: platform.pluginId,
            fileNames: [primaryName, fallbackName]
        ) {
            return image
        }

        return UIImage(named: platform.bigPic)
    }

    static func smallCardImage(for platform: Platformdescription, isDarkMode: Bool) -> UIImage? {
        let primaryName = installedCardIconPrefix + platform.pluginId + (isDarkMode ? "_small_dark" : "_small")
        let fallbackName = installedCardIconPrefix + platform.pluginId + (isDarkMode ? "_small" : "_small_dark")

        if let image = loadInstalledIcon(
            pluginId: platform.pluginId,
            fileNames: [primaryName, fallbackName]
        ) {
            return image
        }

        return UIImage(named: platform.smallPic)
    }

    private static func loadInstalledIcon(pluginId: String, fileNames: [String]) -> UIImage? {
        let storage = LiveParsePlugins.shared.storage
        let versionDirs = storage.listInstalledVersions(pluginId: pluginId)
            .sorted { semverCompare($0.lastPathComponent, $1.lastPathComponent) > 0 }

        for versionDir in versionDirs {
            for fileName in fileNames {
                let cacheKey = "\(pluginId)::\(fileName)" as NSString
                if let cached = imageCache.object(forKey: cacheKey) {
                    return cached
                }

                let iconURL = versionDir
                    .appendingPathComponent(fileName)
                    .appendingPathExtension("png")

                if FileManager.default.fileExists(atPath: iconURL.path),
                   let image = UIImage(contentsOfFile: iconURL.path) {
                    imageCache.setObject(image, forKey: cacheKey)
                    return image
                }
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
