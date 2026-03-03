//
//  AdaptiveFavoriteView.swift
//  AngelLive
//
//  根据插件安装状态自适应显示完整收藏或壳收藏。
//

import SwiftUI
import AngelLiveCore

struct AdaptiveFavoriteView: View {
    @Environment(PluginAvailabilityService.self) private var pluginAvailability

    var body: some View {
        if pluginAvailability.hasAvailablePlugins {
            FavoriteView()
        } else {
            ShellFavoriteView()
        }
    }
}
