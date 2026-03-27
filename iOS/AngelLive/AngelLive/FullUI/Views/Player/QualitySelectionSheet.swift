//
//  QualitySelectionPanel.swift
//  AngelLive
//

import SwiftUI
import AngelLiveCore

/// 播放器内嵌清晰度/线路选择面板，右侧滑入覆盖，不离开播放画面即可切换
struct QualitySelectionPanel: View {
    @Binding var isShowing: Bool
    @Environment(RoomInfoViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var panelWidth: CGFloat {
        if AppConstants.Device.isIPad { return 360 }
        return horizontalSizeClass == .compact ? 280 : 320
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.lg) {
                    if let playArgs = viewModel.currentRoomPlayArgs {
                        ForEach(Array(playArgs.enumerated()), id: \.offset) { cdnIndex, cdn in
                            cdnSection(cdnIndex: cdnIndex, cdn: cdn, playArgs: playArgs)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .adaptivePanelGlassEffect(cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("清晰度")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                if let currentTitle = normalizedQualityTitle {
                    Text("当前：\(currentTitle)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 8)

            Button {
                isShowing = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                    .adaptivePanelCircleGlassEffect()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - CDN Section

    @ViewBuilder
    private func cdnSection(cdnIndex: Int, cdn: LiveQualityModel, playArgs: [LiveQualityModel]) -> some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
            // Section 标题
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                Text(cdn.cdn.isEmpty ? "线路 \(cdnIndex + 1)" : cdn.cdn)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))

            // 清晰度列表
            VStack(spacing: 2) {
                ForEach(Array(cdn.qualitys.enumerated()), id: \.offset) { urlIndex, quality in
                    let selected = viewModel.currentCdnIndex == cdnIndex && viewModel.currentQualityIndex == urlIndex
                    Button {
                        viewModel.changePlayUrl(cdnIndex: cdnIndex, urlIndex: urlIndex)
                        isShowing = false
                    } label: {
                        HStack(spacing: 10) {
                            Text(RoomPlaybackResolver.qualityDisplayTitle(quality, in: playArgs))
                                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : .white.opacity(0.8))

                            Spacer()

                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .background(selected ? Color.accentColor.opacity(0.2) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var normalizedQualityTitle: String? {
        let trimmed = viewModel.currentPlayQualityString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "清晰度" else { return nil }
        return trimmed
    }
}

// MARK: - Glass Effect (private to this file)

private extension View {
    @ViewBuilder
    func adaptivePanelGlassEffect(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.interactive().tint(.black.opacity(AppConstants.PlayerUI.Opacity.overlayStrong)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    func adaptivePanelCircleGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.interactive().tint(.black.opacity(AppConstants.PlayerUI.Opacity.overlayStrong)),
                in: .circle
            )
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}
