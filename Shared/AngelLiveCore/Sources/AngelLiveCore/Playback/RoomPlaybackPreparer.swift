import Foundation

public protocol LivePluginPlaybackRefreshing: Sendable {
    func refreshPlayback(
        roomId: String,
        cdn: LiveQualityModel,
        quality: LiveQualityDetail
    ) async throws -> LiveQualityDetail
}

extension LiveParseJSPlatform: LivePluginPlaybackRefreshing {
    public func refreshPlayback(
        roomId: String,
        cdn: LiveQualityModel,
        quality: LiveQualityDetail
    ) async throws -> LiveQualityDetail {
        try await LiveParseJSPlatformManager.refreshPlayback(
            platform: self,
            roomId: roomId,
            cdn: cdn,
            quality: quality
        )
    }
}

public enum RoomPlaybackPreparer {
    public static func prepare(
        roomId: String,
        cdn: LiveQualityModel,
        quality: LiveQualityDetail,
        plugin: LivePluginPlaybackRefreshing
    ) async throws -> LiveQualityDetail {
        guard RoomPlaybackResolver.requiresRefreshOnSelect(quality) else {
            return quality
        }
        return try await plugin.refreshPlayback(roomId: roomId, cdn: cdn, quality: quality)
    }
}
