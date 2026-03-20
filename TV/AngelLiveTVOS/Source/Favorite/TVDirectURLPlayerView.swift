// TVDirectURLPlayerView.swift
// AngelLiveTVOS
//
// tvOS 壳 UI 直链播放器 - 适配 Siri Remote 交互

import SwiftUI
import AngelLiveDependencies

struct TVDirectURLPlayerView: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var playerCoordinator = KSVideoPlayer.Coordinator()
    @State private var playerOptions = KSOptions()
    @State private var showControls = true
    @State private var isPlaying = false
    @State private var isBuffering = false
    @State private var showStatisticsPanel = false
    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 播放器
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: playerOptions)
                .ignoresSafeArea()

            // 缓冲指示
            if isBuffering {
                ProgressView()
                    .scaleEffect(2.0)
                    .tint(.white)
            }

            // 控制层
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }

            if showStatisticsPanel {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        TVPlayerStatisticsPanel(playerCoordinator: playerCoordinator, streamURL: url) {
                            hideStatisticsPanel()
                        }
                        .frame(width: min(geometry.size.width * 0.4, 640), height: geometry.size.height - 80)
                        .padding(.vertical, 40)
                        .padding(.trailing, 48)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .zIndex(2)
            }
        }
        .onAppear {
            configurePlayer()
            scheduleAutoHide()
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
        .onExitCommand {
            if showStatisticsPanel {
                hideStatisticsPanel()
                return
            }
            dismiss()
        }
        .onPlayPauseCommand {
            togglePlayPause()
        }
        .onMoveCommand { direction in
            guard !showStatisticsPanel else { return }
            if direction == .down || direction == .up {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showControls.toggle()
                }
                if showControls { scheduleAutoHide() }
            }
        }
        .onChange(of: playerCoordinator.state) {
            let state = playerCoordinator.state
            switch state {
            case .readyToPlay, .bufferFinished:
                isPlaying = true
                isBuffering = false
            case .paused, .playedToTheEnd, .error:
                isPlaying = false
                isBuffering = false
            case .buffering:
                isBuffering = true
            default:
                break
            }
        }
    }

    // MARK: - 控制层 UI

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            topBar
            Spacer()
            // 底部控制栏
            bottomBar
        }
    }

    private var topBar: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.top, 40)
        .padding(.bottom, 60)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // 播放/暂停
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
            }
            .contextMenu {
                Button {
                    showStatisticsAction()
                } label: {
                    Label("视频信息统计", systemImage: "chart.bar.xaxis")
                }
            }

            // 刷新
            Button {
                refreshPlayback()
            } label: {
                Image(systemName: "arrow.trianglehead.2.counterclockwise")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .adaptiveGlassEffectCapsule()
        .padding(.bottom, 60)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.4), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 播放器配置

    private func configurePlayer() {
        playerOptions.userAgent = "libmpv"
        KSOptions.isAutoPlay = true

        let urlString = url.absoluteString.lowercased()
        if urlString.contains(".m3u8") {
            KSOptions.firstPlayerType = KSAVPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
        } else {
            KSOptions.firstPlayerType = KSMEPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
        }
    }

    // MARK: - 控制操作

    private func togglePlayPause() {
        if isPlaying {
            playerCoordinator.playerLayer?.pause()
            isPlaying = false
        } else {
            playerCoordinator.playerLayer?.play()
            isPlaying = true
        }
        resetAutoHide()
    }

    private func refreshPlayback() {
        playerCoordinator.playerLayer?.seek(time: .zero, autoPlay: true)
        resetAutoHide()
    }

    private func showStatisticsAction() {
        autoHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.28)) {
            showControls = false
            showStatisticsPanel = true
        }
    }

    private func hideStatisticsPanel() {
        withAnimation(.easeInOut(duration: 0.28)) {
            showStatisticsPanel = false
            showControls = true
        }
        scheduleAutoHide()
    }

    // MARK: - 自动隐藏

    private func scheduleAutoHide() {
        guard !showStatisticsPanel else { return }
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls = false
                    }
                }
            }
        }
    }

    private func resetAutoHide() {
        guard !showStatisticsPanel else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            showControls = true
        }
        scheduleAutoHide()
    }
}
