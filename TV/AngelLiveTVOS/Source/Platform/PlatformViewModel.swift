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
                bigPic: "\(title)-big",
                smallPic: "\(title)-small",
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
