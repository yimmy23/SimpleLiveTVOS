//
//  SettingView.swift
//  AngelLive
//
//  Created by pangchong on 10/17/25.
//

import SwiftUI
import AngelLiveCore
import LiveParse

struct SettingView: View {
    @StateObject private var syncService = BilibiliCookieSyncService.shared
    @State private var cloudKitReady = false
    @State private var cloudKitStateString = "检查中..."
    @Environment(PluginAvailabilityService.self) private var pluginAvailability

    private var accountManagementIcon: UIImage? {
        let preferredTypes: [LiveType] = [.bilibili, .douyin, .ks, .soop]
        for type in preferredTypes {
            if let image = PlatformIconProvider.tabImage(for: type) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                // 账号设置
                if pluginAvailability.hasAvailablePlugins {
                    Section {
                        NavigationLink {
                            PlatformAccountLoginView()
                                .toolbar(.hidden, for: .tabBar)
                        } label: {
                            HStack {
                                Group {
                                    if let image = accountManagementIcon {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppConstants.Colors.link.gradient)
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .frame(width: 32)

                                Text("平台账号登录")

                                Spacer()

                                Text("哔哩/抖音/快手")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.secondaryText)
                            }
                        }
                    } header: {
                        Text("账号")
                    }
                }

                // 插件管理
                if pluginAvailability.hasAvailablePlugins {
                    Section {
                        NavigationLink {
                            PluginManagementView()
                                .toolbar(.hidden, for: .tabBar)
                        } label: {
                            HStack {
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.orange.gradient)
                                    .frame(width: 32)

                                Text("插件管理")

                                Spacer()

                                Text("\(pluginAvailability.installedPluginIds.count) 个已安装")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.secondaryText)
                            }
                        }
                    } header: {
                        Text("插件")
                    }
                }

                // 应用设置
                Section {
                    NavigationLink {
                        GeneralSettingView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(Color.gray.gradient)
                                .frame(width: 32)
                            Text("通用设置")
                        }
                    }
                } header: {
                    Text("设置")
                }

                // 播放设置（始终可用）
                Section {
                    NavigationLink {
                        DanmuSettingView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title3)
                                .foregroundStyle(AppConstants.Colors.success.gradient)
                                .frame(width: 32)
                            Text("弹幕设置")
                        }
                    }
                } header: {
                    Text("播放")
                }

                // 数据同步（有插件时可用）
                if pluginAvailability.hasAvailablePlugins {
                    Section {
                        NavigationLink {
                            if cloudKitReady {
                                SyncView()
                                    .toolbar(.hidden, for: .tabBar)
                            } else {
                                CloudKitStatusView(stateString: cloudKitStateString)
                                    .toolbar(.hidden, for: .tabBar)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "icloud.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.cyan.gradient)
                                    .frame(width: 32)

                                Text("数据同步")

                                Spacer()

                                Text(cloudKitReady ? "iCloud 就绪" : "状态异常")
                                    .font(.caption)
                                    .foregroundStyle(cloudKitReady ? AppConstants.Colors.success : AppConstants.Colors.error)
                            }
                        }
                    } header: {
                        Text("同步")
                    }
                }

                // 历史记录（始终可用）
                Section {
                    NavigationLink {
                        HistoryListView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.title3)
                                .foregroundStyle(AppConstants.Colors.warning.gradient)
                                .frame(width: 32)
                            Text("历史记录")
                        }
                    }
                } header: {
                    Text("记录")
                }

                // tvOS 同步
                if pluginAvailability.hasAvailablePlugins {
                    Section {
                        NavigationLink {
                            TVOSSyncView()
                                .toolbar(.hidden, for: .tabBar)
                        } label: {
                            HStack {
                                Image(systemName: "appletv.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.purple.gradient)
                                    .frame(width: 32)

                                Text("同步到 tvOS")

                                Spacer()

                                Text("多平台账号")
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.secondaryText)
                            }
                        }
                    } header: {
                        Text("tvOS")
                    } footer: {
                        Text("将哔哩哔哩/抖音/快手/SOOP 登录信息同步到 Apple TV，支持局域网自动发现。")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.secondaryText)
                    }
                }

                // 关于
                Section {
                    NavigationLink {
                        OpenSourceListView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundStyle(Color.purple.gradient)
                                .frame(width: 32)
                            Text("开源许可")
                        }
                    }

                    NavigationLink {
                        AboutUSView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.indigo.gradient)
                                .frame(width: 32)
                            Text("关于&问题反馈")
                        }
                    }
                } header: {
                    Text("信息")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if pluginAvailability.hasAvailablePlugins {
                    await checkCloudKitStatus()
                }
            }
            .onChange(of: pluginAvailability.hasAvailablePlugins) { _, hasPlugins in
                guard hasPlugins else { return }
                Task {
                    await checkCloudKitStatus()
                }
            }
        }
    }

    private func checkCloudKitStatus() async {
        cloudKitStateString = await FavoriteService.getCloudState()
        cloudKitReady = cloudKitStateString == "正常"
    }
}

// MARK: - CloudKit Status View

struct CloudKitStatusView: View {
    let stateString: String

    var body: some View {
        VStack(spacing: AppConstants.Spacing.xl) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 60))
                .foregroundStyle(AppConstants.Colors.warning)

            Text("iCloud 状态异常")
                .font(.title2.bold())
                .foregroundStyle(AppConstants.Colors.primaryText)

            Text(stateString)
                .font(.body)
                .foregroundStyle(AppConstants.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("同步")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingView()
}
