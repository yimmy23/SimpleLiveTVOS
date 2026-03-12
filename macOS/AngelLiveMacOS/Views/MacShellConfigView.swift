import SwiftUI
import AngelLiveCore

struct MacShellConfigView: View {
    @Environment(StreamBookmarkService.self) private var bookmarkService
    @Environment(PluginSourceManager.self) private var pluginSourceManager
    @Environment(PluginAvailabilityService.self) private var pluginAvailability

    @State private var inputURL = ""
    @State private var inputTitle = ""
    @State private var showContentSheet = false
    @State private var isProcessing = false

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

    var body: some View {
        List {
            Section {
                TextField("标题（可选）", text: $inputTitle)

                TextField("输入地址", text: $inputURL)
                    .textFieldStyle(.roundedBorder)

                Button {
                    handleAdd()
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
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
        .navigationTitle("配置")
        .sheet(isPresented: $showContentSheet) {
            MacSubscriptionContentSheet(
                pluginSourceManager: pluginSourceManager,
                pluginAvailability: pluginAvailability
            )
            .frame(minWidth: 620, minHeight: 480)
        }
    }

    private func handleAdd() {
        let url = trimmedURL
        guard !url.isEmpty else { return }

        if isSubscriptionURL {
            pluginSourceManager.addSource(url)
            inputURL = ""
            inputTitle = ""
            isProcessing = true
            showContentSheet = true

            Task {
                await pluginSourceManager.fetchIndex(from: url)
                await pluginSourceManager.refreshAvailableUpdates()
                isProcessing = false
            }
        } else {
            // 非 .json 后缀：先尝试 key 解析
            inputURL = ""
            inputTitle = ""
            isProcessing = true
            Task {
                let addedURLs = await pluginSourceManager.addSourceWithKeyResolution(url)
                if !addedURLs.isEmpty {
                    showContentSheet = true
                    for added in addedURLs {
                        await pluginSourceManager.fetchIndex(from: added)
                    }
                    await pluginSourceManager.refreshAvailableUpdates()
                } else {
                    await bookmarkService.add(title: inputTitle.isEmpty ? url : inputTitle, url: url)
                }
                isProcessing = false
            }
        }
    }
}

private struct MacSubscriptionContentSheet: View {
    let pluginSourceManager: PluginSourceManager
    let pluginAvailability: PluginAvailabilityService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if pluginSourceManager.isFetchingIndex {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在加载插件...")
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }
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
            .navigationTitle("订阅内容")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if pluginSourceManager.installTotalCount > 0 {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
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
        .task {
            await pluginSourceManager.refreshAvailableUpdates()
        }
    }

    private func contentRow(_ item: RemotePluginDisplayItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.body)
                Text("v\(item.item.version)")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }

            Spacer()

            itemStateView(item)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func itemStateView(_ item: RemotePluginDisplayItem) -> some View {
        switch item.installState {
        case .failed(let error):
            VStack(alignment: .trailing, spacing: 2) {
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
                    .controlSize(.small)
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                installActionButton(title: "更新") {
                    let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            } else if pluginSourceManager.installedVersion(for: item.id) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppConstants.Colors.success)
            } else {
                installActionButton(title: "安装") {
                    let success = await pluginSourceManager.installPlugin(item)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            }

        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("安装中")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }

        case .installed:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
                    .controlSize(.small)
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                installActionButton(title: "更新") {
                    let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppConstants.Colors.success)
            }
        }
    }

    private func installActionButton(title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
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
            await pluginSourceManager.refreshAvailableUpdates()
        }
    }
}
