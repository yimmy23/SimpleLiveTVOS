//
//  SettingView.swift
//  AngelLiveMacOS
//
//  Created by pc on 11/11/25.
//  Supported by AI助手Claude
//

import SwiftUI
import AngelLiveCore

struct SettingView: View {
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @Environment(PluginAvailabilityService.self) private var pluginAvailability
    @Environment(HistoryModel.self) private var historyModel

    @State private var showOpenSourceList = false
    @State private var showPluginManagement = false
    @State private var showHistory = false
    @State private var showDanmuSetting = false
    @State private var showAccountManagement = false
    @State private var showSyncManagement = false

    var body: some View {
        Form {
            if pluginAvailability.hasAvailablePlugins,
               !pluginAvailability.loginRequiredInstalledPluginIds.isEmpty {
                Section("账号") {
                    accountManagementRow
                }
            }

            if pluginAvailability.hasAvailablePlugins {
                Section {
                    syncManagementRow
                } header: {
                    Text("同步")
                } footer: {
                    Text("使用 iCloud 同步收藏与平台账号登录信息。")
                }
            }

            if pluginAvailability.hasAvailablePlugins {
                Section("插件与扩展") {
                    pluginManagementRow
                }
            }

            Section("数据与记录") {
                historyRow
            }

            Section("播放") {
                danmuSettingRow
            }

            Section("关于与支持") {
                checkUpdateRow
                openSourceRow
                githubRow
            }

            Section {
                Text("AngelLive · macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .sheet(isPresented: $showAccountManagement) {
            NavigationStack {
                MacAccountManagementView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showAccountManagement = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 480)
        }
        .sheet(isPresented: $showSyncManagement) {
            NavigationStack {
                MacSyncManagementView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showSyncManagement = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 520)
        }
        .sheet(isPresented: $showPluginManagement) {
            NavigationStack {
                MacPluginManagementView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showPluginManagement = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 480)
        }
        .sheet(isPresented: $showOpenSourceList) {
            NavigationStack {
                OpenSourceListView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showOpenSourceList = false
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                MacHistoryView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showHistory = false
                            }
                        }
                    }
            }
            .frame(minWidth: 720, minHeight: 520)
        }
        .sheet(isPresented: $showDanmuSetting) {
            NavigationStack {
                MacDanmuSettingView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showDanmuSetting = false
                            }
                        }
                    }
            }
            .frame(minWidth: 640, minHeight: 560)
        }
    }

    private var accountManagementRow: some View {
        Button {
            showAccountManagement = true
        } label: {
            PanelNavigationRow(
                title: "账号管理",
                subtitle: "登录、查看与切换平台账号"
            ) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue.gradient)
            }
        }
        .buttonStyle(.plain)
    }

    private var syncManagementRow: some View {
        Button {
            showSyncManagement = true
        } label: {
            PanelNavigationRow(
                title: "同步管理",
                subtitle: "iCloud 自动同步、手动上传/下载"
            ) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.cyan.gradient)
            }
        }
        .buttonStyle(.plain)
    }

    private var pluginManagementRow: some View {
        Button {
            showPluginManagement = true
        } label: {
            PanelNavigationRow(
                title: "插件管理",
                subtitle: "统一管理订阅源、安装状态和版本更新"
            ) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.orange.gradient)
            } trailing: {
                PanelStatusBadge(pluginAvailability.hasAvailablePlugins ? "已启用" : "未启用", tint: .orange)
            }
        }
        .buttonStyle(.plain)
    }

    private var historyRow: some View {
        Button {
            showHistory = true
        } label: {
            PanelNavigationRow(
                title: "历史记录",
                subtitle: "查看最近播放过的直播间"
            ) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.indigo.gradient)
            } trailing: {
                if !historyModel.watchList.isEmpty {
                    PanelStatusBadge("\(historyModel.watchList.count)", tint: .indigo)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var danmuSettingRow: some View {
        Button {
            showDanmuSetting = true
        } label: {
            PanelNavigationRow(
                title: "弹幕设置",
                subtitle: "显示、字体、速度和区域"
            ) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppConstants.Colors.success.gradient)
            }
        }
        .buttonStyle(.plain)
    }

    private var checkUpdateRow: some View {
        Button {
            updaterViewModel.checkForUpdates()
        } label: {
            PanelNavigationRow(
                title: "检查更新",
                subtitle: updaterViewModel.canCheckForUpdates ? "查看新版本与更新说明" : "当前无法发起更新检查"
            ) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor.gradient)
            } trailing: {
                if !updaterViewModel.canCheckForUpdates {
                    PanelStatusBadge("不可用")
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!updaterViewModel.canCheckForUpdates)
    }

    private var openSourceRow: some View {
        Button {
            showOpenSourceList = true
        } label: {
            PanelNavigationRow(
                title: "开源许可",
                subtitle: "查看第三方依赖与授权信息"
            ) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue.gradient)
            }
        }
        .buttonStyle(.plain)
    }

    private var githubRow: some View {
        Link(destination: URL(string: "https://github.com/pcccccc/AngelLive")!) {
            PanelNavigationRow(
                title: "访问 GitHub",
                subtitle: "项目主页、问题反馈与更新记录",
                showsChevron: false
            ) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.purple.gradient)
            } trailing: {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

}

private struct MacHistoryView: View {
    @Environment(HistoryModel.self) private var historyModel
    @State private var showClearAlert = false

    var body: some View {
        GeometryReader { geometry in
            if historyModel.watchList.isEmpty {
                ErrorView.empty(
                    title: "暂无历史记录",
                    message: "开始播放直播间后，会自动记录在这里。",
                    symbolName: "clock.arrow.circlepath",
                    tint: .secondary
                )
            } else {
                ScrollView {
                    historyGridView(geometry: geometry)
                }
            }
        }
        .navigationTitle("历史记录")
        .toolbar {
            if !historyModel.watchList.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("清空") {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("清空历史记录", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                historyModel.clearAll()
            }
        } message: {
            Text("确定要清空所有历史记录吗？")
        }
    }

    @ViewBuilder
    private func historyGridView(geometry: GeometryProxy) -> some View {
        let horizontalSpacing: CGFloat = 15
        let verticalSpacing: CGFloat = 24
        let horizontalPadding: CGFloat = 20

        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 180, maximum: 260), spacing: horizontalSpacing)
            ],
            spacing: verticalSpacing
        ) {
            ForEach(historyModel.watchList, id: \.roomId) { room in
                HistoryRoomCardButton(room: room) {
                    LiveRoomCard(room: room, showsCoverBadge: true)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        historyModel.removeHistory(room: room)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 16)
    }
}

/// 历史记录专用卡片按钮 - 先异步查询直播状态，再决定是否打开播放器
private struct HistoryRoomCardButton<Content: View>: View {
    let room: LiveModel
    let content: Content
    @Environment(\.openWindow) private var openWindow
    @Environment(FullscreenPlayerManager.self) private var fullscreenPlayerManager
    @Environment(ToastManager.self) private var toastManager
    @State private var isChecking = false

    init(room: LiveModel, @ViewBuilder content: () -> Content) {
        self.room = room
        self.content = content()
    }

    var body: some View {
        Button {
            guard !isChecking else { return }
            Task {
                isChecking = true
                defer { isChecking = false }
                do {
                    let state = try await ApiManager.getCurrentRoomLiveState(
                        roomId: room.roomId,
                        userId: room.userId,
                        liveType: room.liveType
                    )
                    if state == .live {
                        fullscreenPlayerManager.openRoom(room, openWindow: openWindow)
                    } else {
                        toastManager.show(icon: "tv.slash", message: "主播已下播")
                    }
                } catch {
                    // 查询失败时仍然放行，让播放页自行处理错误
                    fullscreenPlayerManager.openRoom(room, openWindow: openWindow)
                }
            }
        } label: {
            content
                .overlay {
                    if isChecking {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.3))
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct MacDanmuSettingView: View {
    @State private var danmuModel = DanmuSettingModel()

    var body: some View {
        List {
            Section {
                Toggle("开启弹幕", isOn: $danmuModel.showDanmu)
                    .tint(AppConstants.Colors.accent)

                Toggle("开启彩色弹幕", isOn: $danmuModel.showColorDanmu)
                    .tint(AppConstants.Colors.accent)
            } header: {
                Text("基本设置")
            }

            Section {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
                    HStack {
                        Text("字体大小")
                            .foregroundStyle(AppConstants.Colors.primaryText)
                        Spacer()
                        Text("\(danmuModel.danmuFontSize)")
                            .foregroundStyle(AppConstants.Colors.secondaryText)
                    }

                    HStack(spacing: AppConstants.Spacing.md) {
                        Button {
                            if danmuModel.danmuFontSize > 15 {
                                danmuModel.danmuFontSize -= 5
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppConstants.Colors.error.gradient)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            if danmuModel.danmuFontSize > 10 {
                                danmuModel.danmuFontSize -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundStyle(AppConstants.Colors.warning.gradient)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("这是测试弹幕")
                            .font(.system(size: CGFloat(danmuModel.danmuFontSize)))
                            .foregroundStyle(AppConstants.Colors.primaryText)

                        Spacer()

                        Button {
                            if danmuModel.danmuFontSize < 100 {
                                danmuModel.danmuFontSize += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .foregroundStyle(AppConstants.Colors.success.gradient)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            if danmuModel.danmuFontSize < 95 {
                                danmuModel.danmuFontSize += 5
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppConstants.Colors.link.gradient)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, AppConstants.Spacing.sm)
            } header: {
                Text("字体设置")
            }

            Section {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
                    HStack {
                        Text("透明度")
                        Spacer()
                        Text(String(format: "%.1f", danmuModel.danmuAlpha))
                            .foregroundStyle(AppConstants.Colors.secondaryText)
                    }

                    Slider(value: $danmuModel.danmuAlpha, in: 0.1...1.0, step: 0.1)
                        .tint(AppConstants.Colors.link)
                }

                Picker("弹幕速度", selection: $danmuModel.danmuSpeedIndex) {
                    ForEach(DanmuSettingModel.danmuSpeedArray.indices, id: \.self) { index in
                        Text(DanmuSettingModel.danmuSpeedArray[index])
                            .tag(index)
                    }
                }
                .onChange(of: danmuModel.danmuSpeedIndex) { _, newValue in
                    danmuModel.getDanmuSpeed(index: newValue)
                }

                Picker("显示区域", selection: $danmuModel.danmuAreaIndex) {
                    ForEach(DanmuSettingModel.danmuAreaArray.indices, id: \.self) { index in
                        Text(DanmuSettingModel.danmuAreaArray[index])
                            .tag(index)
                    }
                }
            } header: {
                Text("显示设置")
            }
        }
        .listStyle(.inset)
        .navigationTitle("弹幕设置")
    }
}

#Preview {
    SettingView()
        .environment(HistoryModel())
        .environmentObject(UpdaterViewModel())
}
