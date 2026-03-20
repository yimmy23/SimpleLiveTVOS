import Foundation

public enum RoomPlaybackPlayerKind: Sendable {
    case avPlayer
    case mePlayer
}

public struct RoomPlaybackSelection: Sendable {
    public let cdnIndex: Int
    public let qualityIndex: Int
    public let quality: LiveQualityDetail

    public init(cdnIndex: Int, qualityIndex: Int, quality: LiveQualityDetail) {
        self.cdnIndex = cdnIndex
        self.qualityIndex = qualityIndex
        self.quality = quality
    }
}

public struct RoomPlaybackPlan: Sendable {
    public let playerKinds: [RoomPlaybackPlayerKind]
    public let isHLS: Bool
    public let overrideURL: URL?
    public let overrideTitle: String?
    public let resolvedSelection: RoomPlaybackSelection?

    public init(
        playerKinds: [RoomPlaybackPlayerKind],
        isHLS: Bool,
        overrideURL: URL? = nil,
        overrideTitle: String? = nil,
        resolvedSelection: RoomPlaybackSelection? = nil
    ) {
        self.playerKinds = playerKinds
        self.isHLS = isHLS
        self.overrideURL = overrideURL
        self.overrideTitle = overrideTitle
        self.resolvedSelection = resolvedSelection
    }
}

public struct RoomPlaybackRequestOptions: Sendable {
    public let userAgent: String
    public let headers: [String: String]

    public init(userAgent: String, headers: [String: String]) {
        self.userAgent = userAgent
        self.headers = headers
    }
}

public struct RoomPlaybackDebugContext: Sendable {
    public let tappedSelection: RoomPlaybackSelection?
    public let effectiveSelection: RoomPlaybackSelection?

    public init(
        tappedSelection: RoomPlaybackSelection?,
        effectiveSelection: RoomPlaybackSelection?
    ) {
        self.tappedSelection = tappedSelection
        self.effectiveSelection = effectiveSelection
    }
}

public enum RoomPlaybackResolver {
    public static func isHLSQuality(_ quality: LiveQualityDetail) -> Bool {
        quality.liveCodeType == .hls || quality.url.lowercased().contains(".m3u8")
    }

    public static func streamTypeIdentifier(for quality: LiveQualityDetail) -> String {
        isHLSQuality(quality) ? "hls" : "flv"
    }

    public static func streamTypeDisplayName(for quality: LiveQualityDetail) -> String {
        isHLSQuality(quality) ? "HLS" : "FLV"
    }

    public static func selection(
        in playArgs: [LiveQualityModel]?,
        cdnIndex: Int,
        qualityIndex: Int
    ) -> RoomPlaybackSelection? {
        guard let playArgs,
              playArgs.indices.contains(cdnIndex),
              playArgs[cdnIndex].qualitys.indices.contains(qualityIndex) else {
            return nil
        }

        return RoomPlaybackSelection(
            cdnIndex: cdnIndex,
            qualityIndex: qualityIndex,
            quality: playArgs[cdnIndex].qualitys[qualityIndex]
        )
    }

    public static func firstSelection(in playArgs: [LiveQualityModel]?) -> RoomPlaybackSelection? {
        guard let playArgs else { return nil }
        for (cdnIndex, cdn) in playArgs.enumerated() {
            if let quality = cdn.qualitys.first {
                return RoomPlaybackSelection(cdnIndex: cdnIndex, qualityIndex: 0, quality: quality)
            }
        }
        return nil
    }

    public static func firstSelection(
        in playArgs: [LiveQualityModel]?,
        where predicate: (LiveQualityDetail) -> Bool
    ) -> RoomPlaybackSelection? {
        guard let playArgs else { return nil }
        for (cdnIndex, cdn) in playArgs.enumerated() {
            for (qualityIndex, quality) in cdn.qualitys.enumerated() where predicate(quality) {
                return RoomPlaybackSelection(cdnIndex: cdnIndex, qualityIndex: qualityIndex, quality: quality)
            }
        }
        return nil
    }

    public static func findHLSQuality(in playArgs: [LiveQualityModel]?) -> LiveQualityDetail? {
        firstSelection(in: playArgs, where: isHLSQuality)?.quality
    }

    public static func findFirstQuality(in playArgs: [LiveQualityModel]?) -> LiveQualityDetail? {
        firstSelection(in: playArgs)?.quality
    }

    public static func firstPlayableURL(from playArgs: [LiveQualityModel]) -> URL? {
        for cdn in playArgs {
            for quality in cdn.qualitys {
                if let url = URL(string: quality.url) {
                    return url
                }
            }
        }
        return nil
    }

    public static func yyPlaybackContext(cdn: LiveQualityModel, quality: LiveQualityDetail) -> [String: Any] {
        let rawLineSeq = (cdn.yyLineSeq ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lineSeq: Any = Int(rawLineSeq) ?? (rawLineSeq.isEmpty ? -1 : rawLineSeq)

        return [
            "lineSeq": lineSeq,
            "gear": quality.qn,
            "qn": quality.qn
        ]
    }

    public static func requestOptions(
        for quality: LiveQualityDetail,
        fallbackUserAgent: String
    ) -> RoomPlaybackRequestOptions {
        let customUA = quality.userAgent?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgent = (customUA?.isEmpty == false) ? customUA! : fallbackUserAgent

        var headers = quality.headers ?? [:]
        if headers["User-Agent"] == nil && headers["user-agent"] == nil {
            headers["user-agent"] = userAgent
        }

        return RoomPlaybackRequestOptions(userAgent: userAgent, headers: headers)
    }

    public static func cdnDisplayName(for cdn: LiveQualityModel) -> String {
        let douyuName = cdn.douyuCdnName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !douyuName.isEmpty {
            return douyuName
        }

        let yyLineSeq = cdn.yyLineSeq?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !yyLineSeq.isEmpty {
            return yyLineSeq
        }

        let normalizedCDN = cdn.cdn.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedCDN.isEmpty ? "未设置" : normalizedCDN
    }

    public static func qualityDisplayTitle(
        _ quality: LiveQualityDetail,
        in playArgs: [LiveQualityModel]?
    ) -> String {
        let normalizedTitle = quality.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = normalizedTitle.isEmpty ? "未命名清晰度" : normalizedTitle
        guard hasDuplicateTitleWithDifferentStreamType(
            in: playArgs,
            title: normalizedTitle,
            targetStreamTypeIdentifier: streamTypeIdentifier(for: quality)
        ) else {
            return baseTitle
        }

        return "\(baseTitle) \(streamTypeDisplayName(for: quality))"
    }

    public static func qualityDisplayTitle(
        in playArgs: [LiveQualityModel]?,
        selection: RoomPlaybackSelection?
    ) -> String {
        guard let selection else { return "清晰度" }
        return qualityDisplayTitle(selection.quality, in: playArgs)
    }

    public static func qualityDisplayTitle(
        in playArgs: [LiveQualityModel]?,
        cdnIndex: Int,
        qualityIndex: Int
    ) -> String {
        qualityDisplayTitle(
            in: playArgs,
            selection: selection(in: playArgs, cdnIndex: cdnIndex, qualityIndex: qualityIndex)
        )
    }

    public static func debugSelectionSummary(
        in playArgs: [LiveQualityModel]?,
        selection: RoomPlaybackSelection?
    ) -> String {
        guard let selection else { return "未设置" }

        let cdnName: String
        if let playArgs, playArgs.indices.contains(selection.cdnIndex) {
            cdnName = cdnDisplayName(for: playArgs[selection.cdnIndex])
        } else {
            cdnName = "未知线路"
        }

        let displayTitle = qualityDisplayTitle(in: playArgs, selection: selection)
        let streamType = streamTypeIdentifier(for: selection.quality)

        return "cdn[\(selection.cdnIndex)]=\(cdnName), quality[\(selection.qualityIndex)]=\(displayTitle)(qn=\(selection.quality.qn), type=\(streamType))"
    }

    public static func douyinPlaybackContext(
        cdn: LiveQualityModel,
        quality: LiveQualityDetail
    ) -> [String: Any] {
        var context: [String: Any] = [
            "rate": quality.qn,
            "qn": quality.qn,
            "quality": quality.title,
            "title": quality.title
        ]

        let normalizedCDN = cdn.cdn.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedCDN.isEmpty {
            context["cdn"] = normalizedCDN
        }

        let streamType = streamTypeIdentifier(for: quality)
        context["liveCodeType"] = quality.liveCodeType.rawValue
        context["streamType"] = streamType
        context["format"] = streamType

        return context
    }

    public static func matchingSelection(
        in playArgs: [LiveQualityModel],
        preferredQuality: LiveQualityDetail,
        preferredCDN: LiveQualityModel? = nil
    ) -> RoomPlaybackSelection? {
        if let selection = firstSelection(in: playArgs, where: { $0.url == preferredQuality.url }) {
            return selection
        }

        let preferredTitle = preferredQuality.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredType = streamTypeIdentifier(for: preferredQuality)
        let preferredCDNName = preferredCDN.map(cdnDisplayName(for:))

        var bestSelection: RoomPlaybackSelection?
        var bestScore = Int.min

        for (cdnIndex, cdn) in playArgs.enumerated() {
            for (qualityIndex, quality) in cdn.qualitys.enumerated() {
                var score = 0

                if streamTypeIdentifier(for: quality) == preferredType {
                    score += 400
                }

                if preferredQuality.qn != 0, quality.qn == preferredQuality.qn {
                    score += 180
                }

                if !preferredTitle.isEmpty,
                   quality.title.trimmingCharacters(in: .whitespacesAndNewlines) == preferredTitle {
                    score += 120
                }

                if let preferredCDNName,
                   cdnDisplayName(for: cdn) == preferredCDNName {
                    score += 80
                }

                if score > bestScore {
                    bestScore = score
                    bestSelection = RoomPlaybackSelection(
                        cdnIndex: cdnIndex,
                        qualityIndex: qualityIndex,
                        quality: quality
                    )
                }
            }
        }

        if let selection = bestSelection, bestScore > 0 {
            return selection
        }

        if isHLSQuality(preferredQuality),
           let selection = firstSelection(in: playArgs, where: isHLSQuality) {
            return selection
        }

        if let selection = firstSelection(
            in: playArgs,
            where: { streamTypeIdentifier(for: $0) == preferredType }
        ) {
            return selection
        }

        return firstSelection(in: playArgs)
    }

    public static func resolvePlan(
        liveType: LiveType,
        liveState: String?,
        selectedQuality: LiveQualityDetail,
        playArgs: [LiveQualityModel]?,
        cdnIndex: Int,
        urlIndex: Int
    ) -> RoomPlaybackPlan {
        if liveType == .bilibili && cdnIndex == 0 && urlIndex == 0 {
            if let selection = firstSelection(in: playArgs, where: isHLSQuality),
               let url = URL(string: selection.quality.url) {
                return RoomPlaybackPlan(
                    playerKinds: [.mePlayer],
                    isHLS: true,
                    overrideURL: url,
                    overrideTitle: qualityDisplayTitle(in: playArgs, selection: selection),
                    resolvedSelection: selection
                )
            }
        }

        if liveType == .ks {
            return RoomPlaybackPlan(playerKinds: [.mePlayer], isHLS: false)
        }

        if isHLSQuality(selectedQuality), liveType == .bilibili {
            return RoomPlaybackPlan(playerKinds: [.mePlayer], isHLS: true)
        }

        if isHLSQuality(selectedQuality),
           liveType == .huya,
           LiveState(rawValue: liveState ?? "unknow") == .video {
            return RoomPlaybackPlan(playerKinds: [.mePlayer], isHLS: false)
        }

        if isHLSQuality(selectedQuality), liveType != .youtube {
            return RoomPlaybackPlan(playerKinds: [.avPlayer], isHLS: true)
        }

        return RoomPlaybackPlan(playerKinds: [.mePlayer], isHLS: false)
    }

    private static func hasDuplicateTitleWithDifferentStreamType(
        in playArgs: [LiveQualityModel]?,
        title: String,
        targetStreamTypeIdentifier: String
    ) -> Bool {
        guard let playArgs, !title.isEmpty else { return false }

        for cdn in playArgs {
            for quality in cdn.qualitys {
                let candidateTitle = quality.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard candidateTitle == title else { continue }
                if streamTypeIdentifier(for: quality) != targetStreamTypeIdentifier {
                    return true
                }
            }
        }

        return false
    }
}
