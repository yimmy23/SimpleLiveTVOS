//
//  MacPlatformLoginWebSheet.swift
//  AngelLiveMacOS
//
//  通用平台 Web 登录面板（macOS 版）。
//  所有登录参数来自 manifest.loginFlow。
//

import SwiftUI
import WebKit
import AngelLiveCore

struct MacPlatformLoginWebSheet: View {
    let pluginId: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var syncService = PlatformCredentialSyncService.shared

    @State private var entry: LoginPlatformEntry?
    @State private var currentWebView: WKWebView?
    @State private var statusText = "请在网页中完成登录，系统会自动保存会话并由宿主托管鉴权。"
    @State private var isSavingCookie = false
    @State private var isLoggedIn = false
    @State private var errorMessage: String?
    @State private var lastSavedCookieSignature: String?
    @State private var cookiePollingTimer: Timer?

    var body: some View {
        NavigationStack {
            Group {
                if let entry {
                    loginContent(entry: entry)
                } else {
                    ProgressView("加载中...")
                }
            }
            .navigationTitle("\(entry?.displayName ?? pluginId) 登录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isLoggedIn {
                        Button("退出登录", role: .destructive) {
                            logout()
                        }
                    }
                }
            }
            .task {
                entry = await PlatformLoginRegistry.shared.entry(pluginId: pluginId)
                await reloadLoginStatus()
            }
            .onDisappear {
                cookiePollingTimer?.invalidate()
                cookiePollingTimer = nil
            }
        }
    }

    @ViewBuilder
    private func loginContent(entry: LoginPlatformEntry) -> some View {
        VStack(spacing: 0) {
            MacPlatformLoginWebView(
                loginFlow: entry.loginFlow,
                onWebViewCreated: { webView in
                    currentWebView = webView
                    startCookiePolling(entry: entry)
                },
                onNavigationStateChange: { title, url, didFinish in
                    updateNavigationStatus(title: title, url: url)
                    if didFinish {
                        pollCookieOnce(entry: entry)
                    }
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if isSavingCookie {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在保存登录信息...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }

    // MARK: - Navigation

    private func updateNavigationStatus(title: String?, url: URL?) {
        guard !isSavingCookie else { return }
        if let title, !title.isEmpty {
            statusText = title
        } else if let host = url?.host(), !host.isEmpty {
            statusText = "当前页面：\(host)"
        } else {
            statusText = "请在网页中完成登录，系统会自动保存会话并由宿主托管鉴权。"
        }
    }

    // MARK: - Cookie Polling (macOS 需要轮询)

    private func startCookiePolling(entry: LoginPlatformEntry) {
        cookiePollingTimer?.invalidate()
        cookiePollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            pollCookieOnce(entry: entry)
        }
    }

    private func pollCookieOnce(entry: LoginPlatformEntry) {
        guard !isSavingCookie, let currentWebView else { return }
        let loginFlow = entry.loginFlow

        currentWebView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let filteredCookies = cookies.filter { cookie in
                loginFlow.cookieDomains.contains { hint in
                    cookie.domain.contains(hint)
                }
            }

            let cookieString = makeCookieString(from: filteredCookies)
            guard !cookieString.isEmpty else { return }
            guard containsAuthenticatedCookie(in: filteredCookies, loginFlow: loginFlow) else { return }

            let signature = makeCookieSignature(from: filteredCookies)

            Task { @MainActor in
                guard !isSavingCookie else { return }
                guard signature != lastSavedCookieSignature else { return }
                await saveCookie(cookieString, entry: entry, cookies: filteredCookies, signature: signature)
            }
        }
    }

    private func saveCookie(_ cookieString: String, entry: LoginPlatformEntry, cookies: [HTTPCookie], signature: String) async {
        guard !cookieString.isEmpty else { return }

        isSavingCookie = true
        errorMessage = nil
        statusText = "检测到登录状态，正在保存..."

        let uid = extractUID(from: cookies, loginFlow: entry.loginFlow)
        let shouldValidate = entry.auth?.supportsValidation ?? false

        let result = await PlatformSessionManager.shared.loginWithCookie(
            pluginId: pluginId,
            cookie: cookieString,
            uid: uid,
            source: .local,
            validateBeforeSave: shouldValidate
        )

        switch result {
        case .valid:
            isLoggedIn = true
            lastSavedCookieSignature = signature
            statusText = "登录信息已保存（宿主托管鉴权）"
            errorMessage = nil
            await syncService.refreshLoginStatus(pluginId: pluginId)
            if syncService.iCloudSyncEnabled {
                await syncService.syncAllToICloud()
            }
        case .expired:
            statusText = "登录信息已过期"
            errorMessage = "Cookie 已过期，请重新登录。"
        case .invalid(let reason):
            statusText = "登录信息无效"
            errorMessage = reason
        case .networkError(let message):
            statusText = "网络错误"
            errorMessage = message
        }

        isSavingCookie = false
    }

    // MARK: - Cookie 工具

    private func containsAuthenticatedCookie(in cookies: [HTTPCookie], loginFlow: ManifestLoginFlow) -> Bool {
        let names = Set(cookies.map(\.name))
        return loginFlow.authSignalCookies.contains { names.contains($0) }
    }

    private func makeCookieSignature(from cookies: [HTTPCookie]) -> String {
        cookies
            .sorted(by: { $0.name < $1.name })
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: ";")
    }

    private func makeCookieString(from cookies: [HTTPCookie]) -> String {
        var deduplicated = [String: String]()
        for cookie in cookies {
            deduplicated[cookie.name] = cookie.value
        }
        return deduplicated
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
    }

    private func extractUID(from cookies: [HTTPCookie], loginFlow: ManifestLoginFlow) -> String? {
        let uidNames = loginFlow.uidCookieNames ?? ["DedeUserID", "uid", "user_id", "userId"]
        for name in uidNames {
            if let value = cookies.first(where: { $0.name == name })?.value, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    // MARK: - Actions

    private func logout() {
        Task {
            await syncService.clearSession(pluginId: pluginId)
            if syncService.iCloudSyncEnabled {
                await syncService.syncAllToICloud()
            }
            await MainActor.run {
                isLoggedIn = false
                statusText = "已退出登录"
                errorMessage = nil
            }
        }
    }

    private func reloadLoginStatus() async {
        let session = await PlatformSessionManager.shared.getSession(pluginId: pluginId)
        isLoggedIn = session?.state == .authenticated
    }
}

// MARK: - WebView (macOS)

private struct MacPlatformLoginWebView: NSViewRepresentable {
    let loginFlow: ManifestLoginFlow
    let onWebViewCreated: (WKWebView) -> Void
    let onNavigationStateChange: (String?, URL?, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigationStateChange: onNavigationStateChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        if let userAgent = loginFlow.userAgent {
            webView.customUserAgent = userAgent
        }

        DispatchQueue.main.async {
            onWebViewCreated(webView)
        }

        if let url = URL(string: loginFlow.loginURL) {
            var request = URLRequest(url: url)
            if let userAgent = loginFlow.userAgent {
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }
            webView.load(request)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onNavigationStateChange: (String?, URL?, Bool) -> Void

        init(onNavigationStateChange: @escaping (String?, URL?, Bool) -> Void) {
            self.onNavigationStateChange = onNavigationStateChange
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onNavigationStateChange(webView.title, webView.url, false)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onNavigationStateChange(webView.title, webView.url, true)
        }
    }
}
