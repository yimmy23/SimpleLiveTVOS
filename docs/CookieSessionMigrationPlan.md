# Cookie/Session Migration Plan（AngelLive + LiveParse）

更新时间：2026-02-18

## 执行顺序

1. M0 基线盘点
2. M1 会话基础层
3. M2 Bilibili 接入改造
4. M3 Host.http 鉴权注入
5. M4 Bilibili 关注列表导入
6. M5 多平台模板化

## 当前进度

### M0 基线盘点

- 状态：已完成
- 交付：
  - `docs/CookieSessionMigrationM0Baseline.md`
  - 旧 key 调用点、风险清单、必须登录接口盘点

### M1 会话基础层

- 状态：已完成
- 已落地：
  - `PlatformSessionManager`（`actor`）
  - `SessionStore`（Keychain 敏感字段 + UserDefaults 元数据）
  - 旧 key 迁移入口（legacy -> session）
  - 会话平台扩展：`bilibili / douyin / kuaishou`
  - 新增统一登录入口：`loginWithCookie(...)`（一期用于接入三平台 cookie 登录）
- 代码：
  - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/PlatformSessionManager.swift`

### M2 Bilibili 接入改造

- 状态：已完成
- 已完成：
  - 修复退出登录未清 iCloud 残留 Cookie 风险
  - iOS/macOS 登录 ViewModel 去除旧 key 直写，统一走 `BilibiliCookieSyncService`
  - tvOS 账号页移除 UI 层对旧 key 的直接写入
  - `BilibiliCookieManager` 改为通过 `BilibiliCookieSyncService` 读写
  - `BilibiliCookieSyncService` 增加与 `PlatformSessionManager` 的镜像写入/清理
  - 新增 `BilibiliAccountService`，统一 iOS/macOS/tvOS/Core 的 Cookie 校验与用户信息请求入口
  - iOS/macOS/tvOS 构建验证通过（tvOS 采用 arm64 模拟器目的地）
  - `BilibiliCookieSyncService` 读路径改为 runtime cache + session snapshot，旧 key 仅保留兼容兜底/双写
  - iOS/macOS/tvOS 登录态 session 写入统一收敛到 `PlatformSessionManager.loginWithCookie(...)`
  - Core 构建验证：`Shared/AngelLiveCore` 执行 `swift build` 通过

### 里程碑记录

- 2026-02-18
  - 提交：`19065b6`
  - 内容：完成 M1 + M2 核心收敛（会话基础层、写入路径统一、校验路径统一、迁移文档落地）
- 2026-02-18
  - 提交：`(working tree, 未提交)`
  - 内容：完成 `BilibiliCookieSyncService` 去 legacy 读依赖（session 快照主路径 + 兼容兜底），并通过 Core 构建验证
- 2026-02-18
  - 提交：`(working tree, 未提交)`
  - 内容：`PlatformSessionManager` 扩展三平台会话 ID，并新增 `loginWithCookie` 一期入口
- 2026-02-18
  - 提交：`(working tree, 未提交)`
  - 内容：三端 Bilibili 登录态会话写入改为统一走 `loginWithCookie(...)`
- 2026-02-18
  - 提交：`(working tree, 未提交)`
  - 内容：iOS 设置页改为“平台账号登录”二级菜单（哔哩哔哩/抖音/快手）并统一弹出 WebView 登录
- 2026-02-18
  - 提交：`(working tree, 未提交)`
  - 内容：抖音 cookie 传递改为插件入口（`setCookie/clearCookie`），宿主侧移除对 LiveParse 内部 key 直写，并完成 iOS 真机构建验证

### M3 Host.http 鉴权注入

- 状态：进行中（抖音一期已落地）
- 目标：
  - `sessionScope` / `authRequired`
  - 自动注入 Cookie/鉴权头
  - 处理 `Set-Cookie` 回写 session
- 已落地（抖音）：
  - Douyin JS 插件新增 `setCookie` / `clearCookie` 入口，插件内维护 runtime cookie
  - 插件请求统一优先使用 runtime cookie（payload 传入 cookie 时会自动刷新 runtime）
  - `LiveParse/Douyin.swift` 的 JS 插件调用路径移除 `ensureCookie(...)` 注入，改为纯插件消费 cookie
  - `PlatformSessionLiveParseBridge` 改为调用插件入口同步/清理 cookie，不再写 LiveParse 内部 `UserDefaults` key
  - iOS 真机构建验证通过（`generic/platform=iOS`，`CODE_SIGNING_ALLOWED=NO`）
- 后续统一要求（其余插件）：
  - 所有涉及登录态/鉴权 cookie 的插件，统一改为 `setCookie` / `clearCookie` 入口 + 插件内 runtime cookie
  - 宿主统一通过会话层同步 cookie，禁止再依赖插件调用时临时拼接 `payload.cookie`
  - 优先顺序：`bilibili`、`ks`，随后按实际登录需求扩展到其他平台插件

### M4 Bilibili 关注列表导入

- 状态：未开始

### M5 多平台模板化

- 状态：未开始
- 预设要求：
  - 平台插件标准化 cookie 交互协议（`setCookie` / `clearCookie` / runtime cookie）
