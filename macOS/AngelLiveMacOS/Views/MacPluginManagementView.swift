//
//  MacPluginManagementView.swift
//  AngelLiveMacOS
//
//  macOS 插件管理页：显示已安装插件、管理订阅源、安装/更新插件。
//

import SwiftUI
import AngelLiveCore

struct MacPluginManagementView: View {
    @Environment(PluginAvailabilityService.self) private var pluginAvailability
    @Environment(PluginSourceManager.self) private var pluginSourceManager

    @State private var inputURL = ""
    @State private var isProcessing = false

    var body: some View {
        Form {
            // 已安装插件
            installedPluginsSection

            // 可安装插件
            availablePluginsSection

            // 订阅源管理
            if !pluginSourceManager.sourceURLs.isEmpty {
                subscriptionSourcesSection
            }

            // 添加新订阅源
            addSourceSection
        }
        .formStyle(.grouped)
        .navigationTitle("插件管理")
        .task {
            await pluginSourceManager.fetchAllSourceIndexes()
            await pluginSourceManager.refreshAvailableUpdates()
        }
        .onChange(of: pluginAvailability.installedPluginIds) { _, _ in
            Task {
                await pluginSourceManager.refreshAvailableUpdates()
            }
        }
    }

    // MARK: - 已安装插件

    private var installedPluginsSection: some View {
        Section {
            if pluginAvailability.installedPluginIds.isEmpty {
                Text("暂无已安装的插件")
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            } else {
                ForEach(pluginAvailability.installedPluginIds, id: \.self) { pluginId in
                    HStack(spacing: 10) {
                        pluginIconView(for: pluginId)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginDisplayName(for: pluginId))
                                .font(.body)

                            versionSubtitleView(for: pluginId)
                        }

                        Spacer()

                        pluginStatusView(for: pluginId)

                        Button(role: .destructive) {
                            Task {
                                _ = pluginSourceManager.uninstallPlugin(pluginId: pluginId)
                                await pluginAvailability.refresh()
                                await pluginSourceManager.fetchAllSourceIndexes()
                                await pluginSourceManager.refreshAvailableUpdates()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("已安装插件")
        } footer: {
            if !pluginAvailability.installedPluginIds.isEmpty {
                Text("共 \(pluginAvailability.installedPluginIds.count) 个插件")
            }
        }
    }

    // MARK: - 可安装插件

    @ViewBuilder
    private var availablePluginsSection: some View {
        let notInstalled = pluginSourceManager.remotePlugins.filter {
            pluginSourceManager.installedVersion(for: $0.id) == nil
        }
        if !notInstalled.isEmpty {
            Section {
                ForEach(notInstalled) { displayItem in
                    HStack(spacing: 10) {
                        Image(systemName: "puzzlepiece.extension")
                            .frame(width: 28, height: 28)
                            .foregroundStyle(AppConstants.Colors.secondaryText)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayItem.displayName)
                                .font(.body)
                            Text("版本 \(displayItem.item.version)")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.secondaryText)
                        }

                        Spacer()

                        remotePluginActionView(for: displayItem)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text("可安装插件")
                    Spacer()
                    if notInstalled.contains(where: { $0.installState == .notInstalled }) {
                        Button {
                            Task {
                                _ = await pluginSourceManager.installAll()
                                await pluginAvailability.refresh()
                                await pluginSourceManager.refreshAvailableUpdates()
                            }
                        } label: {
                            Text("全部安装")
                                .font(.caption)
                        }
                        .disabled(pluginSourceManager.isInstalling)
                    }
                }
            }
        }
    }

    // MARK: - 订阅源管理

    private var subscriptionSourcesSection: some View {
        Section {
            ForEach(pluginSourceManager.sourceURLs, id: \.self) { url in
                HStack {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(role: .destructive) {
                        Task {
                            await pluginSourceManager.removeSourceAndAssociatedPlugins(url)
                            await pluginAvailability.refresh()
                            await pluginSourceManager.fetchAllSourceIndexes()
                            await pluginSourceManager.refreshAvailableUpdates()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("已添加的订阅源")
        }
    }

    // MARK: - 添加订阅源

    private var addSourceSection: some View {
        Section {
            TextField("输入订阅源地址 (.json)", text: $inputURL)

            Button {
                addSource()
            } label: {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppConstants.Colors.success.gradient)
                    }
                    Text("添加订阅源")
                }
            }
            .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)

            if let error = pluginSourceManager.errorMessage {
                PluginSourceErrorCard(title: "插件源异常", message: error)
            }
        } header: {
            Text("添加订阅源")
        } footer: {
            Text("输入包含插件索引的 JSON 地址，添加后将自动检查插件更新")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func pluginIconView(for pluginId: String) -> some View {
        if let platform = platformForPluginId(pluginId),
           let image = MacPlatformIconProvider.tabImage(for: platform.liveType) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "puzzlepiece.extension")
                .frame(width: 28, height: 28)
                .foregroundStyle(AppConstants.Colors.secondaryText)
        }
    }

    private func pluginDisplayName(for pluginId: String) -> String {
        guard let platform = platformForPluginId(pluginId) else { return pluginId }
        return LiveParseTools.getLivePlatformName(platform.liveType)
    }

    private func platformForPluginId(_ pluginId: String) -> LiveParseJSPlatform? {
        LiveParseJSPlatformManager.availablePlatforms.first { $0.pluginId == pluginId }
    }

    @ViewBuilder
    private func versionSubtitleView(for pluginId: String) -> some View {
        let installed = pluginSourceManager.installedVersion(for: pluginId) ?? "未知"
        if let latest = pluginSourceManager.latestVersion(for: pluginId),
           pluginSourceManager.hasUpdate(for: pluginId) {
            (
                Text(installed).foregroundStyle(Color.red) +
                Text(" → ").foregroundStyle(AppConstants.Colors.secondaryText) +
                Text(latest).foregroundStyle(Color.green)
            )
            .font(.caption)
        } else {
            Text("版本 \(installed)")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private func pluginStatusView(for pluginId: String) -> some View {
        if pluginSourceManager.updatingPluginIds.contains(pluginId) {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("更新中")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            }
        } else if pluginSourceManager.hasUpdate(for: pluginId) {
            Button {
                Task {
                    let success = await pluginSourceManager.updatePlugin(pluginId: pluginId)
                    if success {
                        await pluginAvailability.refresh()
                    }
                    await pluginSourceManager.refreshAvailableUpdates()
                }
            } label: {
                Label("更新", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(AppConstants.Colors.link)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppConstants.Colors.success)
        }
    }

    private func addSource() {
        let input = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isProcessing = true
        Task {
            let addedURLs = await pluginSourceManager.addSourceFromInput(input)
            if !addedURLs.isEmpty {
                inputURL = ""
                await pluginSourceManager.fetchAllSourceIndexes()
                await pluginSourceManager.refreshAvailableUpdates()
            }
            isProcessing = false
        }
    }

    // MARK: - 远程插件操作

    @ViewBuilder
    private func remotePluginActionView(for displayItem: RemotePluginDisplayItem) -> some View {
        switch displayItem.installState {
        case .notInstalled:
            Button {
                Task {
                    let success = await pluginSourceManager.installPlugin(displayItem)
                    if success {
                        await pluginAvailability.refresh()
                        await pluginSourceManager.refreshAvailableUpdates()
                    }
                }
            } label: {
                Text("安装")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .installing:
            ProgressView()
                .controlSize(.small)
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppConstants.Colors.success)
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}
