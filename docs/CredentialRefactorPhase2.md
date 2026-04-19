# 会话层重构 Phase 2 — 剩余工作清单

更新时间：2026-04-19
关联 commit：`refactor: 会话层统一 pluginId & 凭证校验 manifest 驱动`（已落地 Core 层）

## 背景

Phase 1 已完成 Core 层的基础改造：平台身份键收敛为字符串 pluginId、凭证校验下沉到插件、manifest 扩展 auth/loginFlow 字段、新增登录入口注册表。当前 Core 模块可独立编译；UI 层与存量会话服务仍引用过渡 shim，本期继续收敛。

Phase 2 目标：宿主端 UI 完全数据化（不再硬编码任何平台元数据），存量会话服务整体替换，三端 xcodebuild 全通过。

## 待办分组

### 1. Core 服务重写

- [ ] 新增通用凭证同步服务（路径建议 `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/PlatformCredentialSyncService.swift`）
  - iCloud 记录键：`angellive_session_sync_{pluginId}`（已有命名延用）
  - Bonjour 服务类型沿用 `_angellive-cookie._tcp`（避免跨端版本错位）
  - 对外暴露 `@Published loggedInByPluginId: [String: Bool]` 替代按平台写死的 `isLoggedIn`
  - 按 pluginId 对外索引：`isLoggedIn(pluginId:)` / `setManualCookie(pluginId:cookie:)`
  - 保留能力：`iCloudSyncEnabled` / `lastICloudSyncTime` / `discoveredDevices` / `startBonjourListener` / `startBonjourBrowsing` / `sendAllToDevice` / `syncAllToICloud` / `syncAllFromICloud` / `fetchCloudSyncPreview` / `getLocalAuthenticatedPluginIds` / `handleMultiPlatformSyncData`
  - 平台专属字段提取（如 uid 识别）统一走 `manifest.loginFlow.uidCookieNames`，遍历优先级返回首个非空
- [ ] 删除文件内 `LegacyPlatformSessionID` 过渡 shim
- [ ] 删除存量会话服务与账号服务及其依赖文件（Bilibili 专属 Service/Manager/Cookie 模型）
- [ ] SessionStore 启动迁移：`bilibili_cookie_sync` → `angellive_session_sync_bilibili` 一次性迁移后删旧 record
- [ ] 旧 UserDefaults 键（含 `SimpleLive.Setting.BilibiliCookie` / `LiveParse.Bilibili.uid` / `BilibiliCookieSyncService.*`）读取一次迁入新 PlatformSession 后清理

### 2. UI 层 — iOS

- [ ] 新增通用 `PlatformLoginWebSheet.swift`
  - 入参：`pluginId: String`
  - 流程：从 `PlatformLoginRegistry.shared.entry(pluginId:)` 读取 `loginFlow` → 装配 WKWebView → 监听 Cookie jar 触达 `authSignalCookies` 任一命中 → 调 `PlatformSessionManager.loginWithCookie`（内部走插件 `validateCredential`）
  - UID 提取遍历 `loginFlow.uidCookieNames`
  - 成功判定辅以 `successURLKeyword` / `successTitleKeyword` / `postRedirectDelay`
- [ ] 改造 `PlatformAccountLoginView.swift`
  - 删除内部 `PlatformAccountItem` enum（含 loginURL / cookieDomainHints / extraCookieNames / containsAuthenticatedCookie 等全部硬编码）
  - 列表数据源改为 `PlatformLoginRegistry.shared.availablePlatforms()`
  - `.sheet` 不再按平台分支，所有已声明 loginFlow 的平台统一走 `PlatformLoginWebSheet`
  - 登录状态取自 `PlatformCredentialSyncService.loggedInByPluginId`
- [ ] 删除首批接入平台的专属登录页面、账号 ViewModel、账号信息模型、用户服务、跨端同步 Sheet、调试视图（原 `FullUI/Views/Bilibili/*` 与 `FullUI/Components/BilibiliCookieDebugView.swift`）
- [ ] 清理 `SettingView` 里指向已删除调试入口的引用

### 3. UI 层 — macOS

- [ ] 新增 `PlatformLoginWebSheet.swift`（NSViewRepresentable + 2.0s polling 形态保留）
- [ ] 改造 `SettingView.swift`
  - 删除 `[PlatformSessionID: Bool]` 状态字典，改为 pluginId 索引
  - `.sheet` 分支合并，统一走新通用面板
- [ ] 删除对应 `Views/Bilibili/*` 下所有文件与 `MacOSPlatformCookieWebLoginView.swift`

### 4. UI 层 — tvOS

- [ ] 改造 `AccountManagementView.swift`
  - 删除 `TVPlatformItem` enum、`BilibiliUserInfoTV` 结构、`supportsHTTPValidation` 分支
  - 通用化 `PlatformDetailPageView` / `PlatformManualInputPageView` / `LANSyncPageView`
  - 登录状态一致走 `PlatformSessionManager.validateSession(pluginId:)`
  - 手动输入帮助文本从 `loginFlow.requiredCookieHint` / `loginFlow.websiteHost` 读
- [ ] 本端仍保留：手动粘贴 Cookie、局域网同步接收、远程 QR 输入（`RemoteInputService` 无需改动）

### 5. 三端 App 入口

- [ ] iOS / macOS / tvOS 三端 App 入口切换到 `PlatformCredentialSyncService.shared`
- [ ] 启动流程中 `syncFromICloud + syncAllPlatformsFromICloud` 合并为 `syncAllFromICloud`
- [ ] 启动后触发 `PlatformSessionLiveParseBridge.syncFromPersistedSessionsOnLaunch()` 保持现状

### 6. 插件侧（独立仓库完成）

- [ ] 首批接入平台 manifest 补 `auth` 字段（已在 1.x 版本实现 credential 4 入口，补声明即可）
- [ ] 同 manifest 补 `loginFlow` 字段，最小形态如下：
  ```json
  {
    "auth": {
      "required": false,
      "credentialKinds": ["cookie"],
      "supportsStatusCheck": true,
      "supportsValidation": true
    },
    "loginFlow": {
      "kind": "webview",
      "loginURL": "<登录入口 URL>",
      "cookieDomains": ["<目标域名>"],
      "authSignalCookies": ["<已登录判定 Cookie 名>"],
      "uidCookieNames": ["<uid 源 Cookie>"],
      "successURLKeyword": "<成功跳转 URL 关键词，可选>",
      "successTitleKeyword": "<成功页标题关键词，可选>",
      "postRedirectDelay": 3.0,
      "requiredCookieHint": "<tvOS 手动输入提示，可选>",
      "websiteHost": "<tvOS 帮助文本里的域名，可选>"
    }
  }
  ```
- [ ] 其他平台按同样形式逐步补齐；未声明 `loginFlow` 的插件本端不会出现在登录列表中

## 验收

### 构建门槛
```bash
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLive       -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLiveMacOS  -destination 'platform=macOS' build
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLiveTVOS   -destination 'platform=tvOS Simulator,name=Apple TV' build
```

### 端到端
1. 通用登录面板：iOS/macOS 登录任一已声明 loginFlow 的平台 → 状态显示已登录；退出 → 状态变未登录
2. 持久化：登录后重启 app → 状态保持，启动时 validateCredential 仍返回 valid
3. tvOS：手动粘贴 Cookie → 走插件 validateCredential；iOS/macOS 端一键「同步到 tvOS」→ 多平台 payload 正确落地
4. iCloud 同步：iOS 登录 → 关闭 → macOS 打开自动拉下
5. 未声明 loginFlow 的平台：登录列表不可见
6. 业务链路：列表、播放、弹幕仍能正确取到登录态（沿用 `authMode: "platform_cookie"`）

### 回归项
- 旧 CookieSyncService 的观测属性订阅点全部迁移
- `PlatformIconProvider` 图标查找正常（按 liveType 仍可查到）
- `PluginAvailabilityService` 刷新后登录列表即时更新

## 风险与对策

- **迁移一致性**：新旧 CloudKit record 并存 → 启动迁移完成后立即标记 `AngelLive.Migration.pluginIdSessionV2`，避免重复迁
- **UI 空窗期**：新通用面板上线前，旧面板已删除 → 必须同 PR 内完成替换，不允许拆分
- **手动输入兼容**：部分平台无 URL 成功标识 → loginFlow 允许全部关键词为空，以 `authSignalCookies` 命中为唯一准绳
- **tvOS 手动输入本**：确保无 loginFlow 时 tvOS 给默认降级提示而非崩溃

## 后续衔接

Phase 2 完成后，宿主端将不再有任何平台专属代码。新平台接入流程：
1. 在独立仓库发布 plugin bundle
2. manifest 补 auth + loginFlow 声明
3. 本端无需改代码，下次启动即可在登录列表中出现

后续规划（Phase 3+）：
- 插件登录声明迁移到 `credential` 顶层统一 payload（对齐 LiveParse 仓库 `PluginAdvancedCapabilitiesPlan.md` §1.6 第二阶段）
- 关注列表导入能力（参照 `CookieSessionMigrationPlan.md` M4）
