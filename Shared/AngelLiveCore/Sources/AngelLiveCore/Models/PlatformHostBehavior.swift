import Foundation

public enum FavoriteIdentityKey: String, Sendable {
    case roomId
    case userId
}

public enum PlatformHostBehavior {
    public static func favoriteIdentityKey(for liveType: LiveType) -> FavoriteIdentityKey {
        guard let rawValue = behavior(for: liveType)?.favoriteIdentityKey?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawValue.isEmpty else {
            return .roomId
        }
        switch rawValue {
        case "userid", "user_id":
            return .userId
        case "roomid", "room_id":
            return .roomId
        default:
            return .roomId
        }
    }

    public static func shouldPreserveFavoriteRoomInfoOnRefresh(for liveType: LiveType) -> Bool {
        behavior(for: liveType)?.preserveFavoriteRoomInfoOnRefresh == true
    }

    public static func liveStateOnFavoriteRefreshFailure(for liveType: LiveType) -> LiveState {
        guard let rawValue = behavior(for: liveType)?.liveStateFailureFallback,
              let liveState = LiveState(rawValue: rawValue) else {
            return .unknow
        }
        return liveState
    }

    public static func supportsLiveEndPolling(for liveType: LiveType) -> Bool {
        if let declared = behavior(for: liveType)?.supportsLiveEndPolling {
            return declared
        }
        return PlatformCapability.supports(.liveState, for: liveType)
    }

    public static func isPlayableRoom(_ room: LiveModel) -> Bool {
        let state = room.liveState ?? LiveState.unknow.rawValue
        return playableLiveStates(for: room.liveType).contains(state)
    }

    public static func externalRoomURL(for liveType: LiveType, roomId: String, userId: String) -> URL? {
        guard var template = behavior(for: liveType)?.externalRoomURLTemplate?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !template.isEmpty else {
            return nil
        }

        template = template
            .replacingOccurrences(of: "{roomId}", with: roomId)
            .replacingOccurrences(of: "{userId}", with: userId)
        return URL(string: template)
    }

    public static func themeColorHex(for liveType: LiveType) -> String? {
        let normalized = behavior(for: liveType)?.themeColor?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }

    private static func playableLiveStates(for liveType: LiveType) -> Set<String> {
        guard let rawStates = behavior(for: liveType)?.playableLiveStates, !rawStates.isEmpty else {
            return [LiveState.live.rawValue]
        }
        return Set(rawStates.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private static func behavior(for liveType: LiveType) -> ManifestHostBehavior? {
        SandboxPluginCatalog.platform(for: liveType)?.hostBehavior
    }
}
