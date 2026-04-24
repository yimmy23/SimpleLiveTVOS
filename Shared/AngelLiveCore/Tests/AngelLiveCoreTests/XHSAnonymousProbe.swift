import Foundation
import Testing
@testable import AngelLiveCore

// Probe: does XHS serve current_room_info anonymously given only a client-generated a1?
// RUN: swift test --filter XHSAnonymousProbe
@Suite("XHSAnonymousProbe", .serialized)
struct XHSAnonymousProbeTests {

    static func randomA1() -> String {
        let hex = "0123456789abcdef"
        return String((0..<32).map { _ in hex.randomElement()! })
    }

    @Test("anonymous current_room_info with client-generated a1")
    func anonymousCurrentRoomInfo() async throws {
        let signer = try XHSSigningService()
        let a1 = Self.randomA1()
        let cookieHeader = "a1=\(a1); webId=\(a1)"

        // First: fetch the livelist page to harvest a real room_id (anonymous, no cookie needed - it's HTML).
        let listPageURL = URL(string: "https://www.xiaohongshu.com/livelist?channel_id=0&channel_type=web_live_list")!
        var listRequest = URLRequest(url: listPageURL)
        listRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let (listData, _) = try await URLSession.shared.data(for: listRequest)
        let listHTML = String(data: listData, encoding: .utf8) ?? ""
        // crude extraction — pick first 6+ digit room id from an embedded link/state
        let roomId: String? = {
            let patterns = [
                #"/livestream/(\d{6,})"#,
                #""room_id"\s*:\s*"?(\d{6,})"#,
                #""roomId"\s*:\s*"?(\d{6,})"#
            ]
            for p in patterns {
                if let re = try? NSRegularExpression(pattern: p),
                   let m = re.firstMatch(in: listHTML, range: NSRange(listHTML.startIndex..., in: listHTML)),
                   let r = Range(m.range(at: 1), in: listHTML) {
                    return String(listHTML[r])
                }
            }
            return nil
        }()

        guard let roomId else {
            print("[probe] couldn't find a room_id in livelist page — skipping")
            return
        }
        print("[probe] a1=\(a1)  roomId=\(roomId)")

        // Now: sign /current_room_info and call it anonymously.
        let apiURL = "https://live-room.xiaohongshu.com/api/sns/red/live/web/v1/room/current_room_info?room_id=\(roomId)&source=web_live&client_type=1"
        let signed = try signer.sign(url: apiURL, body: nil, cookies: cookieHeader)
        print("[probe] signed headers:", signed)

        var req = URLRequest(url: URL(string: apiURL)!)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://www.xiaohongshu.com", forHTTPHeaderField: "Origin")
        req.setValue("https://www.xiaohongshu.com/livestream/\(roomId)?source=web_live_list", forHTTPHeaderField: "Referer")
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        for (k, v) in signed { req.setValue(v, forHTTPHeaderField: k) }

        let (body, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        let bodyStr = String(data: body, encoding: .utf8) ?? ""
        print("[probe] HTTP \(http.statusCode)")
        print("[probe] body head:", bodyStr.prefix(1200))
        // Don't assert — this test is a research probe, not an invariant.
    }

    @Test("anonymous squarefeed")
    func anonymousSquarefeed() async throws {
        let signer = try XHSSigningService()
        let a1 = Self.randomA1()
        let cookieHeader = "a1=\(a1); webId=\(a1)"
        let url = "https://live-room.xiaohongshu.com/api/sns/red/live/web/feed/v1/squarefeed?source=13&category=0&pre_source=&extra_info=%7B%22image_formats%22%3A%5B%22jpg%22%2C%22webp%22%2C%22avif%22%5D%7D&size=5"
        let signed = try signer.sign(url: url, body: nil, cookies: cookieHeader)
        var req = URLRequest(url: URL(string: url)!)
        req.setValue("Mozilla/5.0 Chrome/122", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://www.xiaohongshu.com", forHTTPHeaderField: "Origin")
        req.setValue("https://www.xiaohongshu.com/livelist?channel_id=0&channel_type=web_live_list", forHTTPHeaderField: "Referer")
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        for (k, v) in signed { req.setValue(v, forHTTPHeaderField: k) }
        let (body, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        let bodyStr = String(data: body, encoding: .utf8) ?? ""
        print("[probe-feed] HTTP \(http.statusCode)  body head:", bodyStr.prefix(800))
    }
}
