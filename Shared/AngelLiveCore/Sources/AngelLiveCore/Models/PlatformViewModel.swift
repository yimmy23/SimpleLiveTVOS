//
//  PlatformViewModel.swift
//  AngelLiveCore
//
//  Created by pc on 2024/6/14.
//

import Foundation
import Observation
import SwiftUI

@Observable
public final class PlatformViewModel {
    public var platformInfo: [Platformdescription] = []

    public init() {}

    private func normalizedDescription(_ description: String?, liveType: LiveType) -> String {
        let normalized = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalized.isEmpty {
            return normalized
        }
        return LiveParseTools.getLivePlatformDescription(liveType)
    }

    /// 根据已安装插件 ID 刷新平台列表
    public func refreshPlatforms(installedPluginIds: [String]) {
        let platformBaseByType = Dictionary(
            uniqueKeysWithValues: LiveParseTools.getAllSupportPlatform().map { ($0.liveType, $0) }
        )
        let installedPlatforms = SandboxPluginCatalog.availablePlatforms(installedPluginIds: installedPluginIds)

        platformInfo = installedPlatforms.map { platform in
            let fallbackTitle = LiveParseTools.getLivePlatformName(platform.liveType)
            let title = platformBaseByType[platform.liveType]?.livePlatformName ?? fallbackTitle
            let description = normalizedDescription(
                platformBaseByType[platform.liveType]?.description,
                liveType: platform.liveType
            )

            return Platformdescription(
                title: title,
                bigPic: "\(title)-big",
                smallPic: "\(title)-small",
                descripiton: description,
                liveType: platform.liveType
            )
        }
    }
}


public struct Platformdescription: Hashable {
    public let title: String
    public let bigPic: String
    public let smallPic: String
    public let descripiton: String
    public let liveType: LiveType

    public init(title: String, bigPic: String, smallPic: String, descripiton: String, liveType: LiveType) {
        self.title = title
        self.bigPic = bigPic
        self.smallPic = smallPic
        self.descripiton = descripiton
        self.liveType = liveType
    }
}
