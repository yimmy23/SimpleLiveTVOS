# 壳 UI 实现进度跟踪

## 概述

当本地没有 LiveParse JS 插件时，显示「壳 UI」替代现有完整 UI。壳 UI 包含 4 个 Tab：收藏、配置、历史、设置。用户可通过配置页添加网络视频链接（直接播放）或插件源地址（安装插件后切换到完整 UI）。

## 实现范围

- [x] 方案设计
- [~] iOS 端实现
- [ ] macOS 端实现（后续）
- [ ] tvOS 端实现（后续）

---

## iOS 端实现计划

### Phase 1：基础设施 ✅

#### 1.1 插件检测服务（AngelLiveCore 共享层）
- [x] 新建 `PluginAvailabilityService`
  - 文件：`Shared/AngelLiveCore/Sources/AngelLiveCore/Services/PluginAvailabilityService.swift`
  - 检测 builtIn + sandbox 是否有任何可用插件
  - 提供 `hasAvailablePlugins: Bool` 属性
  - 插件安装成功后可调用 `refresh()` 刷新状态

#### 1.2 网络链接收藏模型（AngelLiveCore 共享层）
- [x] 新建 `StreamBookmark` 模型
  - 文件：`Shared/AngelLiveCore/Sources/AngelLiveCore/Models/StreamBookmark.swift`
  - 字段：id、title、url、addedAt、lastPlayedAt
  - Codable + Sendable + Identifiable + Hashable
- [x] 新建 `StreamBookmarkService`（CloudKit 同步）
  - 文件：`Shared/AngelLiveCore/Sources/AngelLiveCore/Services/StreamBookmarkService.swift`
  - 独立 CKRecord 类型 `stream_bookmarks`（不与现有 `favorite_streamers` 共用）
  - CRUD 操作 + 本地缓存 + iCloud 同步

#### 1.3 插件源管理模型（AngelLiveCore 共享层）
- [x] 新建 `PluginSourceManager`
  - 文件：`Shared/AngelLiveCore/Sources/AngelLiveCore/Services/PluginSourceManager.swift`
  - 管理用户添加的插件源 URL 列表（UserDefaults 持久化）
  - 调用 `LiveParsePluginUpdater.fetchIndex()` 获取远程索引
  - 调用 `LiveParsePluginUpdater.installAndActivate()` 安装插件
  - `RemotePluginDisplayItem` 带安装状态的 UI 模型
  - 支持单个安装和全部安装

### Phase 2：壳 UI 视图层（iOS）✅

#### 2.1 ContentView 路由
- [x] 修改 `iOS/AngelLive/ContentView.swift`
  - 新增 `ShellTabSelection` 枚举（favorite / config / history / settings）
  - 新增 `PluginAvailabilityService`、`StreamBookmarkService`、`PluginSourceManager` 状态
  - 根据 `hasAvailablePlugins` 切换完整 UI / 壳 UI
  - 支持 iOS 17 和 iOS 18+ 两套 TabView
  - 插件安装成功后通过 `.onChange` 自动切换到完整 UI（带动画）

#### 2.2 壳 - 收藏 Tab
- [x] 新建 `ShellFavoriteView`
  - 文件：`iOS/AngelLive/AngelLive/Views/Shell/ShellFavoriteView.swift`
  - 显示用户通过配置添加的网络链接列表
  - 支持左滑删除、右滑编辑
  - 编辑弹出 `EditBookmarkSheet`
  - CloudKit 自动同步

#### 2.3 壳 - 配置 Tab
- [x] 新建 `ShellConfigView`
  - 文件：`iOS/AngelLive/AngelLive/Views/Shell/ShellConfigView.swift`
  - 添加网络视频区域：输入标题+链接，保存到收藏
  - 插件源管理区域：添加/删除源地址，拉取索引
  - `PluginListSheet`：显示可用插件列表，支持单个/全部安装
  - 安装成功后自动触发 `PluginAvailabilityService.refresh()`

#### 2.4 壳 - 历史 Tab
- [x] 新建 `ShellHistoryView`
  - 文件：`iOS/AngelLive/AngelLive/Views/Shell/ShellHistoryView.swift`
  - 复用现有 `HistoryModel`
  - 显示带封面缩略图的历史列表
  - 支持清空和单条删除

#### 2.5 壳 - 设置 Tab
- [x] 新建 `ShellSettingView`
  - 文件：`iOS/AngelLive/AngelLive/Views/Shell/ShellSettingView.swift`
  - 三个选项：通用设置、开源许可、关于
  - 复用现有 `GeneralSettingView`、`OpenSourceListView`、`AboutUSView`

### Phase 3：播放能力

#### 3.1 直接播放网络链接
- [ ] 确认现有播放器是否支持直接传入 URL 播放（不经过 LiveParse）
- [ ] 如需适配，在 `DetailPlayerView` / `RoomInfoViewModel` 中添加 URL 直接播放模式

---

## 文件清单

| 类型 | 文件 | 说明 |
|------|------|------|
| 新增 | `AngelLiveCore/Services/PluginAvailabilityService.swift` | 插件检测服务 |
| 新增 | `AngelLiveCore/Models/StreamBookmark.swift` | 网络链接收藏模型 |
| 新增 | `AngelLiveCore/Services/StreamBookmarkService.swift` | CloudKit 同步服务 |
| 新增 | `AngelLiveCore/Services/PluginSourceManager.swift` | 插件源管理 |
| 新增 | `iOS/Views/Shell/ShellFavoriteView.swift` | 壳收藏页 |
| 新增 | `iOS/Views/Shell/ShellConfigView.swift` | 壳配置页 |
| 新增 | `iOS/Views/Shell/ShellHistoryView.swift` | 壳历史页 |
| 新增 | `iOS/Views/Shell/ShellSettingView.swift` | 壳设置页 |
| 修改 | `iOS/ContentView.swift` | 路由逻辑：插件检测 → UI 切换 |

## 状态说明

| 状态 | 含义 |
|------|------|
| [ ] | 未开始 |
| [~] | 进行中 |
| [x] | 已完成 |
| [!] | 有问题/阻塞 |

## 变更日志

| 日期 | 变更内容 |
|------|---------|
| 2026-03-02 | 创建文档，完成方案设计 |
| 2026-03-02 | 完成 Phase 1 + Phase 2 iOS 实现，构建通过 |
