//
//  OpenSourceListView.swift
//  AngelLiveMacOS
//
//  Created by Claude on 12/3/25.
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

struct OpenSourceListView: View {
    @State private var acknowList: AcknowList? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                loadingStateView
            } else if let errorMsg = errorMessage {
                ErrorView(
                    title: "无法加载开源许可",
                    message: errorMsg,
                    showRetry: true,
                    onRetry: {
                        loadAcknowledgements()
                    }
                )
            } else if let list = acknowList {
                AcknowListSwiftUIView(acknowList: list)
            } else {
                ErrorView.empty(
                    title: "暂无开源许可信息",
                    message: "当前没有可展示的依赖许可内容。",
                    symbolName: "doc.text",
                    tint: .secondary
                )
            }
        }
        .navigationTitle("开源许可")
        .task {
            loadAcknowledgements()
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: 16) {
            PanelHintCard(
                title: "正在整理开源许可",
                message: "稍后会列出当前构建包含的第三方依赖与授权信息，方便你快速核对来源。",
                systemImage: "doc.text.magnifyingglass",
                tint: .blue
            )

            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在解析 Package.resolved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAcknowledgements() {
        isLoading = true
        errorMessage = nil

        // 尝试从 Bundle 中加载 Package.resolved 文件
        guard let url = Bundle.main.url(forResource: "Package", withExtension: "resolved") else {
            errorMessage = "找不到 Package.resolved 文件"
            isLoading = false
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = AcknowPackageDecoder()
            let list = try decoder.decode(from: data)
            acknowList = list
            isLoading = false
        } catch {
            errorMessage = "解析失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

#Preview {
    OpenSourceListView()
}
