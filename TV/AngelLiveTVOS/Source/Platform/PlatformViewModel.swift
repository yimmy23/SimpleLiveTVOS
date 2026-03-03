//
//  PlatformViewModel.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2024/6/14.
//

import Foundation
import Observation
import SwiftUI
import AngelLiveDependencies
import AngelLiveCore

@Observable
class PlatformViewModel {
    var platformInfo: [Platformdescription] = []

    init() {}

    func refreshPlatforms(installedPluginIds: [String]) {
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


struct Platformdescription {
    let title: String
    let bigPic: String
    let smallPic: String
    let descripiton: String
    let liveType: LiveType
}
