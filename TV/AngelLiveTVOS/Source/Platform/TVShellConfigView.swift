// TVShellConfigView.swift
// AngelLiveTVOS
//
// 壳 UI 配置页：简洁输入框，自动识别视频链接或订阅地址。

import SwiftUI
import AngelLiveCore

struct TVShellConfigView: View {
    @Environment(AppState.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputURL = ""
    @State private var inputTitle = ""
    @State private var showContentSheet = false
    @State private var isProcessing = false
    @FocusState private var focusedField: Field?

    enum Field { case title, url, add }

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
        ZStack {
            Color.clear
                .background(.thinMaterial)
                .ignoresSafeArea()

            HStack(alignment: .center, spacing: 120) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("添加视频或订阅")
                        .font(.system(size: 48, weight: .heavy))

                    Text("输入视频地址添加到收藏，可在收藏页直接播放")
                        .font(.system(size: 24, weight: .medium))
                        .lineSpacing(6)
                        .foregroundStyle(.secondary)

                    TextField("标题（可选）", text: $inputTitle)
                        .focused($focusedField, equals: .title)
                        .frame(maxWidth: 600, alignment: .leading)

                    TextField("输入地址", text: $inputURL)
                        .focused($focusedField, equals: .url)
                        .frame(maxWidth: 600, alignment: .leading)

                    if let error = appViewModel.pluginSourceManager.errorMessage {
                        Text(error)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    HStack(spacing: 20) {
                        Button(action: handleAdd) {
                            Label("添加", systemImage: "plus.circle.fill")
                                .font(.caption)
                        }
                        .disabled(trimmedURL.isEmpty || isProcessing)
                        .focused($focusedField, equals: .add)

                        if isProcessing {
                            ProgressView()
                        }
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)

                // 右侧：远程输入二维码
                remoteInputQRPanel
            }
            .padding(80)
            .safeAreaPadding()
        }
        .onChange(of: appViewModel.remoteInputService.lastEvent?.value) {
            guard let event = appViewModel.remoteInputService.lastEvent else { return }
            switch event.field {
            case .title: inputTitle = event.value
            case .url:   inputURL = event.value
            case .search: break
            }
        }
        .fullScreenCover(isPresented: $showContentSheet) {
            TVSubscriptionContentSheet(
                pluginSourceManager: appViewModel.pluginSourceManager,
                pluginAvailability: appViewModel.pluginAvailability
            )
        }
    }

    // MARK: - 远程输入二维码面板

    private var remoteInputQRPanel: some View {
        let service = appViewModel.remoteInputService
        let url = "http://\(service.localIPAddress):\(service.port)/config"
        return VStack(spacing: 16) {
            Spacer()
            if service.isRunning && !service.localIPAddress.isEmpty {
                Image(uiImage: Common.generateQRCode(from: url))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 18)

                Text("扫码用手机输入")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(url)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            } else {
                ProgressView()
                Text("正在启动远程输入...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
                await appViewModel.bookmarkService.add(
                    title: inputTitle.isEmpty ? url : inputTitle,
                    url: url
                )
                inputURL = ""
                inputTitle = ""
            }
        }
    }
}

// MARK: - 订阅内容 Sheet

private struct TVSubscriptionContentSheet: View {
    let pluginSourceManager: PluginSourceManager
    let pluginAvailability: PluginAvailabilityService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.clear
                .background(.thinMaterial)
                .ignoresSafeArea()

            NavigationStack {
                Group {
                    if pluginSourceManager.isFetchingIndex {
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(2)
                            Text("正在加载内容...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if pluginSourceManager.remotePlugins.isEmpty {
                        ContentUnavailableView {
                            Label("暂无可用内容", systemImage: "tray")
                        }
                    } else {
                        List {
                            Section {
                                ForEach(pluginSourceManager.remotePlugins) { item in
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                                .font(.headline)
                                            Text("v\(item.item.version)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        cardStateView(item)
                                    }
                                    .padding(.vertical, 20)
                                }
                            } header: {
                                HStack {
                                    Spacer()
                                    if pluginSourceManager.installTotalCount > 0 {
                                        HStack(spacing: 12) {
                                            ProgressView()
                                            Text("正在安装 \(pluginSourceManager.installCompletedCount)/\(pluginSourceManager.installTotalCount)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Button(action: { installAll() }) {
                                            Text("全部安装")
                                        }
                                        .disabled(!canInstallAll)
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    }
                }
                .navigationTitle("订阅内容")
            }
        }
        .task {
            await pluginSourceManager.refreshAvailableUpdates()
        }
    }

    private func contentCard(_ item: RemotePluginDisplayItem) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("v\(item.item.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            cardStateView(item)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .adaptiveGlassEffectRoundedRect(cornerRadius: 16)
    }

    @ViewBuilder
    private func cardStateView(_ item: RemotePluginDisplayItem) -> some View {
        switch item.installState {
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                Text("安装中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .notInstalled:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                actionButton("更新", item: item, isUpdate: true)
            } else if pluginSourceManager.installedVersion(for: item.id) != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                actionButton("安装", item: item, isUpdate: false)
            }
        case .installed:
            if pluginSourceManager.updatingPluginIds.contains(item.id) {
                ProgressView()
            } else if pluginSourceManager.hasUpdate(for: item.id) {
                actionButton("更新", item: item, isUpdate: true)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }

    private func actionButton(_ title: String, item: RemotePluginDisplayItem, isUpdate: Bool) -> some View {
        Button {
            Task {
                let success: Bool
                if isUpdate {
                    success = await pluginSourceManager.updatePlugin(pluginId: item.id)
                } else {
                    success = await pluginSourceManager.installPlugin(item)
                }
                if success {
                    await pluginAvailability.refresh()
                    await pluginSourceManager.refreshAvailableUpdates()
                }
            }
        } label: {
            Label(title, systemImage: isUpdate ? "arrow.down.circle.fill" : "plus.circle.fill")
                .font(.caption)
        }
    }

    private var canInstallAll: Bool {
        !pluginSourceManager.isInstalling &&
        pluginSourceManager.remotePlugins.contains { $0.installState == .notInstalled }
    }

    private func installAll() {
        guard canInstallAll else { return }
        Task {
            let count = await pluginSourceManager.installAll()
            if count > 0 {
                await pluginAvailability.refresh()
            }
        }
    }
}
