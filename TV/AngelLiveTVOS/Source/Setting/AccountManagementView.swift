//
//  AccountManagementView.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2024/11/28.
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

// MARK: - Bilibili 用户信息模型 (tvOS)

struct BilibiliUserInfoTV: Codable {
    let mid: Int?
    let uname: String?
    let userid: String?
    let sign: String?
    let birthday: String?
    let sex: String?
    let rank: String?
    let face: String?
    let nickFree: Bool?

    enum CodingKeys: String, CodingKey {
        case mid, uname, userid, sign, birthday, sex, rank, face
        case nickFree = "nick_free"
    }

    var displayName: String {
        uname ?? "未知用户"
    }
}

private extension BilibiliUserInfoTV {
    init(from info: BilibiliAccountUserInfo) {
        self.mid = info.mid
        self.uname = info.uname
        self.userid = info.userid
        self.sign = info.sign
        self.birthday = info.birthday
        self.sex = info.sex
        self.rank = info.rank
        self.face = info.face
        self.nickFree = info.nickFree
    }
}

// MARK: - 统一平台模型

enum TVPlatformItem: String, CaseIterable, Identifiable, Equatable {
    case bilibili
    case douyin
    case kuaishou
    case soop
    case kick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bilibili: return "哔哩哔哩"
        case .douyin: return "抖音"
        case .kuaishou: return "快手"
        case .soop: return "SOOP"
        case .kick: return "Kick"
        }
    }

    var sessionID: PlatformSessionID {
        switch self {
        case .bilibili: return .bilibili
        case .douyin: return .douyin
        case .kuaishou: return .kuaishou
        case .soop: return .soop
        case .kick: return .kick
        }
    }

    var liveType: LiveType {
        switch self {
        case .bilibili: return .bilibili
        case .douyin: return .douyin
        case .kuaishou: return .ks
        case .soop: return .soop
        case .kick: return .kick
        }
    }

    /// 是否支持 HTTP 级别的 Cookie 验证（Bilibili 通过 API 验证，其他平台仅正则校验）
    var supportsHTTPValidation: Bool {
        self == .bilibili
    }

    /// 手动输入帮助文本中的网站域名
    var websiteHost: String {
        switch self {
        case .bilibili: return "bilibili.com"
        case .douyin: return "douyin.com"
        case .kuaishou: return "kuaishou.com"
        case .soop: return "sooplive.co.kr"
        case .kick: return "kick.com"
        }
    }

    /// Cookie 格式提示
    var requiredCookieHint: String {
        switch self {
        case .bilibili: return "需包含 SESSDATA"
        case .douyin: return "需包含 ttwid"
        case .kuaishou: return "需包含 key=value 格式"
        case .soop: return "需包含 AuthTicket"
        case .kick: return "需包含 kick_session 或 session_token"
        }
    }
}

// MARK: - 账号管理主视图

struct AccountManagementView: View {
    @StateObject private var syncService = BilibiliCookieSyncService.shared

    @State private var currentPage: AccountPage = .main
    @State private var platformLoginStatus: [PlatformSessionID: Bool] = [:]

    enum AccountPage: Equatable {
        case main
        case platformDetail(TVPlatformItem)
        case lanSync
        case manualInput(TVPlatformItem)
    }

    var body: some View {
        ZStack {
            switch currentPage {
            case .main:
                accountMainView
                    .transition(.opacity)
            case .platformDetail(let platform):
                PlatformDetailPageView(
                    platform: platform,
                    onBack: {
                        currentPage = .main
                    },
                    onManualInput: { p in
                        currentPage = .manualInput(p)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .lanSync:
                BilibiliLANSyncPageView(onBack: { currentPage = .main })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .manualInput(let platform):
                PlatformManualInputPageView(
                    platform: platform,
                    onBack: { currentPage = .platformDetail(platform) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }

    // MARK: - 主页面

    private var accountMainView: some View {
        VStack(spacing: 15) {
            Spacer()

            // 同步区域
            Button {
                currentPage = .lanSync
            } label: {
                HStack(spacing: 15) {
                    Text("局域网同步")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("推荐")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $syncService.iCloudSyncEnabled) {
                Text("iCloud 自动同步")
            }

            if syncService.iCloudSyncEnabled {
                Button {
                    Task {
                        _ = await syncService.syncFromICloud()
                        await syncService.syncAllPlatformsFromICloud()
                        await refreshAllLoginStatuses()
                    }
                } label: {
                    HStack(spacing: 15) {
                        Text("立即从 iCloud 同步")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }


            // 平台列表
            ForEach(TVPlatformItem.allCases) { platform in
                Button {
                    currentPage = .platformDetail(platform)
                } label: {
                    HStack(spacing: 15) {
                        Text(platform.title)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(loginStatusText(for: platform))
                            .font(.system(size: 30))
                            .foregroundStyle(loginStatusColor(for: platform))
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 200)
        }
        .task {
            await refreshAllLoginStatuses()
        }
    }

    // MARK: - 登录状态辅助方法

    private func loginStatusText(for platform: TVPlatformItem) -> String {
        if platform == .bilibili {
            return syncService.isLoggedIn ? "已登录" : "未登录"
        }
        return (platformLoginStatus[platform.sessionID] ?? false) ? "已登录" : "未登录"
    }

    private func loginStatusColor(for platform: TVPlatformItem) -> Color {
        if platform == .bilibili {
            return syncService.isLoggedIn ? .green : .gray
        }
        return (platformLoginStatus[platform.sessionID] ?? false) ? .green : .gray
    }

    private func refreshAllLoginStatuses() async {
        for platform in TVPlatformItem.allCases where platform != .bilibili {
            let session = await PlatformSessionManager.shared.getSession(platformId: platform.sessionID)
            platformLoginStatus[platform.sessionID] = session?.state == .authenticated
        }
    }
}

// MARK: - 平台详情页面

struct PlatformDetailPageView: View {
    let platform: TVPlatformItem
    let onBack: () -> Void
    let onManualInput: (TVPlatformItem) -> Void

    @StateObject private var syncService = BilibiliCookieSyncService.shared
    @State private var isLoggedIn = false
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var bilibiliUserInfo: BilibiliUserInfoTV?
    @State private var showLogoutConfirm = false

    var body: some View {
        VStack(spacing: 15) {
            Spacer()

            // 状态显示区域
            statusSection
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

            // 已登录时的操作
            if isLoggedIn {
                // Bilibili 专属：验证 Cookie
                if platform.supportsHTTPValidation {
                    Button {
                        Task { await validateBilibiliCookie() }
                    } label: {
                        HStack {
                            Text("验证 Cookie")
                                .foregroundColor(.primary)
                            Spacer()
                            if isValidating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isValidating)
                }

                // 退出登录
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Text("退出登录")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            // 手动输入 Cookie（始终可用）
            Button {
                onManualInput(platform)
            } label: {
                HStack {
                    Text("手动输入 Cookie")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 200)
        }
        .onExitCommand { onBack() }
        .alert("退出登录", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) { logout() }
        } message: {
            Text("确定要退出\(platform.title)登录吗？")
        }
        .task {
            await refreshStatus()
        }
    }

    // MARK: - 状态显示

    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 16) {
            if isValidating {
                ProgressView()
                    .scaleEffect(1.5)
                Text("正在验证...")
                    .font(.headline)
            } else if platform == .bilibili, let user = bilibiliUserInfo {
                // Bilibili 已登录且有用户信息
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text(user.displayName)
                    .font(.title2.bold())
                if let mid = user.mid {
                    Text("UID: \(mid)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = validationMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text("验证失败")
                    .font(.title2)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isLoggedIn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("已登录")
                    .font(.title2)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("未登录")
                    .font(.title2)
            }
        }
    }

    // MARK: - 状态刷新

    private func refreshStatus() async {
        if platform == .bilibili {
            isLoggedIn = syncService.isLoggedIn
            if isLoggedIn {
                await validateBilibiliCookie()
            }
        } else {
            let session = await PlatformSessionManager.shared.getSession(platformId: platform.sessionID)
            isLoggedIn = session?.state == .authenticated
        }
    }

    // MARK: - Bilibili Cookie 验证

    private func validateBilibiliCookie() async {
        isValidating = true
        validationMessage = nil

        let cookie = syncService.getCurrentCookie()
        guard !cookie.isEmpty else {
            validationMessage = "Cookie 为空"
            isValidating = false
            return
        }

        let result = await BilibiliAccountService.shared.loadUserInfo(
            cookie: cookie,
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
        )

        switch result {
        case .success(let info):
            bilibiliUserInfo = BilibiliUserInfoTV(from: info)
            validationMessage = nil
            if let mid = info.mid {
                syncService.setCookie(cookie, uid: "\(mid)", source: .local, save: false)
            }
        case .failure(let error):
            bilibiliUserInfo = nil
            validationMessage = error.localizedDescription
        }

        isValidating = false
    }

    // MARK: - 退出登录

    private func logout() {
        if platform == .bilibili {
            syncService.clearCookie()
            bilibiliUserInfo = nil
        }
        Task {
            await PlatformSessionManager.shared.clearSession(platformId: platform.sessionID)
        }
        isLoggedIn = false
        validationMessage = nil
    }
}

// MARK: - 通用手动输入页面

struct PlatformManualInputPageView: View {
    let platform: TVPlatformItem
    let onBack: () -> Void

    @StateObject private var syncService = BilibiliCookieSyncService.shared
    @State private var cookieInput = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var isSuccess = false

    var body: some View {
        VStack(spacing: 15) {
            Spacer()

            if isSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    Text("设置成功")
                        .font(.title2.bold())
                    Button {
                        onBack()
                    } label: {
                        Text("完成")
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                TextField("请输入 \(platform.title) Cookie 字符串", text: $cookieInput)

                if let message = validationMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

                Button {
                    Task { await validateAndSave() }
                } label: {
                    HStack {
                        Text("验证并保存")
                            .foregroundColor(.primary)
                        Spacer()
                        if isValidating {
                            ProgressView()
                        }
                    }
                }
                .disabled(cookieInput.isEmpty || isValidating)

                // 帮助信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("如何获取 Cookie")
                        .font(.headline)

                    Text("1. 在电脑浏览器中登录 \(platform.websiteHost)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("2. 按 F12 打开开发者工具")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("3. 切换到 Network (网络) 标签")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("4. 刷新页面，点击任意请求")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("5. 在 Headers 中找到 Cookie 字段并复制")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("提示：\(platform.requiredCookieHint)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
            }

            Spacer(minLength: 200)
        }
        .onExitCommand {
            onBack()
        }
    }

    private func validateAndSave() async {
        isValidating = true
        validationMessage = nil

        if platform == .bilibili {
            // Bilibili 使用专用的 setManualCookie 保持缓存同步
            let result = await syncService.setManualCookie(cookieInput)
            switch result {
            case .valid:
                isSuccess = true
            case .invalid(let reason):
                validationMessage = "Cookie 无效: \(reason)"
            case .expired:
                validationMessage = "Cookie 已过期"
            case .networkError(let error):
                validationMessage = "网络错误: \(error.localizedDescription)"
            }
        } else {
            // 其他平台使用 PlatformSessionManager
            let result = await PlatformSessionManager.shared.loginWithCookie(
                platformId: platform.sessionID,
                cookie: cookieInput,
                source: .manual,
                validateBeforeSave: platform != .kick && platform != .kuaishou
            )
            switch result {
            case .valid:
                isSuccess = true
            case .invalid(let reason):
                validationMessage = "Cookie 无效: \(reason)"
            case .expired:
                validationMessage = "Cookie 已过期"
            case .networkError(let message):
                validationMessage = "网络错误: \(message)"
            }
        }

        isValidating = false
    }
}

// MARK: - 局域网同步页面视图

struct BilibiliLANSyncPageView: View {
    @StateObject private var syncService = BilibiliCookieSyncService.shared
    let onBack: () -> Void

    @State private var isSuccess = false
    @State private var syncedPlatformSummary = ""

    var body: some View {
        VStack(spacing: 15) {
            Spacer()

            // 状态区域
            VStack(spacing: 20) {
                if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    Text("同步成功")
                        .font(.title2.bold())
                    Text(syncedPlatformSummary.isEmpty ? "登录信息已保存" : syncedPlatformSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        onBack()
                    } label: {
                        Text("完成")
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                } else {
                    Image(systemName: "wifi")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("等待连接...")
                        .font(.title2.bold())
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)

            // 操作步骤
            VStack(alignment: .leading, spacing: 16) {
                Text("操作步骤")
                    .font(.headline)

                StepRow(number: 1, text: "确保 Apple TV 和 iOS 在同一 Wi-Fi 网络")
                StepRow(number: 2, text: "在 iOS/macOS 端 Angel Live 中登录平台账号")
                StepRow(number: 3, text: "点击「同步到 tvOS」按钮")
                StepRow(number: 4, text: "选择此 Apple TV 设备")
            }
            .padding(.top, 20)

            Button {
                onBack()
            } label: {
                HStack {
                    Text("返回")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 200)
        }
        .onExitCommand {
            onBack()
        }
        .task {
            syncService.startBonjourListener()
        }
        .onDisappear {
            syncService.stopBonjourListener()
        }
        .onChange(of: syncService.lastBonjourSyncAt) { _, newValue in
            guard newValue != nil else { return }
            syncedPlatformSummary = platformSummary(syncService.lastBonjourSyncedPlatformIds)
            isSuccess = true
        }
    }

    private func platformSummary(_ platformIds: [String]) -> String {
        guard !platformIds.isEmpty else { return "登录信息已保存" }

        let names = platformIds.compactMap { platformId -> String? in
            switch platformId {
            case PlatformSessionID.bilibili.rawValue:
                return "哔哩哔哩"
            case PlatformSessionID.douyin.rawValue:
                return "抖音"
            case PlatformSessionID.kuaishou.rawValue:
                return "快手"
            case PlatformSessionID.soop.rawValue:
                return "SOOP"
            case PlatformSessionID.kick.rawValue:
                return "Kick"
            default:
                return nil
            }
        }

        guard !names.isEmpty else { return "登录信息已保存" }
        return "已保存：\(names.joined(separator: "、"))"
    }
}

// MARK: - 辅助视图

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 15) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

#Preview {
    AccountManagementView()
}
