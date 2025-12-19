# tvOS 触控板方向异常排查记录

## 当前结论
- **静态房间列表**（不走网络、不更新数据）时触控板方向正常。
- **真实数据更新**（roomList 持续变化）时方向变为全是 `.down`。
- 高概率根因：**roomList 更新导致 focus 丢失/越界，系统把触控板输入归一为“向下滚动”**。

---

## 已改动点

### 1) 修复“首次进入显示 bilibili”
文件：`TV/AngelLiveTVOS/Source/Platform/PlatformView.swift`

- 给 `ListMainView` 加 `.id(liveType)`，避免 fullScreenCover 复用旧状态。
  - 作用：第一次进入非 bilibili 平台时不会先显示 bilibili。

---

## ListMainView 调试开关（核心）

文件：`TV/AngelLiveTVOS/Source/List/ListMainView.swift`

```swift
private let useStaticRooms = false
private let useStableRoomsSnapshot = true
private let deferRoomListUpdates = true
private let disableSceneRefresh = true
private let forceFocusOnRoomListChange = true
private let useSimpleListCells = true
```

### 说明
- `useStaticRooms`
  - true：使用固定静态房间列表（不走网络、不更新）。
- `useStableRoomsSnapshot`
  - true：只取第一次 roomList 做快照，后续更新不刷新 UI。
- `deferRoomListUpdates`
  - true：roomList 更新延迟 0.25s 应用。
- `disableSceneRefresh`
  - true：禁止 scenePhase 触发刷新。
- `forceFocusOnRoomListChange`
  - true：roomList 更新后强制将 focus 拉回有效 index。
- `useSimpleListCells`
  - true：用简化 cell 替代 `LiveCardView`（减少干扰）。

---

## 目前可用/不可用组合

### ✅ 正常
1) 静态数据（完全无更新）
```swift
useStaticRooms = true
useSimpleListCells = true
```

2) 真实数据 + 快照
```swift
useStaticRooms = false
useStableRoomsSnapshot = true
useSimpleListCells = true
```

### ❌ 不正常
- 只要 `useStableRoomsSnapshot = false`，roomList 持续更新，触控板方向变为 `.down`

---

## 下一步建议（下班后继续）

### Step 1：验证“focus 修正”是否能救回方向
```swift
useStaticRooms = false
useStableRoomsSnapshot = false
deferRoomListUpdates = false
forceFocusOnRoomListChange = true
useSimpleListCells = true
```

- 如果正常 → 根因确认是 **roomList 更新导致 focus 丢失**。
- 如果仍不正常 → 继续排查输入层（如 microGamepad）。

---

## 备注
- `forceFocusOnRoomListChange` 已实现：roomList 更新后若焦点无效/越界，会延迟 0.25s 拉回合法 index。
- 如果此策略有效，可考虑作为正式修复并逐步恢复 `LiveCardView`。

---
