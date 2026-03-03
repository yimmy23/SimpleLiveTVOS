//
//  PlatformViewModel.swift
//  AngelLiveCore
//
//  Created by pc on 2024/6/14.
//

import Foundation
import Observation
import SwiftUI
import LiveParse

@Observable
public final class PlatformViewModel {
    public var platformInfo: [Platformdescription] = []

    public init() {}

    /// 根据已安装插件 ID 刷新平台列表
    public func refreshPlatforms(installedPluginIds: [String]) {
        let pluginMap = SandboxPluginCatalog.installedPluginMap()
        let installedPlatforms = SandboxPluginCatalog.availablePlatforms(installedPluginIds: installedPluginIds)

        platformInfo = installedPlatforms.map { platform in
            let manifestName = pluginMap[platform.pluginId]?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (manifestName?.isEmpty == false) ? manifestName! : platform.pluginId
            let description = "由沙盒插件提供"

            return Platformdescription(
                title: title,
                bigPic: "\(platform.pluginId)-big",
                smallPic: "\(platform.pluginId)-small",
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
