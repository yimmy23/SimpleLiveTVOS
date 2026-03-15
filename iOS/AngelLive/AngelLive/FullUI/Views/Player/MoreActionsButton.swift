//
//  MoreActionsButton.swift
//  AngelLive
//
//  Created by pangchong on 10/23/25.
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies
import AVKit

/// 直播间功能按钮（清屏、主播详情等直播间相关功能）
struct MoreActionsButton: View {
    let room: LiveModel
    var onClearChat: () -> Void
    var showQualityOption: Bool = false

    @Environment(RoomInfoViewModel.self) private var viewModel
    @State private var showActionSheet = false
    @State private var showStreamerInfo = false
    @State private var showQualitySheet = false
    @State private var buttonPressed = false

    var body: some View {
        Button(action: {
            buttonPressed.toggle()
            showActionSheet = true
        }) {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
        .conditionalEffect(.pushDown, condition: buttonPressed)
        .confirmationDialog("直播间", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("主播详情") {
                showStreamerInfo = true
            }

            if showQualityOption {
                Button("清晰度 - \(viewModel.currentPlayQualityString)") {
                    showQualitySheet = true
                }
            }

            Button("清屏") {
                onClearChat()
            }

            // 预留：相关直播间推荐
            // Button("相关推荐") { }

            Button("取消", role: .cancel) {
                showActionSheet = false
            }
        }
        .sheet(isPresented: $showStreamerInfo) {
            StreamerInfoSheet(room: room)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            QualitySelectionSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .tint(.primary)
    }
}

// MARK: - 清晰度选择 Sheet

/// 竖屏模式下的清晰度选择面板
private struct QualitySelectionSheet: View {
    let viewModel: RoomInfoViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let playArgs = viewModel.currentRoomPlayArgs {
                    ForEach(Array(playArgs.enumerated()), id: \.offset) { cdnIndex, cdn in
                        Section(cdn.cdn.isEmpty ? "线路 \(cdnIndex + 1)" : cdn.cdn) {
                            ForEach(Array(cdn.qualitys.enumerated()), id: \.offset) { urlIndex, quality in
                                Button {
                                    viewModel.changePlayUrl(cdnIndex: cdnIndex, urlIndex: urlIndex)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(quality.title)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if viewModel.currentCdnIndex == cdnIndex && viewModel.currentPlayQualityQn == quality.qn {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("暂无可用清晰度")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("清晰度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let room = LiveModel(
        userName: "测试主播",
        roomTitle: "测试直播间",
        roomCover: "",
        userHeadImg: "",
        liveType: .bilibili,
        liveState: "1",
        userId: "123",
        roomId: "456",
        liveWatchedCount: "1000"
    )
    ZStack {
        Color.black
        MoreActionsButton(
            room: room,
            onClearChat: {
                print("清屏")
            }
        )
    }
    .environment(RoomInfoViewModel(room: room))
}
