import Foundation
import Starscream

public protocol WebSocketConnectionDelegate: AnyObject {
    func webSocketDidConnect()
    func webSocketDidDisconnect(error: Error?)
    func webSocketDidReceiveMessage(text: String, nickname: String, color: UInt32)
}

public final class WebSocketConnection {
    var socket: WebSocket?
    public var parameters: [String: String]?
    var headers: [String: String]?
    public weak var delegate: WebSocketConnectionDelegate?

    let liveType: LiveType

    private let pluginId: String?
    private let danmakuPlan: LiveParseDanmakuPlan?
    private var pluginDriver: PluginJSDanmakuDriver?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var shouldReconnect = true
    private var isClosingAfterDriverFailure = false
    private var reconnectAttempts = 0
    private var driverTimerReason: PluginJSDanmakuDriver.TickReason = .heartbeat

    private var requestURL: URL? {
        if let raw = danmakuPlan?.transport?.url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        if let raw = parameters?["ws_url"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        if let raw = parameters?["url"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return nil
    }

    public init(parameters: [String: String]?, headers: [String: String]?, liveType: LiveType) {
        self.parameters = parameters
        self.headers = headers
        self.liveType = liveType
        self.pluginId = nil
        self.danmakuPlan = nil
    }

    public init(
        parameters: [String: String]?,
        headers: [String: String]?,
        liveType: LiveType,
        pluginId: String,
        roomId: String,
        userId: String?,
        danmakuPlan: LiveParseDanmakuPlan
    ) {
        self.parameters = parameters
        self.headers = headers
        self.liveType = liveType
        self.pluginId = pluginId
        self.danmakuPlan = danmakuPlan

        if danmakuPlan.usesPluginRuntimeDriver {
            self.pluginDriver = PluginJSDanmakuDriver(
                pluginId: pluginId,
                roomId: roomId,
                userId: userId,
                plan: danmakuPlan
            )
        }
    }

    deinit {
        Task { [pluginDriver] in
            await pluginDriver?.destroy(reason: .deinitialized)
        }
        disconnect()
    }

    public func connect() {
        shouldReconnect = true

        guard let pluginDriver else {
            delegate?.webSocketDidDisconnect(
                error: LiveParseError.danmuArgsParseError("弹幕驱动不受支持", "插件未声明 runtime.driver=plugin_js_v1：\(liveType.rawValue)")
            )
            return
        }

        guard let requestURL else {
            delegate?.webSocketDidDisconnect(
                error: LiveParseError.danmuArgsParseError("弹幕连接地址缺失", "插件未返回可用的 transport.url / ws_url")
            )
            return
        }

        Task {
            do {
                let result = try await pluginDriver.createSession()
                applyDriverResult(result)
                await MainActor.run {
                    self.connectSocket(url: requestURL)
                }
            } catch {
                handleDriverFailure(error)
            }
        }
    }

    public func disconnect() {
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        socket?.disconnect()
        socket?.forceDisconnect()
        socket = nil

        Task { [pluginDriver] in
            await pluginDriver?.destroy(reason: .disconnect)
        }
    }

    private func connectSocket(url: URL) {
        var request = URLRequest(url: url)

        if let subprotocols = danmakuPlan?.transport?.subprotocols, !subprotocols.isEmpty {
            request.setValue(subprotocols.joined(separator: ","), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }

        for (key, value) in effectiveWebSocketHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let socket = WebSocket(request: request)
        socket.delegate = self
        self.socket = socket
        socket.connect()
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }

        reconnectTimer?.invalidate()
        let interval: TimeInterval = 10
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.shouldReconnect, let url = self.requestURL else { return }
            self.reconnectAttempts += 1
            self.connectSocket(url: url)
        }
        if let reconnectTimer {
            RunLoop.current.add(reconnectTimer, forMode: .common)
        }
    }
}

extension WebSocketConnection: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected:
            reconnectAttempts = 0
            reconnectTimer?.invalidate()
            reconnectTimer = nil

            guard let pluginDriver else {
                handleDriverFailure(
                    LiveParseError.danmuArgsParseError("弹幕驱动不受支持", "插件驱动在连接建立后丢失")
                )
                return
            }

            Task {
                do {
                    let result = try await pluginDriver.onOpen()
                    applyDriverResult(result)
                    delegate?.webSocketDidConnect()
                } catch {
                    handleDriverFailure(error)
                }
            }
        case .disconnected(let reason, let code):
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil

            if isClosingAfterDriverFailure {
                isClosingAfterDriverFailure = false
                Task { [pluginDriver] in
                    await pluginDriver?.destroy(reason: .error)
                }
                return
            }

            let error = NSError(
                domain: "websocket.disconnected",
                code: Int(code),
                userInfo: [
                    "reason": reason,
                    NSLocalizedDescriptionKey: reason
                ]
            )
            delegate?.webSocketDidDisconnect(error: error)
            scheduleReconnect()
        case .text(let string):
            handleIncomingFrame(frameType: .text, text: string, data: nil)
        case .binary(let data):
            handleIncomingFrame(frameType: .binary, text: nil, data: data)
        case .error(let error):
            if let upgradeError = error as? HTTPUpgradeError {
                switch upgradeError {
                case .notAnUpgrade(let statusCode, let responseHeaders):
                    Logger.error(
                        "[DanmuWS] HTTP upgrade rejected status=\(statusCode), headers=\(responseHeaders)",
                        category: .danmu
                    )
                case .invalidData:
                    Logger.error(
                        "[DanmuWS] HTTP upgrade invalidData",
                        category: .danmu
                    )
                }
            } else {
                Logger.error(
                    "[DanmuWS] websocket error: \(error?.localizedDescription ?? "nil")",
                    category: .danmu
                )
            }
            handleConnectionFailure(error)
        case .cancelled:
            handleConnectionFailure(
                NSError(
                    domain: "websocket.cancelled",
                    code: -999,
                    userInfo: [NSLocalizedDescriptionKey: "WebSocket cancelled"]
                )
            )
        case .peerClosed:
            handleConnectionFailure(
                NSError(
                    domain: "websocket.peerClosed",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "WebSocket peer closed"]
                )
            )
        default:
            break
        }
    }
}

private extension WebSocketConnection {
    func handleIncomingFrame(
        frameType: PluginJSDanmakuDriver.IncomingFrameType,
        text: String?,
        data: Data?
    ) {
        guard let pluginDriver else {
            handleDriverFailure(
                LiveParseError.danmuArgsParseError("弹幕驱动不受支持", "插件驱动在收包时丢失")
            )
            return
        }

        Task {
            do {
                let result = try await pluginDriver.onFrame(
                    frameType: frameType,
                    text: text,
                    data: data
                )
                applyDriverResult(result)
            } catch {
                handleDriverFailure(error)
            }
        }
    }

    func applyDriverResult(_ result: LiveParseDanmakuDriverResult) {
        deliverMessages(result.messages)
        sendWrites(result.writes)
        updateTimer(result.timer)
    }

    func deliverMessages(_ messages: [LiveParseDanmakuMessage]?) {
        guard let messages else { return }
        for message in messages {
            delegate?.webSocketDidReceiveMessage(
                text: message.text,
                nickname: message.nickname,
                color: message.color ?? 0xFFFFFF
            )
        }
    }

    func sendWrites(_ writes: [LiveParseDanmakuWriteAction]?) {
        guard let writes else { return }
        for write in writes {
            switch write.kind {
            case .text:
                guard let text = write.text else { continue }
                socket?.write(string: text)
            case .binary:
                guard let bytesBase64 = write.bytesBase64,
                      let data = Data(base64Encoded: bytesBase64) else { continue }
                socket?.write(data: data)
            }
        }
    }

    func updateTimer(_ timer: LiveParseDanmakuTimerPlan?) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        guard let timer else { return }
        switch timer.mode {
        case .off:
            return
        case .heartbeat:
            driverTimerReason = .heartbeat
        case .polling:
            driverTimerReason = .polling
        }

        let interval = max(Double(timer.intervalMs ?? 0) / 1000.0, 1.0)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runDriverTick()
        }
        if let heartbeatTimer {
            RunLoop.current.add(heartbeatTimer, forMode: .common)
        }
    }

    func effectiveWebSocketHeaders() -> [String: String] {
        guard let headers else { return [:] }

        if pluginId == "panda" || danmakuPlan?.runtime?.protocolId == "panda_centrifuge_json" {
            var effective: [String: String] = [:]

            if let userAgent = headerValue(named: "User-Agent", in: headers) {
                effective["User-Agent"] = userAgent
            }
            if let origin = headerValue(named: "Origin", in: headers) {
                effective["Origin"] = origin
            }
            if let host = requestURL?.host, !host.isEmpty {
                effective["Host"] = host
            }

            // Match the working Python probe handshake and stop Starscream from auto-injecting cookies.
            effective["Cookie"] = ""
            return effective
        }

        return headers
    }

    func headerValue(named name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func runDriverTick() {
        guard let pluginDriver else { return }
        Task {
            do {
                let result = try await pluginDriver.onTick(reason: driverTimerReason)
                applyDriverResult(result)
            } catch {
                handleDriverFailure(error)
            }
        }
    }

    func handleConnectionFailure(_ error: Error?) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        delegate?.webSocketDidDisconnect(error: error)
        scheduleReconnect()
    }

    func handleDriverFailure(_ error: Error) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        shouldReconnect = false
        delegate?.webSocketDidDisconnect(error: error)
        isClosingAfterDriverFailure = true
        socket?.disconnect()
        socket?.forceDisconnect()
        socket = nil

        Task { [pluginDriver] in
            await pluginDriver?.destroy(reason: .error)
        }
    }
}
