# Cookie/Session Migration Plan（AngelLive + LiveParse）

更新时间：2026-02-17

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

- 状态：已完成（骨架）
- 已落地：
  - `PlatformSessionManager`（`actor`）
  - `SessionStore`（Keychain 敏感字段 + UserDefaults 元数据）
  - 旧 key 迁移入口（legacy -> session）
- 代码：
  - `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/PlatformSessionManager.swift`

### M2 Bilibili 接入改造

- 状态：进行中
- 已完成：
  - 修复退出登录未清 iCloud 残留 Cookie 风险
  - iOS/macOS 登录 ViewModel 去除旧 key 直写，统一走 `BilibiliCookieSyncService`
  - tvOS 账号页移除 UI 层对旧 key 的直接写入
  - `BilibiliCookieManager` 改为通过 `BilibiliCookieSyncService` 读写
  - `BilibiliCookieSyncService` 增加与 `PlatformSessionManager` 的镜像写入/清理
  - 新增 `BilibiliAccountService`，统一 iOS/macOS/tvOS/Core 的 Cookie 校验与用户信息请求入口
- 待完成：
  - 进一步降低 `BilibiliCookieSyncService` 对 legacy key 的依赖（保留兼容迁移）

### M3 Host.http 鉴权注入

- 状态：未开始
- 目标：
  - `sessionScope` / `authRequired`
  - 自动注入 Cookie/鉴权头
  - 处理 `Set-Cookie` 回写 session

### M4 Bilibili 关注列表导入

- 状态：未开始

### M5 多平台模板化

- 状态：未开始
