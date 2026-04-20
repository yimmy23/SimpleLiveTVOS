//
//  TVOSSyncView.swift
//  AngelLive
//
//  Created by pangchong on 10/17/25.
//

import SwiftUI
import AngelLiveCore

struct TVOSSyncView: View {
    @ObservedObject private var syncService = PlatformCredentialSyncService.shared
    @State private var isSearching = false
    @State private var isSending = false
    @State private var sendResult: String?
    @State private var sendSuccess = false

    // iCloud 确认弹窗状态
    @State private var showUploadConfirm = false
    @State private var showDownloadConfirm = false
    @State private var confirmMessage = ""
    @State private var isFetchingPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppConstants.Spacing.lg) {
                // Cookie 状态卡片
                VStack(spacing: AppConstants.Spacing.md) {
                    HStack {
                        Image(systemName: hasAnyLogin ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(hasAnyLogin ? AppConstants.Colors.success.gradient : AppConstants.Colors.error.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("多平台 Cookie")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.primaryText)

                            Text("将已登录的平台账号同步到 tvOS（哔哩哔哩 / 抖音 / 快手 / SOOP / Kick）")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }

                        Spacer()
                    }
                }
                .padding()
                .background(AppConstants.Colors.materialBackground)
                .cornerRadius(AppConstants.CornerRadius.lg)

                // iCloud 同步
                VStack(spacing: AppConstants.Spacing.md) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .font(.title2)
                            .foregroundStyle(Color.cyan.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud 自动同步")
                                .font(.headline)
                                .foregroundStyle(AppConstants.Colors.primaryText)

                            Text("开启后 Cookie 会自动同步到 tvOS")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }

                        Spacer()

                        Toggle("", isOn: $syncService.iCloudSyncEnabled)
                            .tint(AppConstants.Colors.accent)
                            .labelsHidden()
                    }

                    if syncService.iCloudSyncEnabled {
                        // 上次同步时间
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

                        // 同步到 iCloud
                        Button {
                            Task { await prepareUploadConfirm() }
                        } label: {
                            HStack {
                                if isFetchingPreview {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                }
                                Text("同步到 iCloud")
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.link)
                        }
                        .disabled(isFetchingPreview)

                        // 从 iCloud 同步
                        Button {
                            Task { await prepareDownloadConfirm() }
                        } label: {
                            HStack {
                                if isFetchingPreview {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "icloud.and.arrow.down")
                                }
                                Text("从 iCloud 同步到本地")
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.Colors.link)
                        }
                        .disabled(isFetchingPreview)
                    }
                }
                .padding()
                .background(AppConstants.Colors.materialBackground)
                .cornerRadius(AppConstants.CornerRadius.lg)

                // 局域网同步
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

                    // 发现的设备列表
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

                    // 搜索按钮
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

                // 结果提示
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

                // 使用说明
                VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                    Text("使用说明")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.primaryText)

                    VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                        Label("确保 iPhone/iPad 和 Apple TV 在同一 WiFi 网络", systemImage: "1.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.secondaryText)

                        Label("在 tvOS 设置中打开「账号管理 > 局域网同步」", systemImage: "2.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.secondaryText)

                        Label("在此页面点击搜索并选择 tvOS 设备发送", systemImage: "3.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.secondaryText)

                        Label("也可以开启 iCloud 同步，Cookie 会自动同步", systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.link)
                    }
                }
                .padding()
                .background(AppConstants.Colors.materialBackground)
                .cornerRadius(AppConstants.CornerRadius.lg)

                Spacer(minLength: AppConstants.Spacing.xxl)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("同步到 tvOS")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            syncService.stopBonjourBrowsing()
        }
        .alert("同步到 iCloud", isPresented: $showUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定上传") {
                Task {
                    await syncService.syncAllToICloud()
                    await MainActor.run {
                        sendResult = "已同步到 iCloud（含多平台）"
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
                    await MainActor.run {
                        sendResult = "已从 iCloud 同步到本地"
                        sendSuccess = true
                    }
                }
            }
        } message: {
            Text(confirmMessage)
        }
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

    private var hasAnyLogin: Bool {
        syncService.loggedInByPluginId.values.contains(true)
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
}
