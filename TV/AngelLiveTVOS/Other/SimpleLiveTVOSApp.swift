//
//  SimpleLiveTVOSApp.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/6/26.
//

import SwiftUI
import AngelLiveDependencies
import AngelLiveCore
import TipKit

@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
#endif
}

@main
struct SimpleLiveTVOSApp: App {

    var appViewModel = AppState()

    init() {
        // 启动时将 Caches 中的插件同步到 App Group 容器（供 TopShelf 使用）
        PluginAppGroupSync.syncToAppGroup()

        KingfisherManager.shared.defaultOptions += [
            .processor(WebPProcessor.default),
            .cacheSerializer(WebPSerializer.default)
        ]
        Bugsnag.start()

        // 配置 TipKit
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appViewModel: appViewModel)
                .task {
                    // 启动时同步所有平台的 Cookie 到 JS 插件
                    await PlatformSessionLiveParseBridge.syncFromPersistedSessionsOnLaunch()
                    // tvOS 启动时尝试从 iCloud 同步 Cookie
                    if BilibiliCookieSyncService.shared.iCloudSyncEnabled {
                        _ = await BilibiliCookieSyncService.shared.syncFromICloud()
                        await BilibiliCookieSyncService.shared.syncAllPlatformsFromICloud()
                    }
                }
                .onOpenURL { url in
                    appViewModel.handleDeepLink(url: url)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { appViewModel.showDeepLinkPlayer },
                    set: { appViewModel.showDeepLinkPlayer = $0 }
                )) {
                    DeepLinkPlayerView(appViewModel: appViewModel)
                }
        }
    }
}
