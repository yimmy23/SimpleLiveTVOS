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
        let allPlatforms = LiveParseTools.getAllSupportPlatform()

        // 使用插件动态映射，不依赖固定平台枚举。
        let installedLiveTypes = Set(
            LiveParseJSPlatformManager.availablePlatforms
                .filter { installedPluginIds.contains($0.pluginId) }
                .map(\.liveType)
        )

        platformInfo = allPlatforms
            .filter { installedLiveTypes.contains($0.liveType) }
            .map { item in
                Platformdescription(
                    title: item.livePlatformName,
                    bigPic: "\(item.livePlatformName)-big",
                    smallPic: "\(item.livePlatformName)-small",
                    descripiton: item.description,
                    liveType: item.liveType
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
