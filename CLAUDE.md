# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码仓库中工作时提供指导。

## 项目概述

AngelLive 是一个多平台直播聚合应用，支持 iOS、macOS 和 tvOS。通过 JS 插件系统聚合多个直播平台，功能包括播放、CloudKit 云同步收藏、弹幕显示等。支持通过远程插件源动态安装和更新平台插件。

## 构建命令

```bash
# 打开工作区（必须使用工作区，不要单独打开 .xcodeproj）
open AngelLive.xcworkspace

# 命令行构建
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLive -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLiveMacOS -destination 'platform=macOS' build
xcodebuild -workspace AngelLive.xcworkspace -scheme AngelLiveTVOS -destination 'platform=tvOS Simulator,name=Apple TV' build

# 运行测试（AngelLiveCore 包）
cd Shared/AngelLiveCore && swift test
```

## 架构

**MVVM + Service 层**，通过 Swift Package 共享代码：

```
View (SwiftUI) → ViewModel (@Observable) → Service → AppState
```

### 工作区结构

- `AngelLive.xcworkspace` - 主工作区（使用这个，不要单独打开项目）
- `iOS/AngelLive.xcodeproj` - iOS 平台
- `macOS/AngelLiveMacOS.xcodeproj` - macOS 平台
- `TV/AngelLiveTVOS.xcodeproj` - tvOS 平台

### 共享包（位于 `Shared/`）

- **AngelLiveCore** - 核心业务逻辑：ViewModels、Services、Models、DanmakuKit
- **AngelLiveDependencies** - 集中管理第三方依赖，按平台条件引入
- **SharedAssets** - 跨平台共享的颜色、图片、设计资源

### 关键文件

| 组件 | 位置 |
|------|------|
| 全局状态 | `*/AppState.swift`（各平台各有一份） |
| 直播 API 服务 | `Shared/AngelLiveCore/Sources/Services/LiveService.swift` |
| CloudKit 同步 | `Shared/AngelLiveCore/Sources/Services/FavoriteService.swift` |
| 收藏 ViewModel | `Shared/AngelLiveCore/Sources/Models/AppFavoriteModel.swift` |

## 平台要求

- **Swift 6.2**（swift-tools-version）
- iOS 17+、macOS 15+、tvOS 17+
- Xcode 15+

## 依赖说明

本项目默认使用 **KSPlayer** 播放器内核。可通过环境变量 `USE_VLC=1` 切换为 VLCKit 内核（两者互斥，不能同时引入，否则内嵌的 FFmpeg 符号会冲突）。

## 关键模式

### 状态管理
使用 `@Observable` 宏（iOS 17+），通过 Environment 注入。AppState 持有所有 ViewModel。

### 并行搜索
`LiveService.searchRooms()` 使用 TaskGroup 并发搜索多个平台。

### CloudKit 同步
`FavoriteService` 处理 iCloud 收藏同步，使用 Actor 保证线程安全（`FavoriteStateModel`）。

## JS 插件系统（LiveParse）

各直播平台的 API 解析通过 JavaScriptCore JS 插件实现，位于 `LiveParse/Sources/LiveParse/Resources/` 目录：

### 插件结构

每个插件包含：
- **manifest.json** — 声明 pluginId、version、apiVersion、entry 入口文件、可选 preloadScripts
- **index.js** — 入口脚本，导出 `globalThis.LiveParsePlugin` 对象

命名规范：`lp_plugin_{平台}_{版本}_{文件类型}.{ext}`

### 插件 API（v2 方法名）

| 方法 | 用途 |
|------|------|
| `getCategories` | 获取分类列表 |
| `getRooms` | 获取房间列表 |
| `getPlayback` | 获取播放地址 |
| `search` | 搜索房间 |
| `getRoomDetail` | 获取房间详情 |
| `getLiveState` | 获取直播状态 |
| `resolveShare` | 解析分享码 |
| `getDanmaku` | 获取弹幕参数 |

### 关键机制

- **preloadScripts**：manifest 中声明需要预加载的脚本
- **浏览器环境 shim**：JSRuntime 启动时注入 `window`/`document`/`navigator` 全局对象，供第三方脚本使用
- **Cookie 注入**：JS 插件通过 `payload.cookie` 获取 Cookie
- **v1→v2 兼容**：Swift 侧 `callWithFallback` 先尝试 v2 方法名，失败时回退 v1

### 测试

```bash
cd LiveParse && swift test
```

## 远程插件系统

LiveParse 内置了完整的远程插件管理基础设施，支持从远程源下载、安装、更新 JS 插件。

### 远程插件源

在线插件索引地址：`https://live-parse.vercel.app/Dist/PluginRelease/plugins.json`

索引 JSON 结构：
```json
{
  "apiVersion": 1,
  "generatedAt": "...",
  "plugins": [
    {
      "pluginId": "example",
      "version": "0.1.0",
      "platform": "example",
      "platformName": "示例平台",
      "zipURLs": ["https://mirror.example.com/...zip", "https://github.com/...zip"],
      "zipURL": "https://github.com/.../example_0.1.0.zip",
      "sha256": "abcdef...",
      "icon": "assets/live_card_example.png",
      "iosIcon": "assets/pad_live_card_example.png",
      "macosIcon": "assets/mini_live_card_example.png",
      "tvosIcon": "assets/live_card_example.png",
      "tvosBigIcon": "assets/tv_example_big.png",
      "tvosSmallIcon": "assets/tv_example_small.png",
      "tvosBigIconDark": "assets/tv_example_big_dark.png",
      "tvosSmallIconDark": "assets/tv_example_small_dark.png"
    }
  ]
}
```

### LiveParse 插件管理 API

| 类 | 职责 |
|---|------|
| `LiveParsePluginManager` | 核心管理器：resolve/load/call 插件，支持 builtIn 和 sandbox 两种来源 |
| `LiveParsePluginStorage` | 本地存储管理：插件文件存放在 `Application Support/LiveParse/plugins/` |
| `LiveParsePluginUpdater` | 远程更新：fetchIndex → downloadZip → SHA256 校验 → install |
| `LiveParsePluginInstaller` | ZIP 解压安装：解压到沙盒目录，包含 zip-slip 安全校验 |
| `LiveParseRemotePluginIndex` | 远程索引模型（apiVersion、plugins 数组） |
| `LiveParseRemotePluginItem` | 远程插件条目模型（pluginId、version、zipURL、sha256、platformName、图标等） |
| `LiveParsePluginManifest` | 插件清单：pluginId、version、apiVersion、liveTypes、entry、preloadScripts |
| `LiveParsePluginState` | 本地状态：各插件的 pinnedVersion、lastGoodVersion、enabled |
| `LiveParseLoadedPlugin` | 已加载插件实例（Actor）：持有 manifest、rootDirectory、JSRuntime |
| `LiveParsePlugins` | 全局共享 `LiveParsePluginManager` 单例（`LiveParsePlugins.shared`） |

### 插件加载优先级

`LiveParsePluginManager.resolve()` 按以下顺序选择插件：

1. **pinned version** → 精确匹配指定版本（sandbox 优先，fallback builtIn）
2. **sandbox 最新版** → 已安装的远程插件，取最高 semver
3. **lastGoodVersion** → 上次成功使用的 builtIn 版本
4. **builtIn 最新版** → 内置在 bundle 中的插件

### 远程插件安装流程

```
fetchIndex(url) → LiveParseRemotePluginIndex
    ↓
install(item: LiveParseRemotePluginItem)
    ↓
downloadVerifiedZip → 尝试 zipURLs 中的多个镜像源
    ↓
SHA256 校验（mismatch 则尝试下一个源）
    ↓
LiveParsePluginInstaller.install(zipData, storage)
    ↓
解压到 Application Support/LiveParse/plugins/{pluginId}/{version}/
    ↓
installAndActivate → 冒烟测试 → 记录 lastGoodVersion
    ↓
reload() → 下次 resolve() 自动使用新版本
```

### 注意事项

- `LiveParseRemotePluginItem` 包含 pluginId、version、zipURL、zipURLs、sha256、platformName、图标字段等
- `downloadVerifiedZip` 支持多镜像源 fallback（遍历 `downloadURLs`，逐个下载并校验 SHA256）
- `installAndActivate` 方法支持冒烟测试：安装后加载插件并调用指定函数验证可用性，失败则自动回滚
- 插件的 `call()` / `callDecodable()` 方法通过 `LiveParsePlugins.shared` 统一调用
- Cookie 注入通过 `PlatformSessionLiveParseBridge` 桥接

## 深度链接（tvOS）

格式：`simplelive://room/{platform}/{roomId}` - 供 Top Shelf 扩展使用。
