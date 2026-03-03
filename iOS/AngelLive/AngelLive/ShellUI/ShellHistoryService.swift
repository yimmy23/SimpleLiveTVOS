//
//  ShellHistoryService.swift
//  AngelLive
//
//  壳 UI 独立的播放历史服务，基于 UserDefaults 持久化。
//  不依赖 LiveModel / HistoryModel，仅记录 URL + 标题 + 播放时间。
//

import Foundation
import Observation

/// 壳 UI 播放历史条目
struct ShellHistoryItem: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var title: String
    var url: String
    var playedAt: Date

    init(id: String = UUID().uuidString, title: String, url: String, playedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.playedAt = playedAt
    }
}

@Observable
final class ShellHistoryService {

    private(set) var items: [ShellHistoryItem] = []

    @ObservationIgnored
    private let cacheKey = "AngelLive.ShellHistory.Cache"

    @ObservationIgnored
    private let maxItems = 100

    init() {
        loadFromCache()
    }

    // MARK: - 添加历史

    /// 添加或更新一条播放记录（相同 URL 去重，移到最前）
    @MainActor
    func addHistory(title: String, url: String) {
        // 移除已有的同 URL 记录
        items.removeAll { $0.url == url }

        // 插入到最前
        let item = ShellHistoryItem(title: title, url: url, playedAt: Date())
        items.insert(item, at: 0)

        // 限制数量
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        saveToCache()
    }

    // MARK: - 删除

    @MainActor
    func removeHistory(_ item: ShellHistoryItem) {
        items.removeAll { $0.id == item.id }
        saveToCache()
    }

    @MainActor
    func clearAll() {
        items.removeAll()
        saveToCache()
    }

    // MARK: - 持久化

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([ShellHistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func saveToCache() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }
}
