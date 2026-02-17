# Cookie/Session 迁移 M0 基线盘点（AngelLive + LiveParse）

更新时间：2026-02-17

## 范围

- AngelLive 宿主（iOS/macOS/tvOS + Shared）
- 本地 LiveParse 插件（`/Users/pangchong/Desktop/Git_Mini/LiveParse`）

## 1. 当前会话链路（谁产出、谁写入、谁消费、谁同步）

### 链路 A：应用启动自动补 Cookie（iOS/macOS）

1. 应用启动挂载 `.setupBilibiliCookieIfNeeded()`  
   - `iOS/AngelLive/AngelLive/AngelLiveApp.swift:30`  
   - `macOS/AngelLiveMacOS/AngelLiveMacOSApp.swift:68`
2. `BilibiliCookieManager.setupCookieIfNeeded` 检测本地 Cookie，为空则触发隐藏 WebView 抓取。  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieManager.swift:27`
3. 抓取后直接写入旧 key（`UserDefaults`）。  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieManager.swift:121`  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieManager.swift:126`

结论：该链路绕过 `BilibiliCookieSyncService`，不会写 `lastSyncedData`，也不会触发 iCloud 同步逻辑。

### 链路 B：登录页（iOS/macOS）

1. `BilibiliLoginViewModel` 从 WebView 提取 Cookie。  
   - iOS: `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:108`  
   - macOS: `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:118`
2. 先直接写 `UserDefaults`（cookie/uid）。  
   - iOS: `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:47`、`iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:137`  
   - macOS: `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:61`、`macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:147`
3. 再调用 `BilibiliCookieSyncService.setCookie` 再写一次并做同步。  
   - iOS: `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:145`  
   - macOS: `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:155`
4. 使用用户信息接口校验并再次写 uid。  
   - iOS: `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:182`  
   - macOS: `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:191`

结论：同一路径存在重复写入（ViewModel 本地写 + SyncService 再写）。

### 链路 C：同步与 tvOS

1. tvOS 启动时尝试 iCloud 拉取。  
   - `TV/AngelLiveTVOS/Other/SimpleLiveTVOSApp.swift:37`
2. tvOS 账号页可手动校验、手动输入、局域网同步，并通过 `BilibiliCookieSyncService` 写入。  
   - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:302`  
   - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:655`
3. tvOS 页面同时还写 `SettingStore.bilibiliCookie`（同 key，第二写入点）。  
   - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:351`  
   - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:539`  
   - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:659`

结论：tvOS 已有统一服务，但仍保留 UI 层并行写入。

## 2. 旧 key 直接调用点清单

检索口径：`SimpleLive.Setting.BilibiliCookie`、`LiveParse.Bilibili.uid`。  
AngelLive 命中 15 处，LiveParse(Bilibili.swift) 命中 4 处。

### 宿主核心层（建议保留为唯一入口）

- `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:76`
- `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:77`
- `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieManager.swift:114`
- `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieManager.swift:115`

### 宿主 UI/状态层（迁移后应改为只读 SessionManager）

- `Shared/AngelLiveCore/Sources/AngelLiveCore/Models/SettingStore.swift:11`
- `TV/AngelLiveTVOS/Source/Setting/SettingStore.swift:11`
- `macOS/AngelLiveMacOS/Views/SettingView.swift:13`
- `iOS/AngelLive/AngelLive/Components/ErrorView.swift:32`
- `iOS/AngelLive/AngelLive/Components/ErrorView.swift:37`
- `TV/AngelLiveTVOS/Source/Error/ErrorView.swift:28`
- `macOS/AngelLiveMacOS/AngelLiveMacOSApp.swift:42`（启动日志打印 cookie）

### 登录页（重复写入来源）

- `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:41`
- `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliLoginViewModel.swift:42`
- `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:41`
- `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliLoginViewModel.swift:42`

### LiveParse 插件层（与宿主强耦合）

- `/Users/pangchong/Desktop/Git_Mini/LiveParse/Sources/LiveParse/Bilibili.swift:19`
- `/Users/pangchong/Desktop/Git_Mini/LiveParse/Sources/LiveParse/Bilibili.swift:20`
- `/Users/pangchong/Desktop/Git_Mini/LiveParse/Sources/LiveParse/Bilibili.swift:24`
- `/Users/pangchong/Desktop/Git_Mini/LiveParse/Sources/LiveParse/Bilibili.swift:25`

## 3. “必须登录”接口盘点（当前实现）

### 已明确需要登录态（用于账号状态校验）

- `https://api.bilibili.com/x/member/web/account`
  - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:128`
  - `iOS/AngelLive/AngelLive/Views/Bilibili/BilibiliUserService.swift:23`
  - `macOS/AngelLiveMacOS/Views/Bilibili/BilibiliUserService.swift:23`
  - `TV/AngelLiveTVOS/Source/Setting/AccountManagementView.swift:313`

### 当前未实现（但迁移计划已定义）

- `getFollowingList` / 关注列表导入链路在 AngelLive 与 LiveParse 中均未落地（仅存在规划文档）。
  - 参考规划：`/Users/pangchong/Desktop/Git_Mini/LiveParse/Docs/CookieSessionMigrationPlan.md:131`

### 现状补充

- LiveParse 的大部分 Bilibili 内容接口并不强制登录；`getHeaders()` 会在无登录 cookie 时自动补 `buvid3/buvid4` 与随机 `DedeUserID`。  
  - `/Users/pangchong/Desktop/Git_Mini/LiveParse/Sources/LiveParse/Bilibili.swift:1176`

## 4. 风险清单（M0）

### 高风险

1. 退出登录不会真正清空 iCloud 侧 cookie。  
   `clearCookie()` 后调用 `syncToICloud()`，但 `syncToICloud` 对空 cookie 直接 `return`，旧值可能继续保留在 iCloud KVS。  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:211`  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:237`
2. 明文 cookie 存于 `UserDefaults` + iCloud KVS，不满足敏感凭据最小暴露。  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:186`  
   - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift:240`
3. 启动日志直接打印 cookie 状态，存在日志泄露面。  
   - `macOS/AngelLiveMacOS/AngelLiveMacOSApp.swift:42`

### 中风险

1. 多写入源并存（CookieManager / SyncService / LoginViewModel / SettingStore），状态来源不唯一。  
2. 登录校验逻辑重复实现 4 份（Core + iOS + macOS + tvOS），行为可能漂移。  
3. LiveParse 插件通过固定 key 直接耦合宿主存储，阻碍 SessionStore 抽象替换。

## 5. M1 前置输入（可直接开工）

1. 确定 `PlatformSessionManager` 作为唯一写入口，禁止 UI 和 ViewModel 直接写 key。  
2. 先在兼容层保留旧 key 只读迁移，新增写入走新 SessionStore。  
3. 优先修复“登出未清 iCloud”问题，再推进 Keychain 化。  
4. 统一 `validateCookie` 到 Core，iOS/macOS/tvOS 仅消费结果枚举。

