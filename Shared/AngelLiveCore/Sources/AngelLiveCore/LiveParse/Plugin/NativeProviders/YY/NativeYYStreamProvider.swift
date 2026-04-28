import Foundation

struct NativeYYStreamProvider: NativeStreamProvider {
    let providerIds = ["yy", "yy_ws_binary"]

    func resolve(options: [String: Any]) async throws -> [String: Any] {
        let roomId = NativeStreamBridge.stringValue(options["roomId"])
            ?? NativeStreamBridge.stringValue(options["room_id"])
            ?? NativeStreamBridge.stringValue(options["id"])
            ?? ""

        guard !roomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LiveParsePluginError.standardized(
                .init(code: .invalidArgs, message: "roomId is required", context: ["field": "roomId"])
            )
        }

        let requestedGear = NativeStreamBridge.intValue(options["qn"])
            ?? NativeStreamBridge.intValue(options["gear"])
        let requestedLineSeq = NativeStreamBridge.intValue(options["lineSeq"])
            ?? NativeStreamBridge.intValue(options["line_seq"])

        let client = YYWebSocketClient(
            roomId: roomId,
            requestedLineSeq: requestedLineSeq,
            requestedGear: requestedGear
        )
        return try await client.getStreamInfo()
    }
}
