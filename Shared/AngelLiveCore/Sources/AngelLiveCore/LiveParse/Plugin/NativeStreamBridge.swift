import Foundation

/// Host-side native stream resolver used by JS plugins when a platform needs
/// stateful native transport/protocol support that cannot be expressed with
/// Host.http alone.
enum NativeStreamBridge {
    static func resolve(options: [String: Any], declaration: ManifestNativeStream?) async throws -> [String: Any] {
        guard let declaration else {
            throw LiveParsePluginError.standardized(
                .init(
                    code: .invalidArgs,
                    message: "Native stream is not declared by manifest",
                    context: [:]
                )
            )
        }

        let providerId = try normalizedProviderId(from: options, declaration: declaration)
        let allowedProviderIds = normalizedAllowedProviderIds(from: declaration)
        if !allowedProviderIds.isEmpty, !allowedProviderIds.contains(providerId) {
            throw LiveParsePluginError.standardized(
                .init(
                    code: .invalidArgs,
                    message: "Native stream provider is not allowed by manifest",
                    context: ["provider": providerId]
                )
            )
        }

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

    private static func normalizedProviderId(from options: [String: Any], declaration: ManifestNativeStream) throws -> String {
        let raw = stringValue(options["provider"])
            ?? stringValue(options["providerId"])
            ?? stringValue(options["platformId"])
            ?? stringValue(options["protocolId"])
            ?? stringValue(declaration.defaultProviderId)

        guard let raw else {
            throw LiveParsePluginError.standardized(
                .init(
                    code: .invalidArgs,
                    message: "Native stream provider is required",
                    context: [:]
                )
            )
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedAllowedProviderIds(from declaration: ManifestNativeStream) -> Set<String> {
        var values = declaration.allowedProviderIds ?? []
        if let defaultProviderId = declaration.defaultProviderId {
            values.append(defaultProviderId)
        }
        return Set(values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized.isEmpty ? nil : normalized
        })
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
