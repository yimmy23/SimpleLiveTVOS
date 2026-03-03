import SwiftUI
import AngelLiveCore
import LiveParse

struct TVShellConfigView: View {
    @Environment(AppState.self) private var appViewModel

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
        NavigationStack {
            Form {
                Section("添加视频或订阅") {
                    TextField("标题（可选）", text: $inputTitle)
                    TextField("输入地址", text: $inputURL)

                    Button {
                        handleAdd()
                    } label: {
                        HStack(spacing: 10) {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Text("添加")
                        }
                    }
                    .disabled(trimmedURL.isEmpty || isProcessing)

                    if let error = appViewModel.pluginSourceManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("配置")
            .sheet(isPresented: $showContentSheet) {
                TVSubscriptionContentSheet(
                    pluginSourceManager: appViewModel.pluginSourceManager,
                    pluginAvailability: appViewModel.pluginAvailability
                )
            }
        }
    }

    private func handleAdd() {
        let url = trimmedURL
        guard !url.isEmpty else { return }

        if isSubscriptionURL {
            appViewModel.pluginSourceManager.addSource(url)
            inputURL = ""
            inputTitle = ""
            isProcessing = true
            showContentSheet = true

            Task {
                await appViewModel.pluginSourceManager.fetchIndex(from: url)
                await appViewModel.pluginSourceManager.refreshAvailableUpdates()
                isProcessing = false
            }
        } else {
            Task {
                await appViewModel.bookmarkService.add(title: inputTitle.isEmpty ? url : inputTitle, url: url)
                inputURL = ""
                inputTitle = ""
            }
        }
    }
}

private struct TVSubscriptionContentSheet: View {
    let pluginSourceManager: PluginSourceManager
    let pluginAvailability: PluginAvailabilityService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if pluginSourceManager.isFetchingIndex {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在加载插件...")
                            .foregroundStyle(.secondary)
                    }
                } else if pluginSourceManager.remotePlugins.isEmpty {
                    Text("暂无可用内容")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pluginSourceManager.remotePlugins) { item in
                        rowView(item)
                    }
                }
            }
            .navigationTitle("订阅内容")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("全部安装") {
                        installAllPlugins()
                    }
                    .disabled(!canInstallAll)
                }
            }
        }
        .task {
            await pluginSourceManager.refreshAvailableUpdates()
        }
    }

    private func rowView(_ item: RemotePluginDisplayItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                Text("v\(item.item.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            stateView(item)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func stateView(_ item: RemotePluginDisplayItem) -> some View {
        switch item.installState {
        case .failed(let error):
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

        case .installing:
            ProgressView()

        case .notInstalled:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                actionButton("更新") {
                    let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            } else if pluginSourceManager.installedVersion(for: item.id) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                actionButton("安装") {
                    let success = await pluginSourceManager.installPlugin(item)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            }

        case .installed:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                actionButton("更新") {
                    let success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func actionButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.borderedProminent)
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
