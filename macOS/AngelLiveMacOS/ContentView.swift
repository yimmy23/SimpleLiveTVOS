//
//  ContentView.swift
//  AngelLiveMacOS
//
//  Created by pc on 10/17/25.
//  Supported by AI助手Claude
//

import SwiftUI
import AngelLiveCore
import LiveParse

// 定义 Tab 选择类型
enum TabSelection: Hashable {
    case favorite
    case allPlatforms
    case platform(Platformdescription)
    case settings
    case search
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .favorite
    // 首次启动管理器
    @Environment(WelcomeManager.self) private var welcomeManager
    // 从环境获取全局 ViewModels
    @Environment(AppFavoriteModel.self) private var favoriteViewModel
    @Environment(ToastManager.self) private var toastManager
    @Environment(FullscreenPlayerManager.self) private var fullscreenPlayerManager
    // 插件与壳 UI 服务
    @State private var pluginAvailability = PluginAvailabilityService()
    @State private var bookmarkService = StreamBookmarkService()
    @State private var pluginSourceManager = PluginSourceManager()
    // 创建局部 ViewModels
    @State private var platformViewModel = PlatformViewModel()
    @State private var searchViewModel = SearchViewModel()

    var body: some View {
        @Bindable var manager = welcomeManager

        Group {
            if fullscreenPlayerManager.showFullscreenPlayer,
               let room = fullscreenPlayerManager.currentRoom {
                // 全屏播放器
                RoomPlayerView(room: room)
                    .background(Color.black)
            } else {
                // 正常内容
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        Tab(value: TabSelection.favorite) {
                            if pluginAvailability.hasAvailablePlugins {
                                FavoriteView()
                            } else {
                                MacShellFavoriteView()
                            }
                        } label: {
                            Label("收藏", systemImage: "heart.fill")
                        }

                        TabSection("平台") {
                            if !pluginAvailability.hasAvailablePlugins {
                                Tab(value: TabSelection.allPlatforms) {
                                    MacShellConfigView()
                                } label: {
                                    Label("配置", systemImage: "square.grid.2x2.fill")
                                }
                            }

                            if pluginAvailability.hasAvailablePlugins {
                                ForEach(platformViewModel.platformInfo, id: \.liveType) { platform in
                                    Tab(value: TabSelection.platform(platform)) {
                                        PlatformDetailTab(platform: platform)
                                    } label: {
                                        Label {
                                            Text(platform.title)
                                        } icon: {
                                            if let icon = MacPlatformIconProvider.tabImage(for: platform.liveType) {
                                                Image(nsImage: icon)
                                            } else {
                                                Image(systemName: "puzzlepiece.extension")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if pluginAvailability.hasAvailablePlugins {
                            // macOS 26+ 支持 search role，macOS 15 需要普通 Tab
                            if #available(macOS 26.0, *) {
                                Tab("搜索", systemImage: "magnifyingglass", value: TabSelection.search, role: .search) {
                                    SearchView()
                                }
                            } else {
                                Tab(value: TabSelection.search) {
                                    SearchView()
                                } label: {
                                    Label("搜索", systemImage: "magnifyingglass")
                                }
                            }
                        }

                        Tab("设置", systemImage: "gearshape.fill", value: TabSelection.settings) {
                            SettingView()
                        }
                    }
                    .tabViewStyle(.sidebarAdaptable)
                    .navigationDestination(for: LiveModel.self) { room in
                        RoomPlayerView(room: room)
                    }
                    .sheet(isPresented: $manager.showWelcome) {
                        WelcomeView {
                            welcomeManager.completeWelcome()
                        }
                        .presentationSizing(.page.fitted(horizontal: true, vertical: false))
                    }
                }
            }
        }
        .environment(platformViewModel)
        .environment(favoriteViewModel)
        .environment(searchViewModel)
        .environment(pluginAvailability)
        .environment(bookmarkService)
        .environment(pluginSourceManager)
        .environment(toastManager)
        .environment(fullscreenPlayerManager)
        .task {
            await pluginAvailability.checkAvailability()
            platformViewModel.refreshPlatforms(installedPluginIds: pluginAvailability.installedPluginIds)
        }
        .onChange(of: pluginAvailability.installedPluginIds) { _, installedPluginIds in
            platformViewModel.refreshPlatforms(installedPluginIds: installedPluginIds)
            if installedPluginIds.isEmpty {
                if case .platform = selectedTab {
                    selectedTab = .allPlatforms
                } else if selectedTab == .search {
                    selectedTab = .favorite
                }
            } else if selectedTab == .allPlatforms,
                      let firstPlatform = platformViewModel.platformInfo.first {
                selectedTab = .platform(firstPlatform)
            }
        }
        .overlay(alignment: .top) {
            if let toast = toastManager.currentToast, !fullscreenPlayerManager.showFullscreenPlayer {
                ToastView(toast: toast)
                    .padding(.top, 16)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: toastManager.currentToast)
    }
}

struct PlatformDetailTab: View {
    let platform: Platformdescription
    @State private var viewModel: PlatformDetailViewModel

    init(platform: Platformdescription) {
        self.platform = platform
        _viewModel = State(initialValue: PlatformDetailViewModel(platform: platform))
    }

    var body: some View {
        PlatformDetailView()
            .environment(viewModel)
    }
}

#Preview {
    ContentView()
}
