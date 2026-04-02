//
//  PluginConsoleService.swift
//  AngelLiveCore
//
//  Created by pangchong on 2026/4/2.
//

import Foundation
import Observation

// MARK: - HTTP 子请求记录

public struct PluginConsoleHTTPRecord: Identifiable, Sendable {
    public let id: UUID
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let statusCode: Int?
    public let responseHeaders: [String: String]?
    public let responseBody: String?
    public let error: String?
    public let duration: TimeInterval?

    public init(
        url: String,
        method: String,
        headers: [String: String],
        body: String? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        error: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.error = error
        self.duration = duration
    }
}

// MARK: - 日志条目

public enum PluginConsoleEntryStatus: Sendable {
    case loading
    case success
    case error
}

public struct PluginConsoleEntry: Identifiable, Sendable {
    public let id: UUID
    public let tag: String       // 插件 ID（如 bilibili）
    public let method: String    // 调用方法名（如 getCategories）
    public let timestamp: Date
    public var status: PluginConsoleEntryStatus
    public var duration: TimeInterval?
    public var requestBody: String?
    public var responseBody: String?
    public var errorMessage: String?
    public var httpRecords: [PluginConsoleHTTPRecord] = []

    public init(
        tag: String,
        method: String,
        status: PluginConsoleEntryStatus = .loading
    ) {
        self.id = UUID()
        self.tag = tag
        self.method = method
        self.timestamp = Date()
        self.status = status
    }
}

// MARK: - 控制台服务

@Observable
public final class PluginConsoleService: @unchecked Sendable {

    public static let shared = PluginConsoleService()

    private static let maxEntries = 500

    public private(set) var entries: [PluginConsoleEntry] = []

    /// 当前活跃的插件调用 ID（pluginId → entryId），供 Host.http 关联子请求
    private let activeLock = NSLock()
    private var activeCallIds: [String: UUID] = [:]

    private init() {}

    @MainActor
    public func log(tag: String, method: String, status: PluginConsoleEntryStatus = .loading) -> UUID {
        let entry = PluginConsoleEntry(tag: tag, method: method, status: status)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        return entry.id
    }

    @MainActor
    public func updateStatus(
        id: UUID,
        status: PluginConsoleEntryStatus,
        duration: TimeInterval? = nil,
        responseBody: String? = nil,
        errorMessage: String? = nil
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = status
        entries[index].duration = duration
        entries[index].responseBody = responseBody
        entries[index].errorMessage = errorMessage
    }

    @MainActor
    public func updateRequest(id: UUID, body: String?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].requestBody = body
    }

    // MARK: - 活跃调用跟踪（线程安全，供 JSRuntime 的 Host.http 使用）

    public func setActiveCall(pluginId: String, entryId: UUID) {
        activeLock.lock()
        activeCallIds[pluginId] = entryId
        activeLock.unlock()
    }

    public func clearActiveCall(pluginId: String) {
        activeLock.lock()
        activeCallIds.removeValue(forKey: pluginId)
        activeLock.unlock()
    }

    public func activeEntryId(for pluginId: String) -> UUID? {
        activeLock.lock()
        defer { activeLock.unlock() }
        return activeCallIds[pluginId]
    }

    /// 从任意线程追加 HTTP 子请求记录
    @MainActor
    public func appendHTTPRecord(entryId: UUID, record: PluginConsoleHTTPRecord) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].httpRecords.append(record)
    }

    /// 开发者模式是否启用
    public var isEnabled: Bool {
        UserDefaults.shared.bool(forKey: GeneralSettingModel.globalDeveloperMode)
    }

    @MainActor
    public func clear() {
        entries.removeAll()
    }
}
