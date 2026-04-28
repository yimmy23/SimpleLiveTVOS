import Foundation

protocol NativeStreamProvider {
    var providerIds: [String] { get }

    func resolve(options: [String: Any]) async throws -> [String: Any]
}

enum NativeStreamProviderRegistry {
    private static let providers: [NativeStreamProvider] = [
        NativeYYStreamProvider()
    ]

    private static let providersById: [String: NativeStreamProvider] = {
        var result: [String: NativeStreamProvider] = [:]
        for provider in providers {
            for providerId in provider.providerIds {
                let normalizedId = providerId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalizedId.isEmpty else { continue }
                result[normalizedId] = provider
            }
        }
        return result
    }()

    static func provider(for providerId: String) -> NativeStreamProvider? {
        let normalizedId = providerId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return providersById[normalizedId]
    }
}
