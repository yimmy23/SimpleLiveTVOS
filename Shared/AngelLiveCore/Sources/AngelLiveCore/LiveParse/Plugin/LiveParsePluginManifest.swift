import Foundation

public struct LiveParsePluginManifest: Codable, Equatable, Sendable {
    public let pluginId: String
    public let version: String
    public let apiVersion: Int
    public let displayName: String?
    /// 面向用户的平台简介，用于平台页等静态展示。
    public let platformDescription: String?
    /// 面向用户的简短更新日志，按条目展示。
    public let changelog: [String]?
    public let liveTypes: [String]
    public let entry: String
    public let minHostVersion: String?
    /// 插件入口脚本执行前需要预加载的脚本文件名列表（相对于插件根目录或 bundle 资源目录）
    public let preloadScripts: [String]?
    /// 凭证能力声明（可选）
    public let auth: ManifestAuth?
    /// 登录流程声明（可选）。未声明的插件不会出现在宿主的平台登录列表中。
    public let loginFlow: ManifestLoginFlow?
    /// 分享链接候选匹配规则（可选）。宿主只用它筛选候选平台，最终解析仍由插件完成。
    public let shareResolve: ManifestShareResolve?

    public init(
        pluginId: String,
        version: String,
        apiVersion: Int,
        displayName: String? = nil,
        platformDescription: String? = nil,
        changelog: [String]? = nil,
        liveTypes: [String],
        entry: String,
        minHostVersion: String? = nil,
        preloadScripts: [String]? = nil,
        auth: ManifestAuth? = nil,
        loginFlow: ManifestLoginFlow? = nil,
        shareResolve: ManifestShareResolve? = nil
    ) {
        self.pluginId = pluginId
        self.version = version
        self.apiVersion = apiVersion
        self.displayName = displayName
        self.platformDescription = platformDescription
        self.changelog = changelog
        self.liveTypes = liveTypes
        self.entry = entry
        self.minHostVersion = minHostVersion
        self.preloadScripts = preloadScripts
        self.auth = auth
        self.loginFlow = loginFlow
        self.shareResolve = shareResolve
    }
}

public struct ManifestShareResolve: Codable, Equatable, Hashable, Sendable {
    /// 可识别的 URL host，如 ["live.example.com", "short.example"]。
    public let hosts: [String]?
    /// 非 URL 文本兜底关键词，如 App scheme、口令前缀等。
    public let keywords: [String]?

    public init(hosts: [String]? = nil, keywords: [String]? = nil) {
        self.hosts = hosts
        self.keywords = keywords
    }
}

public struct ManifestAuth: Codable, Equatable, Sendable {
    public let required: Bool?
    public let credentialKinds: [String]?
    public let supportsStatusCheck: Bool?
    public let supportsValidation: Bool?

    public init(
        required: Bool? = nil,
        credentialKinds: [String]? = nil,
        supportsStatusCheck: Bool? = nil,
        supportsValidation: Bool? = nil
    ) {
        self.required = required
        self.credentialKinds = credentialKinds
        self.supportsStatusCheck = supportsStatusCheck
        self.supportsValidation = supportsValidation
    }
}

public struct ManifestLoginFlow: Codable, Equatable, Sendable {
    /// 交互类型，默认 "webview"；tvOS 端仅使用通用字段做手动输入引导。
    public let kind: String?
    public let loginURL: String
    public let userAgent: String?
    public let cookieDomains: [String]
    /// 任一出现即视为登录成功。
    public let authSignalCookies: [String]
    /// 可选的 uid 源 Cookie 名称（按顺序尝试）。
    public let uidCookieNames: [String]?
    /// 成功后跳转 URL 包含该关键词。
    public let successURLKeyword: String?
    /// 成功后页面标题包含该关键词（辅助判定）。
    public let successTitleKeyword: String?
    /// 检测到成功后延迟多少秒抓取 Cookie（默认 0）。
    public let postRedirectDelay: Double?
    /// tvOS 手动输入时展示给用户的提示。
    public let requiredCookieHint: String?
    /// tvOS 手动输入帮助文本中出现的网站域名。
    public let websiteHost: String?

    public init(
        kind: String? = nil,
        loginURL: String,
        userAgent: String? = nil,
        cookieDomains: [String],
        authSignalCookies: [String],
        uidCookieNames: [String]? = nil,
        successURLKeyword: String? = nil,
        successTitleKeyword: String? = nil,
        postRedirectDelay: Double? = nil,
        requiredCookieHint: String? = nil,
        websiteHost: String? = nil
    ) {
        self.kind = kind
        self.loginURL = loginURL
        self.userAgent = userAgent
        self.cookieDomains = cookieDomains
        self.authSignalCookies = authSignalCookies
        self.uidCookieNames = uidCookieNames
        self.successURLKeyword = successURLKeyword
        self.successTitleKeyword = successTitleKeyword
        self.postRedirectDelay = postRedirectDelay
        self.requiredCookieHint = requiredCookieHint
        self.websiteHost = websiteHost
    }
}

extension LiveParsePluginManifest {
    static func load(from url: URL) throws -> LiveParsePluginManifest {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(LiveParsePluginManifest.self, from: data)
        } catch {
            throw LiveParsePluginError.invalidManifest(error.localizedDescription)
        }
    }
}
