//
//  ContentView.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/6/26.
//

import SwiftUI
import GameController
import Network
import Foundation
import Darwin
import AngelLiveDependencies
import AngelLiveCore

struct ContentView: View {
    
    var appViewModel: AppState
    var searchLiveViewModel: LiveViewModel
    var favoriteLiveViewModel: LiveViewModel

    @State private var showPluginSyncPrompt = false

    init(appViewModel: AppState) {
        self.appViewModel = appViewModel
        self.searchLiveViewModel = LiveViewModel(roomListType: .search, liveType: .bilibili, appViewModel: appViewModel)
        self.favoriteLiveViewModel = LiveViewModel(roomListType: .favorite, liveType: .bilibili, appViewModel: appViewModel)
    }
    
    var body: some View {
        
        @Bindable var contentVM = appViewModel
        
        NavigationView {
            TabView(selection:$contentVM.selection) {
                if appViewModel.pluginAvailability.hasAvailablePlugins {
                    FavoriteMainView()
                        .tabItem {
                            if appViewModel.favoriteViewModel.isLoading == true || appViewModel.favoriteViewModel.cloudKitReady == false {
                                Label(
                                    title: {  },
                                    icon: {
                                        Image(systemName: appViewModel.favoriteViewModel.isLoading == true ? "arrow.triangle.2.circlepath.icloud" : appViewModel.favoriteViewModel.cloudKitReady == true ? "checkmark.icloud" : "exclamationmark.icloud" )
                                    }
                                )
                                .contentTransition(.symbolEffect(.replace))
                            } else {
                                Text("收藏")
                            }
                        }
                        .tag(0)
                        .environment(favoriteLiveViewModel)
                        .environment(appViewModel)
                } else {
                    TVShellFavoriteView()
                        .tabItem {
                            Text("收藏")
                        }
                        .tag(0)
                        .environment(appViewModel)
                }
                
                PlatformView()
                    .tabItem {
                        Text("配置")
                    }
                    .tag(1)
                    .environment(appViewModel)

                
                if appViewModel.pluginAvailability.hasAvailablePlugins {
                    SearchRoomView()
                        .tabItem {
                            Text("搜索")
                        }
                        .tag(2)
                        .environment(searchLiveViewModel)
                        .environment(appViewModel)
                }

                
                SettingView()
                    .tabItem {
                        Text("设置")
                    }
                    .tag(3)
                    .environment(appViewModel)

            }
        }
        .onAppear {
            Task {
                // 启动时拉取 key 映射（后台静默，不阻塞 UI）
                Task { await PluginSourceKeyService.shared.fetchKeys() }
                await appViewModel.pluginAvailability.checkAvailability()

                // 自动检查插件更新（静默更新）
                if appViewModel.pluginAvailability.hasAvailablePlugins && !appViewModel.pluginSourceManager.sourceURLs.isEmpty {
                    await appViewModel.pluginSourceManager.refreshAvailableUpdates()
                    let updatableIds = appViewModel.pluginAvailability.installedPluginIds.filter {
                        appViewModel.pluginSourceManager.hasUpdate(for: $0)
                    }
                    if !updatableIds.isEmpty {
                        for id in updatableIds {
                            await appViewModel.pluginSourceManager.updatePlugin(pluginId: id)
                        }
                        await appViewModel.pluginAvailability.refresh()
                    }
                }

                // 无本地插件时，检查 CloudKit 是否有已保存的插件源
                if !appViewModel.pluginAvailability.hasAvailablePlugins {
                    await appViewModel.pluginSourceSyncService.checkCloudForSources()
                    if appViewModel.pluginSourceSyncService.hasSyncedSources {
                        showPluginSyncPrompt = true
                    }
                }
            }
        }
        .alert("检测到云端插件", isPresented: $showPluginSyncPrompt) {
            Button("一键安装") {
                Task {
                    await appViewModel.pluginSourceSyncService.performOneClickInstall(
                        pluginSourceManager: appViewModel.pluginSourceManager,
                        pluginAvailability: appViewModel.pluginAvailability
                    )
                }
            }
            Button("取消", role: .cancel) {
                appViewModel.pluginSourceSyncService.dismissPrompt()
            }
        } message: {
            Text("检测到您已在其他设备安装过插件，是否一键安装？")
        }
        .overlay {
            if appViewModel.pluginSourceSyncService.isInstalling {
                cloudInstallProgressOverlay
            }
        }
        .onPlayPauseCommand(perform: {
            if contentVM.selection == 0 {
                NotificationCenter.default.post(name: SimpleLiveNotificationNames.favoriteRefresh, object: nil)
            }
        })
        .onChange(of: appViewModel.pluginAvailability.installedPluginIds) { oldIds, installedIds in
            // 从无插件变为有插件时，主动触发收藏同步
            if oldIds.isEmpty && !installedIds.isEmpty {
                Task {
                    await appViewModel.favoriteViewModel.syncWithActor()
                }
            }
            if installedIds.isEmpty, contentVM.selection == 2 {
                contentVM.selection = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SimpleLiveNotificationNames.navigateToSettings)) { _ in
            contentVM.selection = 3
        }
        
//        .simpleToast(isPresented: $contentVM.showToast, options: appViewModel.toastOptions) {
//            VStack(alignment: .leading) {
//                Label("提示", systemImage: appViewModel.toastTypeIsSuccess ? "checkmark.circle" : "xmark.circle")
//                    .font(.headline.bold())
//                Text(appViewModel.toastTitle)
//            }
//            .padding()
//            .background(.black.opacity(0.6))
//            .foregroundColor(Color.white)
//            .cornerRadius(10)
//        }
    }

    // MARK: - 云端一键安装进度

    private var cloudInstallProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(2)

                if let message = appViewModel.pluginSourceSyncService.installStatusMessage {
                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                if appViewModel.pluginSourceManager.installTotalCount > 0 {
                    Text("\(appViewModel.pluginSourceManager.installCompletedCount)/\(appViewModel.pluginSourceManager.installTotalCount)")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: appViewModel.pluginSourceSyncService.isInstalling)
    }
}
