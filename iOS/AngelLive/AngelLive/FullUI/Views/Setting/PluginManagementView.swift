//
//  PluginManagementView.swift
//  AngelLive
//
//  插件管理页面：显示已安装插件、管理订阅源、安装新插件。
//

import SwiftUI
import AngelLiveCore

struct PluginManagementView: View {
    @Environment(PluginAvailabilityService.self) private var pluginAvailability
    @Environment(PluginSourceManager.self) private var pluginSourceManager

    @State private var inputURL = ""
    @State private var isProcessing = false

    var body: some View {
        List {
            // 已安装插件
            installedPluginsSection

            // 订阅源管理
            subscriptionSourcesSection

            // 添加新订阅源
            addSourceSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("插件管理")
        .navigationBarTitleDisplayMode(.large)
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
                    .font(.body)
                    .foregroundStyle(AppConstants.Colors.secondaryText)
            } else {
                ForEach(pluginAvailability.installedPluginIds, id: \.self) { pluginId in
                    HStack {
                        // 优先显示插件内置 iOS 图标
                        if let platform = platformForPluginId(pluginId) {
                            if let image = PlatformIconProvider.tabImage(for: platform.liveType) {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "puzzlepiece.extension")
                                    .frame(width: 32, height: 32)
                            }
                        } else {
                            Image(systemName: "puzzlepiece.extension")
                                .frame(width: 32, height: 32)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginDisplayName(for: pluginId))
                                .font(.body)
                                .foregroundStyle(AppConstants.Colors.primaryText)

                            versionSubtitleView(for: pluginId)
                        }

                        Spacer()

                        pluginStatusView(for: pluginId)
                    }
                    .padding(.vertical, AppConstants.Spacing.xs)
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

    @ViewBuilder
    private var subscriptionSourcesSection: some View {
        if !pluginSourceManager.sourceURLs.isEmpty {
            Section {
                ForEach(pluginSourceManager.sourceURLs, id: \.self) { url in
                    HStack {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.primaryText)
                            .lineLimit(1)

                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await pluginSourceManager.removeSourceAndAssociatedPlugins(url)
                                await pluginAvailability.refresh()
                                await pluginSourceManager.refreshAvailableUpdates()
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("已添加的订阅源")
            }
        }
    }

    // MARK: - 添加订阅源

    private var addSourceSection: some View {
        Section {
            TextField("输入订阅源地址 (.json)", text: $inputURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)

            Button {
                addSource()
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
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

    // MARK: - Actions

    private func addSource() {
        let url = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        pluginSourceManager.addSource(url)
        inputURL = ""
        isProcessing = true
        Task {
            await pluginSourceManager.refreshAvailableUpdates()
            isProcessing = false
        }
    }

    // MARK: - Helpers

    private func pluginDisplayName(for pluginId: String) -> String {
        guard let platform = platformForPluginId(pluginId) else {
            return pluginId
        }
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
                .scaleEffect(0.8)
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
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(AppConstants.Colors.link)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更新插件")
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppConstants.Colors.success)
        }
    }

}
