//
//  ShellConfigView.swift
//  AngelLive
//
//  壳 UI - 配置页：统一输入框，自动识别视频链接或订阅地址。
//

import SwiftUI
import AngelLiveCore

struct ShellConfigView: View {
    @Environment(StreamBookmarkService.self) private var bookmarkService
    @Environment(PluginSourceManager.self) private var pluginSourceManager
    @Environment(PluginAvailabilityService.self) private var pluginAvailability

    @State private var inputURL = ""
    @State private var inputTitle = ""
    @State private var showContentList = false
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            List {
                addSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("配置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showContentList) {
                SubscriptionContentSheet(
                    pluginSourceManager: pluginSourceManager,
                    pluginAvailability: pluginAvailability
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 添加

    private var trimmedURL: String {
        inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSubscriptionURL: Bool {
        guard !trimmedURL.isEmpty else { return false }
        if let url = URL(string: trimmedURL) {
            return url.pathExtension.lowercased() == "json"
        }
        return trimmedURL.lowercased().hasSuffix(".json")
    }

    private var addSection: some View {
        Section {
            TextField("标题（可选）", text: $inputTitle)

            TextField("输入地址", text: $inputURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)

            Button {
                handleAdd()
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppConstants.Colors.success.gradient)
                    }
                    Text("添加")
                }
            }
            .disabled(trimmedURL.isEmpty || isProcessing)

            if let error = pluginSourceManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.error)
            }
        } header: {
            Text("添加视频或订阅")
        } footer: {
            Text("输入视频地址添加到收藏，可在收藏页直接播放")
        }
    }

    private func handleAdd() {
        let url = trimmedURL
        guard !url.isEmpty else { return }

        if isSubscriptionURL {
            // 订阅地址
            pluginSourceManager.addSource(url)
            inputURL = ""
            inputTitle = ""
            isProcessing = true
            showContentList = true
            Task {
                await pluginSourceManager.fetchIndex(from: url)
                isProcessing = false
            }
        } else {
            // 视频链接
            Task {
                await bookmarkService.add(title: inputTitle.isEmpty ? url : inputTitle, url: url)
                inputURL = ""
                inputTitle = ""
            }
        }
    }

}

// MARK: - 订阅内容列表

struct SubscriptionContentSheet: View {
    let pluginSourceManager: PluginSourceManager
    let pluginAvailability: PluginAvailabilityService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if pluginSourceManager.isFetchingIndex {
                    Section {
                        HStack(spacing: AppConstants.Spacing.sm) {
                            ProgressView()
                            Text("正在加载插件...")
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }
                        .padding(.vertical, AppConstants.Spacing.xs)
                    }
                } else if pluginSourceManager.remotePlugins.isEmpty {
                    ContentUnavailableView {
                        Label("暂无可用内容", systemImage: "tray")
                    }
                } else {
                    ForEach(pluginSourceManager.remotePlugins) { item in
                        contentRow(item)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("订阅内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if pluginSourceManager.installTotalCount > 0 {
                        HStack(spacing: AppConstants.Spacing.xs) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("\(pluginSourceManager.installCompletedCount)/\(pluginSourceManager.installTotalCount)")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }
                    } else {
                        Button("全部安装") {
                            installAllPlugins()
                        }
                        .disabled(!canInstallAll)
                    }
                }
            }
        }
    }

    private func contentRow(_ item: RemotePluginDisplayItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                Text(item.displayName)
                    .font(.body)
                    .foregroundStyle(AppConstants.Colors.primaryText)

                Text("v\(item.item.version)")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }

            Spacer()

            itemStateView(item)
        }
        .padding(.vertical, AppConstants.Spacing.xs)
    }

    @ViewBuilder
    private func itemStateView(_ item: RemotePluginDisplayItem) -> some View {
        switch item.installState {
        case .failed(let error):
            VStack(alignment: .trailing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppConstants.Colors.warning)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(AppConstants.Colors.error)
                    .lineLimit(2)
            }

        case .notInstalled:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
                    .scaleEffect(0.8)
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                Button {
                    Task {
                        let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                        if success {
                            await pluginAvailability.refresh()
                            await pluginSourceManager.refreshAvailableUpdates()
                        }
                    }
                } label: {
                    Text("更新")
                        .font(.caption)
                        .padding(.horizontal, AppConstants.Spacing.sm)
                        .padding(.vertical, AppConstants.Spacing.xs)
                        .background(AppConstants.Colors.link)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("更新插件")
            } else if pluginSourceManager.installedVersion(for: item.id) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppConstants.Colors.success)
            } else {
                Button {
                    Task {
                        let success = await pluginSourceManager.installPlugin(item)
                        if success {
                            await pluginAvailability.refresh()
                        }
                    }
                } label: {
                    Text("安装")
                        .font(.caption)
                        .padding(.horizontal, AppConstants.Spacing.sm)
                        .padding(.vertical, AppConstants.Spacing.xs)
                        .background(AppConstants.Colors.link)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

        case .installing:
            HStack(spacing: AppConstants.Spacing.xs) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("安装中")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }

        case .installed:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
                    .scaleEffect(0.8)
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                Button {
                    Task {
                        let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                        if success {
                            await pluginAvailability.refresh()
                            await pluginSourceManager.refreshAvailableUpdates()
                        }
                    }
                } label: {
                    Text("更新")
                        .font(.caption)
                        .padding(.horizontal, AppConstants.Spacing.sm)
                        .padding(.vertical, AppConstants.Spacing.xs)
                        .background(AppConstants.Colors.link)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("更新插件")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppConstants.Colors.success)
            }
        }
    }

    private var canInstallAll: Bool {
        !pluginSourceManager.isInstalling &&
        pluginSourceManager.remotePlugins.contains { $0.installState == .notInstalled }
    }

    private func installAllPlugins() {
        guard canInstallAll else { return }
        Task {
            let count = await pluginSourceManager.installAll()
            if count > 0 {
                await pluginAvailability.refresh()
            }
        }
    }
}
