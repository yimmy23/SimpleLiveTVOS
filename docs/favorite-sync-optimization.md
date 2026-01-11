# 收藏同步优化方向（抖音 / 虎牙）

本说明用于指导 LiveParse 的优化改动，重点缩短收藏同步耗时。

## 背景
- 收藏同步会逐个刷新房间状态。
- 当前抖音最慢，虎牙次慢。
- 目标是减少状态同步对 UI 展示的阻塞。

## 抖音（Sources/LiveParse/Douyin.swift）

### 1) 避免重复请求（高优先级）
- 现状：`getLiveLastestInfo` 里先 `getDouyinRoomDetail`，如果直播再调用 `getPlayArgs`。
- 问题：`getPlayArgs` 内部又会 `getDouyinRoomDetail`，导致同一房间两次请求。
- 方向：
  - 让 `getPlayArgs` 复用已获取的 `DouyinRoomPlayInfoMainData`；
  - 或为收藏同步增加轻量路径，跳过 `getPlayArgs`。

### 2) Cookie / ttwid 获取成本高（高优先级）
- 现状：`_getRoomDataByApi` 每次都调用 `Douyin.getCookie(roomId:)`。
- `getCookie` 本身可能请求 `live.douyin.com/<room>`，失败还会请求 `ttwid.bytedance.com`。
- 方向：
  - 使用 `ensureCookie` 并增加 TTL 缓存（10–30 分钟）；
  - 对 `ttwid` 做会话级缓存，减少重复网络请求。

### 3) 重试 + HTML 回退太重（中优先级）
- 现状：`getDouyinRoomDetail` 失败重试 3 次 + sleep，最后再走 HTML 解析。
- 方向：
  - 收藏同步场景降低重试次数或跳过 HTML 回退；
  - 播放页保留完整逻辑。

### 4) 增加状态轻量接口（中优先级）
- 方向：新增 `getLiveStateFast`，只返回 `LiveState`，避免拉取流地址。

## 虎牙（Sources/LiveParse/Huya.swift）

### 1) 全量 HTML 解析成本高（高优先级）
- 现状：`getLiveLastestInfo` 拉 `https://m.huya.com/<room>`，解析 `window.HNF_GLOBAL_INIT`。
- 方向：
  - 优先寻找返回状态的轻量 JSON 接口；
  - 如果没有，尽量只解析 `eLiveStatus` 等少量字段。

### 2) 缺少轻量 `getLiveState`（中优先级）
- 现状：`getLiveState` 直接调用 `getLiveLastestInfo`。
- 方向：新增 `getLiveStateFast`，避免构建完整 `LiveModel`。

## 通用优化建议
- 给收藏同步加入单请求超时（如 1.0–1.5s）；
- 本地缓存上次 `liveState`，先展示旧状态，再后台更新。

