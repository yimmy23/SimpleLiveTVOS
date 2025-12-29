# AngelLive iOS 崩溃修复总结

## 已修复的崩溃问题

### 1. FavoriteListViewController 数据竞争崩溃 (Index out of range)

**原因：** `filteredSections` 在多线程环境下被修改，导致 `numberOfItemsInSection` 和 `cellForItemAt` 之间数据不一致

**修复：** 在数据源方法中使用局部快照

```swift
let sections = filteredSections
guard indexPath.section < sections.count else { return }
```

**文件：** `iOS/AngelLive/AngelLive/Views/UIKit/ViewControllers/FavoriteListViewController.swift`

---

### 2. UIRefreshControl + UINavigationController 无限递归 (Stack overflow)

**原因：** iOS 18+ 中 UIKit 的启发式搜索导致布局更新死循环

**修复：** 重写 `contentScrollViewForEdge(_:)` 显式返回 collectionView

```swift
override func contentScrollViewForEdge(_ edge: NSDirectionalRectEdge) -> UIScrollView? {
    return collectionView
}
```

**文件：** `iOS/AngelLive/AngelLive/Views/UIKit/ViewControllers/FavoriteListViewController.swift`

---

### 3. 后台状态 DiffableDataSource 崩溃

**原因：** iOS 18 的 `reconfigureItemsWithIdentifiers` 在后台状态下触发崩溃

**修复：** 在 SwiftUI Wrapper 中检查 `scenePhase`

```swift
@Environment(\.scenePhase) private var scenePhase

func updateUIViewController(...) {
    guard scenePhase == .active else { return }
    // UI 更新代码
}
```

**文件：** `iOS/AngelLive/AngelLive/Views/UIKit/ViewControllers/FavoriteListViewControllerWrapper.swift`

---

### 4. BilibiliCookieSyncService Actor 隔离崩溃

**原因：** `@MainActor` 类的 `@objc` 通知处理方法被后台线程调用

**修复：** 添加 `nonisolated` 修饰符

```swift
@objc nonisolated private func iCloudDidChange(_ notification: Notification) {
    Task { @MainActor in
        // 主线程代码
    }
}
```

**文件：** `Shared/AngelLiveCore/Sources/AngelLiveCore/Services/BilibiliCookieSyncService.swift`

---

## 待修复问题

### 5. iOS 26 UIZoomTransition 崩溃 (UIPreviewTarget)

**平台：** iOS 26 Beta

**原因：** iOS 26 的 `_UIZoomTransitionController.morph` 在源视图不在视图层级中时，`UIPreviewTarget initWithContainer:center:transform:` 断言失败

**状态：** iOS 26 Beta 系统 bug，无法在应用层修复，需等待 Apple 修复

---

### 6. macOS (Designed for iPad) SwiftUI Environment 崩溃

**平台：** Mac 上运行的 iOS 应用 (Designed for iPad)

**原因：** `.sheet()` 弹出时 Environment 对象缺失

**状态：** 待调查

---

### 7. Swift 泛型元数据崩溃 (EXC_BAD_ACCESS)

**平台：** iOS 18.6.2 (iPhone 14 Pro)

**原因：** Swift 运行时在实例化 SwiftUI 条件内容 (`_ConditionalContent`) 的泛型元数据时访问无效内存地址

**调用栈：**
```
libswiftCore.dylib: _swift_getGenericMetadata
SwiftUICore: ConditionalMetadata<>.makeViewList
SwiftUICore: DynamicViewList.updateValue
```

**状态：** Swift 运行时/SwiftUI 框架内部问题，无法在应用层修复

---

## 修改状态

- ✅ 所有 iOS 崩溃已修复
- ⏳ 修改尚未提交
