//
//  MacPluginManagementView.swift
//  AngelLiveMacOS
//
//  macOS 插件管理页：显示已安装插件、管理订阅源、安装/更新插件。
//

import SwiftUI
import AngelLiveCore
import LiveParse

struct MacPluginManagementView: View {
    @Environment(PluginAvailabilityService.self) private var pluginAvailability
    @Environment(PluginSourceManager.self) private var pluginSourceManager

    @State private var inputURL = ""
    @State private var isProcessing = false

    var body: some View {
        Form {
            // 已安装插件
            installedPluginsSection

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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.error)
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
            ProgressView()
                .controlSize(.small)
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
        let url = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        pluginSourceManager.addSource(url)
        inputURL = ""
        isProcessing = true
        Task {
            await pluginSourceManager.fetchIndex(from: url)
            await pluginSourceManager.refreshAvailableUpdates()
            isProcessing = false
        }
    }
}
