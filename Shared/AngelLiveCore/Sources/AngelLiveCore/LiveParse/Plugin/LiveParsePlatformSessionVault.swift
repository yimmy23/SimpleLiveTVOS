import Foundation

struct LiveParsePlatformSession: Sendable {
    let cookie: String
    let uid: String?
    let updatedAt: Date
}

enum LiveParsePlatformSessionVault {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var sessions: [String: LiveParsePlatformSession] = [:]

    static func update(platformId: String, cookie: String, uid: String?) {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return }

        let normalizedCookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        if normalizedCookie.isEmpty {
            sessions.removeValue(forKey: normalizedId)
        } else {
            sessions[normalizedId] = LiveParsePlatformSession(
                cookie: normalizedCookie,
                uid: uid?.trimmingCharacters(in: .whitespacesAndNewlines),
                updatedAt: Date()
            )
        }
        lock.unlock()
    }

    static func clear(platformId: String) {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return }
        lock.lock()
        sessions.removeValue(forKey: normalizedId)
        lock.unlock()
    }

    static func mergedCookieHeader(for platformId: String) -> String? {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return nil }

        var cookieMap: [(String, String)] = []

        // 先解析 defaultCookie（低优先级）
        if let defaultCookie = defaultCookie(for: normalizedId) {
            cookieMap.append(contentsOf: parseCookiePairs(defaultCookie))
        }

        lock.lock()
        let sessionCookie = sessions[normalizedId]?.cookie
        lock.unlock()

        // 再解析 sessionCookie（高优先级，同 key 覆盖）
        if let sessionCookie, !sessionCookie.isEmpty {
            cookieMap.append(contentsOf: parseCookiePairs(sessionCookie))
        }

        // 去重：同 key 保留最后一个（session 优先于 default）
        var seen: [String: Int] = [:]
        var deduped: [(String, String)] = []
        for (key, value) in cookieMap {
            if let idx = seen[key] {
                deduped[idx] = (key, value)
            } else {
                seen[key] = deduped.count
                deduped.append((key, value))
            }
        }

        let merged = deduped.map { "\($0.0)=\($0.1)" }.joined(separator: "; ")
        return merged.isEmpty ? nil : merged
    }

    private static func parseCookiePairs(_ cookie: String) -> [(String, String)] {
        cookie.split(separator: ";").compactMap { pair in
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let eqIdx = trimmed.firstIndex(of: "=") else { return nil }
            let key = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            return key.isEmpty ? nil : (key, value)
        }
    }

    static func canonicalPlatformId(_ platformId: String) -> String {
        let raw = platformId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "kuaishou":
            return "ks"
        default:
            return raw
        }
    }

    private static func defaultCookie(for platformId: String) -> String? {
        switch platformId {
        case "soop":
            return "AbroadChk=OK"
        default:
            return nil
        }
    }
}
