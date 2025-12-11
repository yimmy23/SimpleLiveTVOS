# KSPlayer PiP 修复记录

## 问题描述

macOS 上画中画(PiP)功能存在以下问题：

1. **"返回画中画"按钮失效** - 点击 PiP 窗口的"返回画中画"按钮后，该按钮和"关闭"按钮都会失效
2. **视频比例问题** - PiP 窗口中视频只显示在角落，比例不正确（macOS 26 官方 bug）

## 修复方案

### 问题 1 修复：completionHandler 未调用

**文件**: `KSPlayer/Sources/KSPlayer/AVPlayer/KSPlayerLayer.swift`

**位置**: `KSComplexPlayerLayer` 的 `AVPictureInPictureControllerDelegate` 扩展

**原代码**:
```swift
@MainActor
public func pictureInPictureController(_: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler _: @escaping (Bool) -> Void) {
    pipStop(restoreUserInterface: true)
}
```

**修复后**:
```swift
@MainActor
public func pictureInPictureController(_: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    pipStop(restoreUserInterface: true)
    completionHandler(true)
}
```

**原因**: 根据 Apple 文档，必须调用 `completionHandler(true)` 告诉系统界面已恢复，否则系统会认为恢复失败，导致 PiP 控制按钮失效。

### 问题 2：视频比例问题

**状态**: 未修复（Apple 官方 bug）

macOS 26 上 `AVPictureInPictureController` + `AVSampleBufferDisplayLayer` 存在视频比例显示问题，视频只显示在 PiP 窗口的角落而不是按比例缩放填充整个窗口。

这是 Apple 的官方 bug，KSPlayer 作者已确认，等待 Apple 修复。

## 适用版本

- KSPlayer 老版本（新版本已修复问题 1，但存在闪退问题）
- macOS 26 (Tahoe)

## 备注

由于使用的是 KSPlayer 老版本（新版本有闪退问题），每次 SPM 重新拉取依赖后需要手动应用此修复。
