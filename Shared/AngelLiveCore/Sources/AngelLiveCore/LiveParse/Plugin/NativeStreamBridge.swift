import Foundation

/// Host-side native stream resolver used by JS plugins when a platform needs
/// stateful native transport/protocol support that cannot be expressed with
/// Host.http alone.
enum NativeStreamBridge {
    static func resolve(options: [String: Any], defaultProviderId: String) async throws -> [String: Any] {
        let providerId = normalizedProviderId(from: options, defaultProviderId: defaultProviderId)
        guard let provider = NativeStreamProviderRegistry.provider(for: providerId) else {
            throw LiveParsePluginError.standardized(
                .init(
                    code: .invalidArgs,
                    message: "Native stream provider is not supported",
                    context: ["provider": providerId]
                )
            )
        }
        return try await provider.resolve(options: options)
    }

    private static func normalizedProviderId(from options: [String: Any], defaultProviderId: String) -> String {
        let raw = stringValue(options["provider"])
            ?? stringValue(options["providerId"])
            ?? stringValue(options["platformId"])
            ?? stringValue(options["protocolId"])
            ?? defaultProviderId

        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}
