## 播放详情页重复请求/stop 循环排查记录（iPad 横屏收藏进入）

- **症状**：进入收藏→播放详情（iPad 横屏）时，日志持续打印 `stop()` / `clear formatCtx`，CPU/内存飙升；网络层看到 `getCdnTokenInfo`、`getPlayerArgs` 被高频请求。
- **主要原因**：
  - SwiftUI 重建导致 KSVideoPlayer/Coordinator/Model 反复创建，播放器多次 stop/重连。
  - 播放地址加载没有防抖，视图多次刷新时重复调用 `loadPlayURL()` / `getPlayArgs`。
  - iPad 横屏时的视频尺寸探测任务重复触发。
- **修复要点**：
  1. **固定播放器实例**  
     - 在 `DetailPlayerView` 顶层持有 `@StateObject playerCoordinator` 和 `@StateObject playerModel`，下传到 `PlayerContentView`。  
     - `PlayerContentView` 内不再新建模型，只在 `.task` 中同步 `coordinator/options/url`，URL 不变时不更新。
  2. **播放地址加载防抖**  
     - `RoomInfoViewModel.loadPlayURL(force:)` 增加 `isFetchingPlayURL` + `hasLoadedPlayURL`，默认仅首播调用；刷新按钮用 `force: true`。
  3. **iPad 跳过尺寸探测**  
     - iPad 直接使用 16:9，避免尺寸探测任务导致重建/stop。
  4. **可选防止过度重连**（视需求开启）  
     - `KSOptions.isSecondOpen = false`（已取消双路自动重开，若需恢复请评估重试风控）。
- **排查建议**：
  - 观察 `loadPlayURL` / `getPlayArgs` 调用次数（断点或打印），确认防抖是否生效。
  - 若再次出现 stop 循环，优先检查：是否引入新的状态刷新导致 `PlayerContentView` 重建；是否在其它路径重复调用 `loadPlayURL(force: true)`。

