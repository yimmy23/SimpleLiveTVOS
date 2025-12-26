# iOS UIKit + SwiftUI 安全区域与导航栏大标题联动

## 问题描述

当使用 `UIViewControllerRepresentable` 将 UIKit 的 `UICollectionView` 嵌入 SwiftUI 的 `NavigationStack` 时，遇到以下问题：

1. **TabBar 没有透视效果** - UICollectionView 的内容区域避开了安全区域，导致滚动时内容不会延伸到 TabBar 下方
2. **使用 `.ignoresSafeArea(edges: .bottom)` 后** - TabBar 透视效果生效，但导航栏大标题向上滚动时不会变成小标题的动画失效

## 解决方案

同时使用 `safeAreaInset` 和 `ignoresSafeArea(.container, edges:)` 来处理顶部和底部的安全区域：

```swift
FavoriteListViewControllerWrapper(
    searchText: searchText,
    navigationState: navigationState,
    namespace: roomTransitionNamespace
)
.safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
.safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 0) }
.ignoresSafeArea(.container, edges: [.top, .bottom])
.navigationTitle("收藏")
.navigationBarTitleDisplayMode(.large)
```

## 关键点

1. **`safeAreaInset(edge:spacing:)`** - 添加一个空的安全区域插入视图，确保 SwiftUI 正确计算安全区域
2. **`.ignoresSafeArea(.container, edges: [.top, .bottom])`** - 只忽略容器的安全区域，不影响滚动视图的内容调整
3. **同时处理顶部和底部** - 只处理底部会导致导航栏大标题动画失效

## 效果

- ✅ TabBar 透视效果正常
- ✅ 导航栏大标题 ↔ 小标题动画正常
- ✅ 下拉刷新正常工作
- ✅ 滚动行为正常

## 不起作用的方案

| 方案 | 结果 |
|------|------|
| `contentInsetAdjustmentBehavior = .automatic` | 破坏下拉刷新，布局异常 |
| 只用 `.ignoresSafeArea(edges: .bottom)` | TabBar 透视生效，但大标题动画失效 |
| 只用 `.ignoresSafeArea(.container, edges: .bottom)` | TabBar 透视生效，但大标题动画失效 |
| UIKit 层面设置 `contentInset.bottom` | TabBar 透视失效 |

## 适用场景

当你需要将 UIKit 的 `UIScrollView`/`UICollectionView`/`UITableView` 嵌入 SwiftUI 的 `NavigationStack`，并且需要同时满足：
- 内容延伸到安全区域下方（透视效果）
- 导航栏大标题折叠动画正常工作
