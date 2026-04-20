//
//  PlatformAccountLoginView.swift
//  AngelLive
//
//  数据驱动的平台账号登录列表。
//  所有平台信息来自 PlatformLoginRegistry（manifest.loginFlow），不再硬编码。
//

import SwiftUI
import AngelLiveCore

struct PlatformAccountLoginView: View {
    @ObservedObject private var syncService = PlatformCredentialSyncService.shared
    @Environment(PluginAvailabilityService.self) private var pluginAvailability
    @State private var platforms: [LoginPlatformEntry] = []
    @State private var selectedPluginId: String?

    var body: some View {
        List {
            Section {
                ForEach(platforms) { entry in
                    Button {
                        selectedPluginId = entry.pluginId
                    } label: {
                        HStack(spacing: 12) {
                            platformIcon(entry: entry)
                                .frame(width: 24, height: 24)
                                .frame(width: 32)

                            Text(entry.displayName)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            let loggedIn = syncService.isLoggedIn(pluginId: entry.pluginId)
                            Text(loggedIn ? "已登录" : "未登录")
                                .font(.caption)
                                .foregroundStyle(loggedIn ? AppConstants.Colors.success : .secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("平台列表")
            } footer: {
                Text("登录成功后会保存会话；插件请求时由宿主自动注入鉴权，不会直接读取 Cookie 原文。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("平台账号登录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlatforms()
            await syncService.refreshAllLoginStatus()
        }
        .sheet(item: selectedPlatformBinding, onDismiss: {
            Task {
                await syncService.refreshAllLoginStatus()
            }
        }) { entry in
            PlatformLoginWebSheet(pluginId: entry.pluginId)
        }
    }

    private var selectedPlatformBinding: Binding<LoginPlatformEntry?> {
        Binding(
            get: {
                guard let id = selectedPluginId else { return nil }
                return platforms.first { $0.pluginId == id }
            },
            set: { newValue in
                selectedPluginId = newValue?.pluginId
            }
        )
    }

    private func loadPlatforms() async {
        let all = await PlatformLoginRegistry.shared.availablePlatforms()
        platforms = all.filter { pluginAvailability.isPluginInstalled(for: $0.pluginId) }
    }

    @ViewBuilder
    private func platformIcon(entry: LoginPlatformEntry) -> some View {
        if let liveType = LiveType(rawValue: entry.liveType),
           let image = PlatformIconProvider.pluginManagementImage(for: liveType) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PlatformAccountLoginView()
    }
}
