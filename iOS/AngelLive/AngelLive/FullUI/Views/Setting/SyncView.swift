//
//  SyncView.swift
//  AngelLive
//
//  Created by pangchong on 10/17/25.
//

import SwiftUI
import AngelLiveCore

struct SyncView: View {
    @Environment(AppFavoriteModel.self) var favoriteModel
    @ObservedObject private var syncService = PlatformCredentialSyncService.shared
    @State private var pluginSourceSyncService = PluginSourceSyncService()
    @State private var isSearching = false
    @State private var isSending = false
    @State private var sendResult: String?
    @State private var sendSuccess = false
    @State private var loggedInPlatformNames: [String] = []
    @State private var cloudPluginSourceCount = 0

    // iCloud 确认弹窗状态
    @State private var showUploadConfirm = false
    @State private var showDownloadConfirm = false
    @State private var showClearCloudConfirm = false
    @State private var confirmMessage = ""
    @State private var isFetchingPreview = false
    @State private var isClearingCloudLoginInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppConstants.Spacing.lg) {
                iCloudStatusCard
                syncStatsCard
                syncProgressCard
                loginInfoSyncCard
                lanSyncCard
                accountICloudSyncCard
                sendResultCard
                usageGuideCard
                clearCloudLoginInfoButton

                Spacer(minLength: AppConstants.Spacing.xxl)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("数据同步")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await syncService.refreshAllLoginStatus()
            await loadLoggedInPlatformNames()
            await loadCloudPluginSourceCount()
        }
        .onDisappear {
            syncService.stopBonjourBrowsing()
        }
        .alert("同步到 iCloud", isPresented: $showUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定上传") {
                Task {
                    await syncService.syncAllToICloud()
                    await loadLoggedInPlatformNames()
                    await MainActor.run {
                        sendResult = "已同步到 iCloud"
                        sendSuccess = true
                    }
                }
            }
        } message: {
            Text(confirmMessage)
        }
        .alert("从 iCloud 同步", isPresented: $showDownloadConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定下载") {
                Task {
                    await syncService.syncAllFromICloud()
                    await loadLoggedInPlatformNames()
                    await MainActor.run {
                        sendResult = "已从 iCloud 同步到本地"
                        sendSuccess = true
                    }
                }
            }
        } message: {
            Text(confirmMessage)
        }
        .alert("清理云端登录信息", isPresented: $showClearCloudConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定清理", role: .destructive) {
                Task { await clearCloudLoginInfo() }
            }
        } message: {
            Text("确定要清理 iCloud 中保存的所有平台登录信息吗？此操作不会退出本机账号，但其他设备将无法再从 iCloud 下载这些登录信息。")
        }
    }

    // MARK: - Cards

    private var iCloudStatusCard: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title)
                    .foregroundStyle(statusColor.gradient)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text("iCloud 状态")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.primaryText)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }

                Spacer()
            }
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    private var syncStatsCard: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            Text("同步数据统计")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppConstants.Spacing.md) {
                SyncStatTile(
                    value: "\(favoriteModel.roomList.count)",
                    title: "收藏主播",
                    color: AppConstants.Colors.link
                )

                SyncStatTile(
                    value: "\(loggedInPlatformCount)",
                    title: "已登录平台",
                    color: AppConstants.Colors.warning
                )

                SyncStatTile(
                    value: "\(cloudPluginSourceCount)",
                    title: "订阅源",
                    color: Color.cyan
                )
            }

            if let lastSync = favoriteModel.lastSyncTime {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                    Text("上次同步：\(formatDate(lastSync))")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    @ViewBuilder
    private var syncProgressCard: some View {
        if favoriteModel.syncStatus == .syncing {
            VStack(spacing: AppConstants.Spacing.md) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在同步...")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.primaryText)
                }

                if !favoriteModel.syncProgressInfo.0.isEmpty {
                    VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                        HStack {
                            Text(favoriteModel.syncProgressInfo.0)
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.primaryText)
                                .lineLimit(1)

                            Spacer()

                            Text(favoriteModel.syncProgressInfo.2)
                                .font(.caption)
                                .foregroundStyle(
                                    favoriteModel.syncProgressInfo.2 == "成功" ?
                                    AppConstants.Colors.success :
                                        AppConstants.Colors.error
                                )
                        }

                        Text(favoriteModel.syncProgressInfo.1)
                            .font(.caption2)
                            .foregroundStyle(AppConstants.Colors.secondaryText)

                        ProgressView(
                            value: Double(favoriteModel.syncProgressInfo.3),
                            total: Double(favoriteModel.syncProgressInfo.4)
                        )
                        .tint(AppConstants.Colors.link)
                    }
                }
            }
            .padding()
            .background(AppConstants.Colors.materialBackground)
            .cornerRadius(AppConstants.CornerRadius.lg)
        }
    }

    private var loginInfoSyncCard: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            HStack {
                Image(systemName: hasAnyLogin ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                    .font(.title2)
                    .foregroundStyle(hasAnyLogin ? AppConstants.Colors.success.gradient : AppConstants.Colors.error.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("登录信息同步")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.primaryText)

                    Text(loggedInPlatformSummary)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }

                Spacer()
            }
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    private var accountICloudSyncCard: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            HStack {
                Image(systemName: "icloud.fill")
                    .font(.title2)
                    .foregroundStyle(Color.cyan.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud 同步")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.primaryText)

                    Text("手动上传或下载登录信息")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }

                Spacer()
            }

            if let lastSync = syncService.lastICloudSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                    Text("上次同步: \(PlatformCredentialSyncService.formatSyncTime(lastSync))")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                    Spacer()
                }
            }

            Divider()

            Button {
                Task { await prepareUploadConfirm() }
            } label: {
                ICloudSyncActionRow(
                    title: "同步到 iCloud",
                    subtitle: "上传本地登录信息到云端",
                    isLoading: isFetchingPreview,
                    systemImage: "icloud.and.arrow.up"
                )
            }
            .buttonStyle(.plain)
            .disabled(isFetchingPreview)

            Button {
                Task { await prepareDownloadConfirm() }
            } label: {
                ICloudSyncActionRow(
                    title: "从 iCloud 同步",
                    subtitle: "下载云端登录信息到本地",
                    isLoading: isFetchingPreview,
                    systemImage: "icloud.and.arrow.down"
                )
            }
            .buttonStyle(.plain)
            .disabled(isFetchingPreview)
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    private var clearCloudLoginInfoButton: some View {
        Button {
            showClearCloudConfirm = true
        } label: {
            HStack {
                if isClearingCloudLoginInfo {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(isClearingCloudLoginInfo ? "正在清理..." : "清理云端登录信息")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppConstants.Colors.error.gradient)
            .cornerRadius(AppConstants.CornerRadius.md)
        }
        .disabled(isClearingCloudLoginInfo)
    }

    private var lanSyncCard: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            HStack {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundStyle(Color.blue.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("局域网同步")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.primaryText)

                    Text("搜索同一局域网内的 tvOS 设备")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }

                Spacer()
            }

            Divider()

            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在搜索 tvOS 设备...")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.secondaryText)
                }
                .padding(.vertical, AppConstants.Spacing.sm)
            }

            if !syncService.discoveredDevices.isEmpty {
                VStack(spacing: AppConstants.Spacing.sm) {
                    ForEach(syncService.discoveredDevices) { device in
                        Button {
                            Task {
                                await sendToDevice(device)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "appletv.fill")
                                    .foregroundStyle(Color.purple.gradient)

                                Text(device.name)
                                    .foregroundStyle(AppConstants.Colors.primaryText)

                                Spacer()

                                if isSending {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(AppConstants.Colors.link)
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(AppConstants.CornerRadius.md)
                        }
                        .disabled(isSending)
                    }
                }
            } else if !isSearching {
                Text("未发现 tvOS 设备")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
                    .padding(.vertical, AppConstants.Spacing.sm)
            }

            Button {
                toggleSearch()
            } label: {
                HStack {
                    Image(systemName: isSearching ? "stop.fill" : "magnifyingglass")
                    Text(isSearching ? "停止搜索" : "搜索 tvOS 设备")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSearching ? Color.gray.gradient : AppConstants.Colors.link.gradient)
                .cornerRadius(AppConstants.CornerRadius.md)
            }
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    @ViewBuilder
    private var sendResultCard: some View {
        if let result = sendResult {
            HStack {
                Image(systemName: sendSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(sendSuccess ? AppConstants.Colors.success : AppConstants.Colors.error)
                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(sendSuccess ? AppConstants.Colors.success : AppConstants.Colors.error)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(sendSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(AppConstants.CornerRadius.md)
        }
    }

    private var usageGuideCard: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
            Text("使用说明")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.primaryText)

            VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                Text("Wi-Fi 同步")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.primaryText)

                Label("确保 iPhone/iPad 和 Apple TV 在同一 WiFi 网络", systemImage: "1.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("在 tvOS 设置中打开「账号管理 > 局域网同步」", systemImage: "2.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("在此页面点击搜索并选择 tvOS 设备发送", systemImage: "3.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }

            Divider()

            VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                Text("iCloud 同步")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.primaryText)

                Label("收藏数据会自动同步到 iCloud", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("所有登录同一 iCloud 账号的设备共享收藏", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("下拉收藏页面可快速刷新数据", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("删除收藏后会自动从 iCloud 移除", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)

                Label("登录信息需要在此页面手动上传或下载", systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.link)
            }
        }
        .padding()
        .background(AppConstants.Colors.materialBackground)
        .cornerRadius(AppConstants.CornerRadius.lg)
    }

    // MARK: - Status

    private var statusIcon: String {
        switch favoriteModel.syncStatus {
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.icloud.fill"
        case .error:
            return "exclamationmark.icloud.fill"
        case .notLoggedIn:
            return "xmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        switch favoriteModel.syncStatus {
        case .syncing:
            return AppConstants.Colors.link
        case .success:
            return AppConstants.Colors.success
        case .error:
            return AppConstants.Colors.error
        case .notLoggedIn:
            return AppConstants.Colors.warning
        }
    }

    private var statusText: String {
        switch favoriteModel.syncStatus {
        case .syncing:
            return "正在同步..."
        case .success:
            return "iCloud 已就绪，数据已同步"
        case .error:
            return favoriteModel.cloudKitStateString
        case .notLoggedIn:
            return "未登录 iCloud，请前往系统设置登录"
        }
    }

    private var loggedInPlatformCount: Int {
        let serviceCount = syncService.loggedInByPluginId.values.filter { $0 }.count
        return max(loggedInPlatformNames.count, serviceCount)
    }

    private var hasAnyLogin: Bool {
        loggedInPlatformCount > 0
    }

    private var loggedInPlatformSummary: String {
        if loggedInPlatformNames.isEmpty {
            return "暂无已登录平台"
        }
        return "已登录：\(loggedInPlatformNames.joined(separator: "、"))"
    }

    private func loadLoggedInPlatformNames() async {
        let names = await syncService.getLocalAuthenticatedPlatformNames()
        await MainActor.run {
            loggedInPlatformNames = names
        }
    }

    private func loadCloudPluginSourceCount() async {
        await pluginSourceSyncService.checkCloudForSources()
        cloudPluginSourceCount = pluginSourceSyncService.syncedSourceURLs.count
    }

    // MARK: - iCloud 确认逻辑

    private func prepareUploadConfirm() async {
        isFetchingPreview = true
        defer { isFetchingPreview = false }

        let preview = await syncService.fetchCloudSyncPreview()
        let localNames = await syncService.getLocalAuthenticatedPlatformNames()

        var msg = ""
        if let lastSync = syncService.lastICloudSyncTime {
            msg += "上次同步: \(PlatformCredentialSyncService.formatSyncTime(lastSync))\n"
        }
        if !localNames.isEmpty {
            msg += "本地已登录: \(localNames.joined(separator: "、"))\n"
        } else {
            msg += "本地无已登录平台\n"
        }
        msg += "\n"
        if let cloudTime = preview.latestTime {
            msg += "云端同步时间: \(PlatformCredentialSyncService.formatSyncTime(cloudTime))\n"
            msg += "云端已有平台: \(preview.platformNames.joined(separator: "、"))\n"
            msg += "\n上传后云端数据将被覆盖"
        } else {
            msg += "云端暂无数据"
        }

        confirmMessage = msg
        showUploadConfirm = true
    }

    private func prepareDownloadConfirm() async {
        isFetchingPreview = true
        defer { isFetchingPreview = false }

        let preview = await syncService.fetchCloudSyncPreview()

        guard preview.latestTime != nil else {
            sendResult = "iCloud 中没有同步数据"
            sendSuccess = false
            return
        }

        let localNames = await syncService.getLocalAuthenticatedPlatformNames()

        var msg = ""
        if let lastSync = syncService.lastICloudSyncTime {
            msg += "上次同步: \(PlatformCredentialSyncService.formatSyncTime(lastSync))\n"
        }
        if !localNames.isEmpty {
            msg += "本地已登录: \(localNames.joined(separator: "、"))\n"
        }
        msg += "\n"
        if let cloudTime = preview.latestTime {
            msg += "云端同步时间: \(PlatformCredentialSyncService.formatSyncTime(cloudTime))\n"
        }
        if !preview.platformNames.isEmpty {
            msg += "云端平台: \(preview.platformNames.joined(separator: "、"))\n"
        }
        msg += "\n下载后本地数据将被覆盖"

        confirmMessage = msg
        showDownloadConfirm = true
    }

    // MARK: - Bonjour

    private func toggleSearch() {
        if isSearching {
            syncService.stopBonjourBrowsing()
            isSearching = false
        } else {
            syncService.startBonjourBrowsing()
            isSearching = true
        }
    }

    private func sendToDevice(_ device: PlatformCredentialSyncService.DiscoveredDevice) async {
        isSending = true
        sendResult = nil

        let success = await syncService.sendAllToDevice(device)

        if success {
            sendResult = "已成功发送多平台登录信息到 \(device.name)"
            sendSuccess = true
        } else {
            sendResult = "发送失败，请重试"
            sendSuccess = false
        }

        isSending = false
    }

    private func clearCloudLoginInfo() async {
        isClearingCloudLoginInfo = true
        let deletedCount = await syncService.clearAllICloudSessions()
        await MainActor.run {
            sendResult = deletedCount > 0 ? "已清理云端登录信息" : "云端没有可清理的登录信息"
            sendSuccess = true
            isClearingCloudLoginInfo = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct SyncStatTile: View {
    let value: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: AppConstants.Spacing.xs) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color.gradient)

            Text(title)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppConstants.Colors.materialBackground.opacity(0.5))
        .cornerRadius(AppConstants.CornerRadius.md)
    }
}

private struct ICloudSyncActionRow: View {
    let title: String
    let subtitle: String
    let isLoading: Bool
    let systemImage: String
    var tint: Color = Color.cyan

    var body: some View {
        HStack(spacing: 12) {
            SyncIconTile {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint.gradient)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppConstants.Colors.tertiaryText)
        }
        .contentShape(Rectangle())
    }
}

private struct SyncIconTile<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppConstants.Colors.tertiaryBackground.opacity(0.55))
            content
        }
        .frame(width: 34, height: 34)
    }
}
