//
//  ContentView.swift
//  AngelLive
//
//  Created by pangchong on 10/17/25.
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // 首次启动管理器
    @Environment(WelcomeManager.self) private var welcomeManager

    // 插件检测服务
    @State private var pluginAvailability = PluginAvailabilityService()

    // 壳 UI 服务
    @State private var bookmarkService = StreamBookmarkService()
    @State private var pluginSourceManager = PluginSourceManager()
    @State private var shellHistoryService = ShellHistoryService()

    // 创建全局 ViewModels
    @State private var platformViewModel = PlatformViewModel()
    @State private var favoriteViewModel = AppFavoriteModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var historyViewModel = HistoryModel()

    // 触觉反馈生成器
    private let hapticFeedback = UISelectionFeedbackGenerator()

    // 动态获取 TabSection 标题
    private var platformSectionTitle: String {
        if case .platform(let platform) = selectedTab {
            return platform.title
        }
        return "配置"
    }

    var body: some View {
        @Bindable var manager = welcomeManager

        Group {
            if #available(iOS 18.0, *) {
                if AppConstants.Device.isIPad {
                    iPadTabView
                } else {
                    iPhoneTabView
                }
            } else {
                if AppConstants.Device.isIPad {
                    iOS17iPadTabView
                } else {
                    iOS17iPhoneTabView
                }
            }
        }
        .environment(pluginAvailability)
        .environment(bookmarkService)
        .environment(pluginSourceManager)
        .environment(shellHistoryService)
        .environment(platformViewModel)
        .environment(favoriteViewModel)
        .environment(searchViewModel)
        .environment(historyViewModel)
        .onChange(of: selectedTab) { _, newValue in
            hapticFeedback.selectionChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToSettings)) { _ in
            selectedTab = .settings
        }
        .sheet(isPresented: $manager.showWelcome) {
            WelcomeView {
                welcomeManager.completeWelcome()
            }
            .modifier(WelcomePresentationModifier())
        }
        .task {
            await pluginAvailability.checkAvailability()
        }
        // 插件状态变化时刷新平台列表
        .onChange(of: pluginAvailability.installedPluginIds) { _, newIds in
            platformViewModel.refreshPlatforms(installedPluginIds: newIds)
            if newIds.isEmpty, selectedTab == .search {
                selectedTab = .favorite
            }
        }
    }

    // MARK: - iPad TabView (iOS 18+)

    @available(iOS 18.0, *)
    private var iPadTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(value: TabSelection.favorite) {
                AdaptiveFavoriteView()
            } label: {
                Label {
                    Text("收藏")
                } icon: {
                    CloudSyncTabIcon(syncStatus: favoriteViewModel.syncStatus)
                }
            }

            TabSection(platformSectionTitle) {
                Tab(value: TabSelection.allPlatforms) {
                    AdaptivePlatformView()
                } label: {
                    Label {
                        Text("全部配置")
                    } icon: {
                        Image(systemName: "square.grid.2x2.fill")
                            .resizable()
                            .frame(width: 25, height: 25)
                    }
                }

                ForEach(platformViewModel.platformInfo) { platform in
                    Tab(value: TabSelection.platform(platform)) {
                        PlatformDetailTabContainer(platform: platform)
                    } label: {
                        Label {
                            Text(platform.title)
                        } icon: {
                            if let image = PlatformIconProvider.tabImage(for: platform.liveType) {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 25, height: 25)
                            } else {
                                Image(systemName: "play.tv")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                            }

                        }
                    }
                }
            }

            if pluginAvailability.hasAvailablePlugins {
                // iOS 26+ 支持 search role，iOS 18 需要普通 Tab
                if #available(iOS 26.0, *) {
                    Tab("搜索", systemImage: "magnifyingglass", value: TabSelection.search, role: .search) {
                        AdaptiveSearchView()
                    }
                } else {
                    Tab(value: TabSelection.search) {
                        AdaptiveSearchView()
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
    }

    // MARK: - iPhone TabView (iOS 18+)

    @available(iOS 18.0, *)
    private var iPhoneTabView: some View {
        if #available(iOS 26.0, *) {
            return TabView(selection: $selectedTab) {
                Tab(value: TabSelection.favorite) {
                    AdaptiveFavoriteView()
                } label: {
                    Label {
                        Text("收藏")
                    } icon: {
                        CloudSyncTabIcon(syncStatus: favoriteViewModel.syncStatus)
                    }
                }

                Tab("配置", systemImage: "square.grid.2x2.fill", value: TabSelection.allPlatforms) {
                    AdaptivePlatformView()
                }

                if pluginAvailability.hasAvailablePlugins {
                    Tab("搜索", systemImage: "magnifyingglass", value: TabSelection.search, role: .search) {
                        AdaptiveSearchView()
                    }
                }

                Tab("设置", systemImage: "gearshape.fill", value: TabSelection.settings) {
                    SettingView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
        } else {
           return TabView(selection: $selectedTab) {
                Tab(value: TabSelection.favorite) {
                    AdaptiveFavoriteView()
                } label: {
                    Label {
                        Text("收藏")
                    } icon: {
                        CloudSyncTabIcon(syncStatus: favoriteViewModel.syncStatus)
                    }
                }

                Tab("配置", systemImage: "square.grid.2x2.fill", value: TabSelection.allPlatforms) {
                    AdaptivePlatformView()
                }

                if pluginAvailability.hasAvailablePlugins {
                    // iOS 18 不支持 search role
                    Tab(value: TabSelection.search) {
                        AdaptiveSearchView()
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                }

                Tab("设置", systemImage: "gearshape.fill", value: TabSelection.settings) {
                    SettingView()
                }
            }
        }
    }

    // MARK: - iOS 17 兼容版本

    // iPad iOS 17 TabView
    private var iOS17iPadTabView: some View {
        TabView(selection: $selectedTab) {
            AdaptiveFavoriteView()
                .tabItem {
                    Label {
                        Text("收藏")
                    } icon: {
                        CloudSyncTabIcon(syncStatus: favoriteViewModel.syncStatus)
                    }
                }
                .tag(TabSelection.favorite)

            AdaptivePlatformView()
                .tabItem {
                    Label("配置", systemImage: "square.grid.2x2.fill")
                }
                .tag(TabSelection.allPlatforms)

            if pluginAvailability.hasAvailablePlugins {
                AdaptiveSearchView()
                    .tabItem {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    .tag(TabSelection.search)
            }

            SettingView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(TabSelection.settings)
        }
    }

    // iPhone iOS 17 TabView
    private var iOS17iPhoneTabView: some View {
        TabView(selection: $selectedTab) {
            AdaptiveFavoriteView()
                .tabItem {
                    Label {
                        Text("收藏")
                    } icon: {
                        CloudSyncTabIcon(syncStatus: favoriteViewModel.syncStatus)
                    }
                }
                .tag(TabSelection.favorite)

            AdaptivePlatformView()
                .tabItem {
                    Label("配置", systemImage: "square.grid.2x2.fill")
                }
                .tag(TabSelection.allPlatforms)

            if pluginAvailability.hasAvailablePlugins {
                AdaptiveSearchView()
                    .tabItem {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    .tag(TabSelection.search)
            }

            SettingView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(TabSelection.settings)
        }
    }

}

private struct PlatformDetailTabContainer: View {
    let platform: Platformdescription
    @State private var showCapabilitySheet = false

    var body: some View {
        NavigationStack {
            PlatformDetailViewControllerWrapper()
                .environment(PlatformDetailViewModel(platform: platform))
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(platform.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCapabilitySheet = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
        }
        .sheet(isPresented: $showCapabilitySheet) {
            PlatformCapabilitySheet(liveType: platform.liveType)
        }
    }
}

#Preview {
    ContentView()
}
