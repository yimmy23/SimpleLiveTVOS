//
//  StreamBookmark.swift
//  AngelLiveCore
//
//  网络视频链接收藏模型，用于壳 UI 的收藏管理。
//  独立于现有直播间收藏（FavoriteService），使用单独的 CloudKit 表。
//

import Foundation

public struct StreamBookmark: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public var title: String
    public var url: String
    public var addedAt: Date
    public var lastPlayedAt: Date?

    public init(id: String = UUID().uuidString, title: String, url: String, addedAt: Date = Date(), lastPlayedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.addedAt = addedAt
        self.lastPlayedAt = lastPlayedAt
    }
}
