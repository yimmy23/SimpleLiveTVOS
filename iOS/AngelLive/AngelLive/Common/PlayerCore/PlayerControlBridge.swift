//
//  PlayerControlBridge.swift
//  AngelLive
//

import Foundation
import SwiftUI

/// 播放控制兼容层：UI 只依赖这个桥接结构，不直接依赖具体播放器内核。
struct PlayerControlBridge {
    var isPlaying: Bool
    var isBuffering: Bool
    var supportsPictureInPicture: Bool
    var togglePlayPause: () -> Void
    var refreshPlayback: () -> Void
    var togglePictureInPicture: () -> Void

    // MARK: - 控制层状态

    /// 控制层显示/隐藏
    var isMaskShow: Binding<Bool>
    /// 锁定状态（锁定后禁用所有手势和控制按钮）
    var isLocked: Binding<Bool>
}
