// RemoteInputService.swift
// AngelLiveTVOS
//
// 轻量 HTTP 服务，监听本地端口，让手机浏览器通过网页表单向 tvOS 发送文本输入。
// 无需第三方依赖，纯 Network.framework 实现。

import Foundation
import Network
import Observation
import AngelLiveDependencies

// 输入事件：字段类型 + 内容
struct RemoteInputEvent {
    enum Field: String {
        case title
        case url
        case search
    }
    let field: Field
    let value: String
}

@Observable
final class RemoteInputService {

    private(set) var isRunning = false
    private(set) var localIPAddress: String = ""
    private(set) var port: UInt16 = 8080

    // 最新收到的输入事件，View 通过 onChange 监听
    private(set) var lastEvent: RemoteInputEvent?

    private var listener: NWListener?

    func start() {
        guard listener == nil else { return }
        localIPAddress = Common.getWiFiIPAddress() ?? ""
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener.start(queue: .global(qos: .utility))
        } catch {
            print("[RemoteInputService] start error: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveRequest(connection: connection)
    }

    private func receiveRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            let response = self.processRequest(raw)
            self.sendResponse(connection: connection, body: response)
        }
    }

    private func processRequest(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? ""

        // POST /input — 接收表单提交，返回 JSON 供前端 JS 消费
        if firstLine.hasPrefix("POST /input") {
            if let bodyLine = raw.components(separatedBy: "\r\n\r\n").last {
                let result = parseFormBody(bodyLine)
                let msg = result.message.replacingOccurrences(of: "\"", with: "\\\"")
                let json = "{\"success\":\(result.success),\"message\":\"\(msg)\"}"
                return "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(json.utf8.count)\r\nConnection: close\r\n\r\n\(json)"
            }
            return "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"success\":false,\"message\":\"未收到数据\"}"
        }

        // GET /search — 搜索输入页
        if firstLine.hasPrefix("GET /search") {
            return htmlResponse(searchPage())
        }

        // GET /config 或 / — 配置页（URL + 标题）
        return htmlResponse(configPage())
    }

    @discardableResult
    private func parseFormBody(_ body: String) -> (success: Bool, message: String) {
        var urlValue: String?
        var titleValue: String?
        var fieldValue: RemoteInputEvent.Field?
        var singleValue = ""

        for pair in body.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0]
            let val = kv[1].replacingOccurrences(of: "+", with: " ")
                           .removingPercentEncoding ?? kv[1]
            switch key {
            case "url_value":   urlValue = val
            case "title_value": titleValue = val
            case "field":       fieldValue = RemoteInputEvent.Field(rawValue: val)
            case "value":       singleValue = val
            default: break
            }
        }

        // 配置页：url + title
        if let url = urlValue {
            if url.isEmpty {
                return (false, "地址不能为空")
            }
            let event = RemoteInputEvent(field: .url, value: url)
            Task { @MainActor in self.lastEvent = event }
            if let title = titleValue, !title.isEmpty {
                let titleEvent = RemoteInputEvent(field: .title, value: title)
                Task { @MainActor in self.lastEvent = titleEvent }
                return (true, "已填入：\(title) / \(url)")
            }
            return (true, "已填入地址：\(url)")
        }

        // 搜索页
        if urlValue == nil, titleValue == nil, let field = fieldValue {
            if singleValue.isEmpty {
                return (false, "内容不能为空")
            }
            let event = RemoteInputEvent(field: field, value: singleValue)
            Task { @MainActor in self.lastEvent = event }
            return (true, "已发送：\(singleValue)")
        }

        return (false, "未识别的表单数据")
    }

    private func sendResponse(connection: NWConnection, body: String) {
        let data = Data(body.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - HTTP Responses

    private func htmlResponse(_ html: String) -> String {
        let bodyData = Data(html.utf8)
        let header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
        return header + html
    }

    private func redirectResponse() -> String {
        return "HTTP/1.1 303 See Other\r\nLocation: /\r\nConnection: close\r\n\r\n"
    }

    private func pageHTML(title: String, body: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="zh">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title)</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: -apple-system, sans-serif; background: #1c1c1e; color: #f2f2f7; padding: 24px; }
          h1 { font-size: 20px; font-weight: 700; margin-bottom: 24px; }
          .card { background: #2c2c2e; border-radius: 12px; padding: 20px; margin-bottom: 16px; }
          label { font-size: 13px; color: #8e8e93; display: block; margin-bottom: 8px; }
          input[type=text] { width: 100%; background: #3a3a3c; border: none; border-radius: 8px;
            color: #f2f2f7; font-size: 16px; padding: 12px 14px; outline: none; margin-bottom: 14px; }
          .result { font-size: 13px; margin-top: 14px; min-height: 18px; word-break: break-all; white-space: pre-wrap; }
          .result.ok  { color: #30d158; }
          .result.err { color: #ff453a; }
          button { width: 100%; background: #0a84ff; color: white; border: none;
            border-radius: 10px; font-size: 16px; font-weight: 600; padding: 14px; }
          button:active { opacity: 0.7; }
          .hint { font-size: 12px; color: #636366; margin-top: 16px; }
        </style>
        <script>
        function submitForm(form, resultId) {
          var data = new FormData(form);
          var params = new URLSearchParams(data).toString();
          var result = document.getElementById(resultId);
          fetch('/input', { method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params })
          .then(function(r){ return r.json(); })
          .then(function(j){
            result.className = 'result ' + (j.success ? 'ok' : 'err');
            result.textContent = j.success ? '已同步到 Apple TV' : j.message;
          })
          .catch(function(){ result.className='result err'; result.textContent='发送失败，请重试'; });
          return false;
        }
        </script>
        </head>
        <body>
        <h1>\(title)</h1>
        \(body)
        </body>
        </html>
        """
    }

    private func configPage() -> String {
        pageHTML(title: "Angel Live 添加视频", body: """
        <div class="card">
          <form onsubmit="return submitForm(this,'r1')">
            <label>收藏标题（可选）</label>
            <input type="text" name="title_value" placeholder="为视频起个名字" autocomplete="off">
            <label style="margin-top:14px">视频地址</label>
            <input type="text" name="url_value" placeholder="https://..." autocomplete="off">
            <button type="submit">填入</button>
            <p class="result" id="r1"></p>
          </form>
        </div>
        <p class="hint">提交后内容会自动填入 tvOS 配置页输入框</p>
        """)
    }

    private func searchPage() -> String {
        pageHTML(title: "Angel Live 搜索", body: """
        <div class="card">
          <form onsubmit="return submitForm(this,'r1')">
            <input type="hidden" name="field" value="search">
            <label>搜索内容</label>
            <input type="text" name="value" placeholder="主播名 / 链接 / 分享口令" autocomplete="off">
            <button type="submit">发送到搜索框</button>
            <p class="result" id="r1"></p>
          </form>
        </div>
        <p class="hint">提交后内容会自动填入 tvOS 搜索框</p>
        """)
    }

    // MARK: - 获取本机局域网 IP（使用 Common.getWiFiIPAddress）
}

