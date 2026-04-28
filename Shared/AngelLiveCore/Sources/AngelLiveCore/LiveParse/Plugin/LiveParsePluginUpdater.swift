import CryptoKit
import Foundation

struct LiveParsePluginIndexResponseDiagnostics: Sendable {
    let url: URL
    let statusCode: Int?
    let contentType: String?
    let bodyPreview: String

    var logDescription: String {
        let statusText = statusCode.map(String.init) ?? "n/a"
        let contentTypeText = contentType ?? "unknown"
        return "URL=\(url.absoluteString), HTTP=\(statusText), Content-Type=\(contentTypeText), bodyPreview=\(bodyPreview)"
    }
}

enum LiveParsePluginIndexFetchError: Error, Sendable {
    case nonJSONResponse(LiveParsePluginIndexResponseDiagnostics)
    case decodingFailed(LiveParsePluginIndexResponseDiagnostics, DecodingError)
}

public struct LiveParsePluginUpdateInfo: Equatable, Sendable {
    public let pluginId: String
    public let currentVersion: String?
    public let latestVersion: String
    public let hasUpdate: Bool
    public let changelog: [String]

    public init(
        pluginId: String,
        currentVersion: String?,
        latestVersion: String,
        hasUpdate: Bool,
        changelog: [String]
    ) {
        self.pluginId = pluginId
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.hasUpdate = hasUpdate
        self.changelog = changelog
    }
}

public final class LiveParsePluginUpdater: @unchecked Sendable {
    public let storage: LiveParsePluginStorage
    public let session: URLSession

    public init(storage: LiveParsePluginStorage, session: URLSession = .shared) {
        self.storage = storage
        self.session = session
    }

    public func fetchIndex(url: URL) async throws -> LiveParseRemotePluginIndex {
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        if let httpResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"
            ])
        }

        let diagnostics = responseDiagnostics(url: url, response: response, data: data)
        guard Self.looksLikeJSONObject(data) else {
            Logger.error("Plugin index response is not JSON. \(diagnostics.logDescription)", category: .plugin)
            throw LiveParsePluginIndexFetchError.nonJSONResponse(diagnostics)
        }

        do {
            return try JSONDecoder().decode(LiveParseRemotePluginIndex.self, from: data)
        } catch let decodingError as DecodingError {
            let codingPath = Self.codingPathDescription(for: decodingError)
            let detail = Self.decodingDebugDescription(for: decodingError)
            let codingPathDescription = codingPath.isEmpty ? "<root>" : codingPath
            Logger.error(
                "Plugin index decode failed. \(diagnostics.logDescription), codingPath=\(codingPathDescription), detail=\(detail)",
                category: .plugin
            )
            throw LiveParsePluginIndexFetchError.decodingFailed(diagnostics, decodingError)
        }
    }

    public func downloadZip(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }

    /// Check whether the specified plugin has a newer version in remote index.
    /// - Returns: nil when plugin does not exist in the index.
    public func checkUpdate(
        pluginId: String,
        currentVersion: String?,
        index: LiveParseRemotePluginIndex
    ) -> LiveParsePluginUpdateInfo? {
        let candidates = index.plugins.filter { $0.pluginId == pluginId }
        guard let latest = candidates.max(by: { semverCompare($0.version, $1.version) < 0 }) else {
            return nil
        }

        let normalizedCurrent = currentVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUpdate: Bool
        if let current = normalizedCurrent, !current.isEmpty {
            hasUpdate = semverCompare(latest.version, current) > 0
        } else {
            hasUpdate = true
        }

        return LiveParsePluginUpdateInfo(
            pluginId: pluginId,
            currentVersion: normalizedCurrent,
            latestVersion: latest.version,
            hasUpdate: hasUpdate,
            changelog: latest.changelog ?? []
        )
    }

    public func install(item: LiveParseRemotePluginItem) async throws -> LiveParsePluginManifest {
        let zipData = try await downloadVerifiedZip(item: item)
        return try LiveParsePluginInstaller.install(zipData: zipData, storage: storage)
    }

    /// Install plugin from remote item, run smoke test, and persist `lastGoodVersion`.
    /// If smoke test fails, the newly installed version is removed.
    @discardableResult
    public func installAndActivate(
        item: LiveParseRemotePluginItem,
        smokeFunction: String = "",
        smokePayload: [String: Any] = [:],
        manager: LiveParsePluginManager? = nil
    ) async throws -> LiveParsePluginManifest {
        var installedManifest: LiveParsePluginManifest?
        do {
            let manifest = try await install(item: item)
            installedManifest = manifest

            try await smokeTestInstalledPlugin(
                manifest: manifest,
                function: smokeFunction,
                payload: smokePayload,
                session: manager?.session ?? session
            )

            if let manager {
                try manager.setLastGoodVersion(pluginId: manifest.pluginId, version: manifest.version)
                manager.evict(pluginId: manifest.pluginId)
            } else {
                try persistLastGoodVersion(pluginId: manifest.pluginId, version: manifest.version)
            }
            return manifest
        } catch {
            if let manifest = installedManifest {
                try? removeInstalledVersion(pluginId: manifest.pluginId, version: manifest.version)
            }
            manager?.evict(pluginId: item.pluginId)
            throw error
        }
    }

    func downloadVerifiedZip(item: LiveParseRemotePluginItem) async throws -> Data {
        let expected = item.sha256.lowercased()
        let candidates = item.downloadURLs
        guard !candidates.isEmpty else {
            throw LiveParsePluginError.installFailed("No zip download URL for \(item.pluginId)@\(item.version)")
        }

        var diagnostics: [String] = []

        for raw in candidates {
            guard let url = URL(string: raw) else {
                diagnostics.append("invalid-url(\(raw))")
                continue
            }

            do {
                let zipData = try await downloadZip(url: url)
                let actual = sha256Hex(zipData)
                guard actual == expected else {
                    diagnostics.append("checksum-mismatch(\(url.absoluteString))")
                    continue
                }
                return zipData
            } catch {
                diagnostics.append("download-failed(\(url.absoluteString)): \(error.localizedDescription)")
            }
        }

        throw LiveParsePluginError.installFailed(
            "All sources failed for \(item.pluginId)@\(item.version): \(diagnostics.joined(separator: "; "))"
        )
    }

    public func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func persistLastGoodVersion(pluginId: String, version: String) throws {
        var state = storage.loadState()
        var record = state.plugins[pluginId] ?? .init()
        record.lastGoodVersion = version
        state.plugins[pluginId] = record
        try storage.saveState(state)
    }

    func removeInstalledVersion(pluginId: String, version: String) throws {
        let target = storage.pluginVersionDirectory(pluginId: pluginId, version: version)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try FileManager.default.removeItem(at: target)
    }

    func smokeTestInstalledPlugin(
        manifest: LiveParsePluginManifest,
        function: String,
        payload: [String: Any] = [:],
        session: URLSession
    ) async throws {
        let smoke = function.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !smoke.isEmpty else { return }

        let plugin = LiveParseLoadedPlugin(
            manifest: manifest,
            rootDirectory: storage.pluginVersionDirectory(pluginId: manifest.pluginId, version: manifest.version),
            location: .sandbox,
            runtime: JSRuntime(pluginId: manifest.pluginId, session: session, nativeStream: manifest.nativeStream)
        )
        try await plugin.load()
        _ = try await plugin.runtime.callPluginFunction(name: smoke, payload: payload)
    }

    func semverCompare(_ lhs: String, _ rhs: String) -> Int {
        func parts(_ value: String) -> [Int] {
            value.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
        }

        let left = parts(lhs)
        let right = parts(rhs)
        for idx in 0..<3 {
            if left[idx] != right[idx] {
                return left[idx] < right[idx] ? -1 : 1
            }
        }
        return 0
    }

    private func responseDiagnostics(url: URL, response: URLResponse, data: Data) -> LiveParsePluginIndexResponseDiagnostics {
        let httpResponse = response as? HTTPURLResponse
        return LiveParsePluginIndexResponseDiagnostics(
            url: url,
            statusCode: httpResponse?.statusCode,
            contentType: httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? response.mimeType,
            bodyPreview: Self.bodyPreview(from: data)
        )
    }

    private static func looksLikeJSONObject(_ data: Data) -> Bool {
        firstMeaningfulByte(in: data) == UInt8(ascii: "{")
    }

    private static func firstMeaningfulByte(in data: Data) -> UInt8? {
        var index = data.startIndex
        if data.count >= 3,
           data[index] == 0xEF,
           data[data.index(after: index)] == 0xBB,
           data[data.index(index, offsetBy: 2)] == 0xBF {
            index = data.index(index, offsetBy: 3)
        }

        while index < data.endIndex {
            let byte = data[index]
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index = data.index(after: index)
                continue
            }
            return byte
        }
        return nil
    }

    private static func bodyPreview(from data: Data, limit: Int = 200) -> String {
        guard !data.isEmpty else { return "<empty>" }

        let raw = String(decoding: data.prefix(limit), as: UTF8.self)
        let collapsed = raw
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return "<empty>" }
        return data.count > limit ? collapsed + "..." : collapsed
    }

    private static func codingPathDescription(for error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context), .dataCorrupted(let context):
            return context.codingPath.map(\.stringValue).joined(separator: ".")
        @unknown default:
            return ""
        }
    }

    private static func decodingDebugDescription(for error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context), .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }
}
