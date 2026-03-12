//
//  UnifiedPlayerControlOverlay.swift
//  AngelLive
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies
import UIKit

struct UnifiedPlayerControlOverlay: View {
    @Environment(RoomInfoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isIPadFullscreen) private var isIPadFullscreen: Binding<Bool>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.safeAreaInsetsCustom) private var safeAreaInsets

    let bridge: PlayerControlBridge
    @Binding var showVideoSetting: Bool
    @Binding var showDanmakuSettings: Bool

    @State private var autoHideTask: Task<Void, Never>?
    @State private var isSettingsPopupOpen = false
    @State private var statusBarVM = StatusBarViewModel()

    // 将 bridge.isMaskShow 的值提取到本地 @State 以便 SwiftUI 能可靠追踪变化
    @State private var isMaskVisible: Bool = true

    // MARK: - Computed Properties

    /// 是否处于全屏模式（iPad全屏 或 iPhone横屏）
    private var isFullscreen: Bool {
        if AppConstants.Device.isIPad {
            return isIPadFullscreen.wrappedValue
        }
        return isLandscape
    }

    /// 检测是否为横屏
    private var isLandscape: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .compact ||
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    /// iPhone 横屏时需要忽略安全区
    private var shouldIgnoreSafeArea: Bool {
        isLandscape && !AppConstants.Device.isIPad
    }

    /// 控制层基础内边距
    private var controlPadding: CGFloat {
        isLandscape ? 20 : 12
    }

    /// iPhone 横屏时，状态栏内容右侧内收
    private var statusBarTrailingInset: CGFloat {
        guard isLandscape && !AppConstants.Device.isIPad else { return 0 }
        let currentTrailingInset = controlPadding / 2
        let targetTrailingInset = safeAreaInsets.trailing + 8
        return max(0, targetTrailingInset - currentTrailingInset)
    }

    /// 是否有弹窗/菜单展开
    private var isPopupOpen: Bool {
        showDanmakuSettings || showVideoSetting || isSettingsPopupOpen
    }

    var body: some View {
        ZStack {
            // 底部渐变背景（锁定时隐藏）
            if !bridge.isLocked.wrappedValue {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(AppConstants.PlayerUI.Opacity.overlayLight),
                            .black.opacity(AppConstants.PlayerUI.Opacity.overlayStrong)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .ignoresSafeArea()
                .opacity(isMaskVisible ? 1 : 0)
                .allowsHitTesting(false)
            }

            // 控制按钮层
            ZStack {
                // 左侧中间：锁定按钮（始终显示）
                lockButton

                // 锁定时隐藏其余所有控制
                if !bridge.isLocked.wrappedValue {
                    // 左上角：返回按钮
                    backButtonLayer

                    // 右上角：状态栏 + 功能按钮
                    topRightLayer

                    // 中间：暂停大按钮
                    if !bridge.isPlaying {
                        Button {
                            bridge.togglePlayPause()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 62, height: 62)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // 左下角：播放/暂停、刷新
                    bottomLeftLayer

                    // 右下角：弹幕、清晰度、全屏
                    bottomRightLayer
                }
            }
            .padding(controlPadding)
            .opacity(isMaskVisible ? 1 : 0)
            .allowsHitTesting(isMaskVisible)
            .ignoresSafeArea(shouldIgnoreSafeArea ? .all : [])
            // 触摸控制层时重置自动隐藏
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        if isMaskVisible && !isPopupOpen {
                            startAutoHideTimer()
                        }
                    }
            )
        }
        .tint(.white)
        // 双向同步 bridge.isMaskShow ↔ isMaskVisible
        .onChange(of: bridge.isMaskShow.wrappedValue) { _, newValue in
            if isMaskVisible != newValue {
                isMaskVisible = newValue
            }
        }
        .onChange(of: isMaskVisible) { _, newValue in
            if bridge.isMaskShow.wrappedValue != newValue {
                bridge.isMaskShow.wrappedValue = newValue
            }
            // 自动隐藏计时器管理
            if newValue && !isPopupOpen {
                startAutoHideTimer()
            } else if !newValue {
                cancelAutoHideTimer()
            }
        }
        .onChange(of: showDanmakuSettings) { _, isShowing in
            if !isShowing && isMaskVisible && !isPopupOpen {
                startAutoHideTimer()
            } else if isShowing {
                cancelAutoHideTimer()
            }
        }
        .onChange(of: showVideoSetting) { _, isShowing in
            if !isShowing && isMaskVisible && !isPopupOpen {
                startAutoHideTimer()
            } else if isShowing {
                cancelAutoHideTimer()
            }
        }
        .onAppear {
            isMaskVisible = bridge.isMaskShow.wrappedValue
            if isMaskVisible && !isPopupOpen {
                startAutoHideTimer()
            }
        }
        .onDisappear {
            cancelAutoHideTimer()
        }
    }

    // MARK: - Lock Button

    private var lockButton: some View {
        VStack {
            Spacer()
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        bridge.isLocked.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: bridge.isLocked.wrappedValue ? "lock.fill" : "lock.open")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, isLandscape ? 30 : 0)
                Spacer()
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Back Button

    private var backButtonLayer: some View {
        VStack {
            HStack {
                Button {
                    handleBackButton()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .padding(10)
                        .contentShape(Rectangle())
                }
                .padding(-10)
                .buttonStyle(.plain)
                Spacer()
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Top Right (Status Bar + PiP + Settings)

    private var topRightLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // 状态栏（仅横屏/全屏时显示）
                    if isLandscape || isIPadFullscreen.wrappedValue {
                        statusBarContent
                            .padding(.trailing, statusBarTrailingInset)
                    }
                    HStack(spacing: 16) {
                        if bridge.supportsPictureInPicture {
                            Button {
                                bridge.togglePictureInPicture()
                            } label: {
                                Image(systemName: "pip")
                                    .frame(width: 30, height: 30)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        SettingsButton(
                            showVideoSetting: $showVideoSetting,
                            showDanmakuSettings: $showDanmakuSettings,
                            onDismiss: { dismiss() },
                            onPopupStateChanged: { isOpen in
                                isSettingsPopupOpen = isOpen
                                if isOpen {
                                    cancelAutoHideTimer()
                                } else if isMaskVisible {
                                    startAutoHideTimer()
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.top, isLandscape ? -controlPadding : 0)
            .padding(.trailing, isLandscape ? -controlPadding / 2 : 0)
            Spacer()
        }
    }

    // MARK: - Bottom Left (Play/Pause + Refresh)

    private var bottomLeftLayer: some View {
        VStack {
            Spacer()
            HStack {
                HStack(spacing: 16) {
                    Button {
                        bridge.togglePlayPause()
                    } label: {
                        Image(systemName: bridge.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 30, height: 30)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        bridge.refreshPlayback()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 30, height: 30)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                Spacer()
            }
        }
    }

    // MARK: - Bottom Right (Danmu + Quality + Fullscreen)

    private var bottomRightLayer: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        viewModel.danmuSettings.showDanmu.toggle()
                    } label: {
                        Image(systemName: viewModel.danmuSettings.showDanmu ? "captions.bubble.fill" : "captions.bubble")
                            .frame(width: 30, height: 30)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    qualityMenu

                    Button {
                        toggleOrientationOrFullscreen()
                    } label: {
                        Image(systemName: fullscreenIconName)
                            .frame(width: 30, height: 30)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Status Bar Content

    @ViewBuilder
    private var statusBarContent: some View {
        HStack(spacing: 4) {
            Text(statusBarVM.formattedTime)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: statusBarVM.batteryIconName)
                .font(.system(size: 11))
                .foregroundStyle(statusBarVM.batteryColor)
        }
    }

    // MARK: - Quality Menu

    private var qualityMenu: some View {
        Menu {
            if let playArgs = viewModel.currentRoomPlayArgs {
                ForEach(Array(playArgs.enumerated()), id: \.offset) { cdnIndex, cdn in
                    Menu {
                        ForEach(Array(cdn.qualitys.enumerated()), id: \.offset) { urlIndex, quality in
                            Button {
                                viewModel.changePlayUrl(cdnIndex: cdnIndex, urlIndex: urlIndex)
                            } label: {
                                HStack {
                                    Text(quality.title)
                                    if viewModel.currentCdnIndex == cdnIndex && viewModel.currentPlayQualityQn == quality.qn {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(cdn.cdn.isEmpty ? "线路 \(cdnIndex + 1)" : cdn.cdn)
                    }
                }
            }
        } label: {
            Text(viewModel.currentPlayQualityString)
                .foregroundStyle(.white)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .tint(.primary)
    }

    // MARK: - Helpers

    private var fullscreenIconName: String {
        if AppConstants.Device.isIPad {
            return isIPadFullscreen.wrappedValue ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        }
        return isCurrentLandscape ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
    }

    /// 处理返回按钮点击
    /// - iPad 全屏时：退出全屏
    /// - iPhone 横屏时：切换回竖屏（不 dismiss）
    /// - 其他情况：dismiss 返回上一页
    private func handleBackButton() {
        if AppConstants.Device.isIPad && isIPadFullscreen.wrappedValue {
            isIPadFullscreen.wrappedValue = false
            return
        } else if !AppConstants.Device.isIPad && isCurrentLandscape {
            // iPhone 横屏：先切回竖屏
            KSOptions.supportedInterfaceOrientations = .portrait

            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }

            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .portrait
            )

            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                print("❌ 退出全屏失败: \(error)")
            }

            if let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        } else {
            // 竖屏：返回上一页
            dismiss()
            KSOptions.supportedInterfaceOrientations = .portrait
        }
    }

    private func toggleOrientationOrFullscreen() {
        if AppConstants.Device.isIPad {
            isIPadFullscreen.wrappedValue.toggle()
            return
        }

        let targetOrientation: UIInterfaceOrientationMask = isCurrentLandscape ? .portrait : .landscapeRight
        KSOptions.supportedInterfaceOrientations = targetOrientation

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
            interfaceOrientations: targetOrientation
        )

        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            print("❌ 方向更新失败: \(error)")
        }

        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private var isCurrentLandscape: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return false
        }
        return windowScene.interfaceOrientation.isLandscape
    }

    // MARK: - Auto Hide Timer

    private func startAutoHideTimer() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled && !isPopupOpen {
                isMaskVisible = false
            }
        }
    }

    private func cancelAutoHideTimer() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }
}
