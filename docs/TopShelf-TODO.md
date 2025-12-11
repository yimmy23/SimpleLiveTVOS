# tvOS Top Shelf 功能实现待办清单

## 功能目标
在 Apple TV 主屏幕顶部展示「正在直播的收藏主播」，用户点击可直接跳转到对应直播间。

---

## 技术方案

### 数据流程
```
Extension loadTopShelfContent() 被调用
        ↓
从 CloudKit 读取用户收藏列表
        ↓
并行调用各平台 API 获取实时直播状态
        ↓
过滤出「正在直播」的主播
        ↓
生成 TVTopShelfSectionedContent 返回
        ↓
用户点击 → Deep Link → 打开主 App 对应直播间
```

### 关键技术点
- Extension 可以异步执行网络请求
- CloudKit 容器：`iCloud.icloud.dev.igod.simplelive`
- 需要设置合理的超时时间（建议 15-20 秒）
- YouTube 等特殊平台需要特殊处理（网络环境检测）

---

## 待办清单

### 1. Xcode 项目配置
- [ ] 创建 TV Top Shelf Extension target (File → New → Target → TV Top Shelf Extension)
- [ ] 配置 Extension 的 Bundle Identifier（建议：`dev.igod.simplelive.topshelf`）
- [ ] 配置 Extension 的 iCloud 权限（使用同一个 CloudKit 容器）
- [ ] 确认 Extension Info.plist 配置正确
  - `NSExtensionPointIdentifier`: `com.apple.tv-top-shelf`
  - `NSExtensionPrincipalClass`: `$(PRODUCT_MODULE_NAME).ContentProvider`

### 2. 共享代码处理
- [ ] 将 `FavoriteService.swift` 移至 Shared 模块或复制到 Extension target
- [ ] 将 `ApiManager.fetchLastestLiveInfo` 相关代码共享给 Extension
- [ ] 将 `LiveModel`、`LiveType` 等模型共享给 Extension
- [ ] 处理 Extension 中 LiveParse 依赖问题

### 3. ContentProvider 实现
- [ ] 创建 `ContentProvider.swift`
- [ ] 实现 `loadTopShelfContent()` 方法
  - [ ] 从 CloudKit 读取收藏列表
  - [ ] 并行调用各平台 API 获取直播状态
  - [ ] 添加超时保护（单个请求 + 整体超时）
  - [ ] 过滤正在直播的主播
  - [ ] 生成 `TVTopShelfSectionedContent`
- [ ] 处理 YouTube 等特殊平台（网络环境检测）
- [ ] 处理无收藏或无人直播的情况

### 4. Top Shelf Item 配置
- [ ] 设置主播头像/封面图片 URL
- [ ] 设置主播名称、直播间标题
- [ ] 配置 Deep Link URL（如：`simplelive://room/{platform}/{roomId}`）

### 5. 主 App Deep Link 处理
- [ ] 在 Info.plist 注册 URL Scheme：`simplelive`
- [ ] 在 `SimpleLiveTVOSApp.swift` 或 `AppDelegate` 中处理 `onOpenURL`
- [ ] 解析 URL 参数，跳转到对应直播间
- [ ] 处理直播间不存在或已下播的情况

### 6. 主 App 通知刷新
- [ ] 在收藏同步完成后调用 `TVTopShelfContentProvider.topShelfContentDidChange()`
- [ ] 在添加/删除收藏后通知刷新

### 7. 测试与优化
- [ ] 测试 Extension 执行时间是否足够
- [ ] 测试不同网络环境下的表现
- [ ] 测试收藏数量较多时的性能
- [ ] 测试 Deep Link 跳转是否正常
- [ ] 测试 iCloud 未登录时的处理

---

## 注意事项

### Extension 限制
- 执行时间有限（需要实测，估计 15-30 秒）
- 无法使用 App Groups 共享数据（tvOS 限制）
- 独立进程，不依赖主 App 运行

### 隐私与安全
- 用户数据不出 App，只在 CloudKit 和各平台 API 之间流转
- Extension 直接访问用户的 iCloud 私有数据库

### 用户体验
- 只显示正在直播的主播，不显示已下播的
- 无人直播时不显示内容（返回 nil）
- 点击后直接进入直播间播放

---

## Deep Link URL 设计

```
simplelive://room/{platform}/{roomId}

示例：
simplelive://room/bilibili/12345
simplelive://room/douyu/67890
simplelive://room/huya/abc123
```

---

## 参考资源

- Apple 官方 Demo: `BuildingAFullScreenTopShelfExtension`
- WWDC 2019 Session 211: Mastering the Living Room With tvOS
- Apple 文档: [TVTopShelfContentProvider](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)
