//
//  MacSyncManagementView.swift
//  AngelLiveMacOS
//
//  设置二级页:同步管理。集中管理 iCloud 自动同步、手动上传/下载,以及云端登录信息清理。
//

import SwiftUI
import AngelLiveCore

struct MacSyncManagementView: View {
    @ObservedObject private var syncService = PlatformCredentialSyncService.shared

    @State private var showUploadConfirm = false
    @State private var showDownloadConfirm = false
    @State private var showClearCloudConfirm = false
    @State private var iCloudConfirmMessage = ""
    @State private var isFetchingPreview = false
    @State private var iCloudSyncResult: String?
    @State private var iCloudSyncSuccess = false
    @State private var isClearingCloudLoginInfo = false

    var body: some View {
        Form {
            Section {
                PanelHintCard(
                    title: "iCloud 同步登录信息",
                    message: "登录的 Cookie 会通过 iCloud 同步到您其它设备,登录态不再需要重新登录。",
                    systemImage: "icloud.fill",
                    tint: .cyan
                )
            }

            Section {
                Toggle(isOn: $syncService.iCloudSyncEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.cyan.gradient)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iCloud 自动同步")
                                .font(.body.weight(.medium))
                            Text("登录后 Cookie 自动同步到其他设备")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(AppConstants.Colors.accent)

                if let lastSync = syncService.lastICloudSyncTime {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("上次同步: \(PlatformCredentialSyncService.formatSyncTime(lastSync))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } header: {
                Text("自动同步")
            }

            if syncService.iCloudSyncEnabled {
                Section {
                    Button {
                        Task { await prepareUploadConfirm() }
                    } label: {
                        PanelNavigationRow(
                            title: "同步到 iCloud",
                            subtitle: "上传本地登录信息到云端"
                        ) {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.cyan.gradient)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingPreview)

                    Button {
                        Task { await prepareDownloadConfirm() }
                    } label: {
                        PanelNavigationRow(
                            title: "从 iCloud 同步",
                            subtitle: "下载云端登录信息到本地"
                        ) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.cyan.gradient)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingPreview)

                    if let result = iCloudSyncResult {
                        HStack(spacing: 6) {
                            Image(systemName: iCloudSyncSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(iCloudSyncSuccess ? AppConstants.Colors.success : .red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(iCloudSyncSuccess ? AppConstants.Colors.success : .red)
                        }
                    }
                } header: {
                    Text("手动同步")
                } footer: {
                    Text("上传或下载会覆盖目标侧的登录信息,执行前会展示对比预览。")
                }

                Section {
                    Button(role: .destructive) {
                        showClearCloudConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isClearingCloudLoginInfo ? "正在清理..." : "清理云端登录信息")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.red)
                                Text("仅清理 iCloud 中保存的登录信息,不影响本机")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isClearingCloudLoginInfo {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isClearingCloudLoginInfo)
                } header: {
                    Text("清理")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("同步管理")
        .task {
            await syncService.refreshAllLoginStatus()
        }
        .alert("同步到 iCloud", isPresented: $showUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定上传") {
                Task {
                    await syncService.syncAllToICloud()
                    await MainActor.run {
                        iCloudSyncResult = "已同步到 iCloud"
                        iCloudSyncSuccess = true
                    }
                }
            }
        } message: {
            Text(iCloudConfirmMessage)
        }
        .alert("从 iCloud 同步", isPresented: $showDownloadConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定下载") {
                Task {
                    await syncService.syncAllFromICloud()
                    await MainActor.run {
                        iCloudSyncResult = "已从 iCloud 同步到本地"
                        iCloudSyncSuccess = true
                    }
                }
            }
        } message: {
            Text(iCloudConfirmMessage)
        }
        .alert("清理云端登录信息", isPresented: $showClearCloudConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定清理", role: .destructive) {
                Task { await clearCloudLoginInfo() }
            }
        } message: {
            Text("确定要清理 iCloud 中保存的所有平台登录信息吗?此操作不会退出本机账号,但其他设备将无法再从 iCloud 下载这些登录信息。")
        }
    }

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

        iCloudConfirmMessage = msg
        showUploadConfirm = true
    }

    private func prepareDownloadConfirm() async {
        isFetchingPreview = true
        defer { isFetchingPreview = false }

        let preview = await syncService.fetchCloudSyncPreview()

        guard preview.latestTime != nil else {
            iCloudSyncResult = "iCloud 中没有同步数据"
            iCloudSyncSuccess = false
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

        iCloudConfirmMessage = msg
        showDownloadConfirm = true
    }

    private func clearCloudLoginInfo() async {
        isClearingCloudLoginInfo = true
        let deletedCount = await syncService.clearAllICloudSessions()
        await MainActor.run {
            iCloudSyncResult = deletedCount > 0 ? "已清理云端登录信息" : "云端没有可清理的登录信息"
            iCloudSyncSuccess = true
            isClearingCloudLoginInfo = false
        }
    }
}
