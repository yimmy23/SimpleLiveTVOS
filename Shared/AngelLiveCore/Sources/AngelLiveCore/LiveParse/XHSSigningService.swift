import Foundation
import JavaScriptCore

public final class XHSSigningService: @unchecked Sendable {
    public enum SignError: Error, LocalizedError {
        case jsContextNotInitialized
        case jsDirectoryNotFound
        case missingA1Cookie
        case invalidURL
        case jsonEncodingFailed
        case invalidResult
        case jsException(String)
        case unknown

        public var errorDescription: String? {
            switch self {
            case .jsContextNotInitialized: return "JavaScript context not initialized"
            case .jsDirectoryNotFound: return "JS directory not found"
            case .missingA1Cookie: return "Missing a1 cookie"
            case .invalidURL: return "Invalid URL"
            case .jsonEncodingFailed: return "JSON encoding failed"
            case .invalidResult: return "Invalid result from signer"
            case .jsException(let msg): return "JS exception: \(msg)"
            case .unknown: return "Unknown error"
            }
        }
    }

    private let queue: DispatchQueue
    private let context: JSContext

    public init() throws {
        self.queue = DispatchQueue(label: "xhssigning.service")

        guard let context = JSContext() else {
            throw SignError.jsContextNotInitialized
        }
        self.context = context

        try queue.sync {
            try Self.setupJavaScriptCore(in: context)
        }
    }

    private static func setupJavaScriptCore(in context: JSContext) throws {
        context.exceptionHandler = { _, exception in
            if let exception {
                print("[XHSSigning] JS Error: \(exception)")
            }
        }

        _ = evaluateScript(in: context, script: Self.bootstrapScript, label: "bootstrap")

        let scripts = [
            "ds_sign.js",
            "bundler-runtime.js",
            "library-polyfill.js",
            "vendor-dynamic.js",
            "mnsv2_bundle.js"
        ]

        for script in scripts {
            guard let jsURL = Bundle.module.url(forResource: script.replacingOccurrences(of: ".js", with: ""), withExtension: "js", subdirectory: "XHS"),
                  let code = try? String(contentsOf: jsURL, encoding: .utf8) else {
                print("[XHSSigning] Failed to load \(script)")
                continue
            }
            _ = evaluateScript(in: context, script: code, label: script)
        }

        let initScript = """
        (function() {
            if (!global.XhsMnsV2 || typeof global.XhsMnsV2.initFromBrowser !== 'function') {
                throw new Error('XhsMnsV2 init API missing');
            }
            if (!global.XhsMnsV2.initFromBrowser()) {
                throw new Error('mnsv2 init failed');
            }
            return true;
        })();
        """

        _ = evaluateScript(in: context, script: initScript, label: "mnsv2-init")
    }

    public func sign(url: String, body: String? = nil, cookies: String) throws -> [String: String] {
        guard let a1 = cookieValue(named: "a1", in: cookies), !a1.isEmpty else {
            throw SignError.missingA1Cookie
        }

        let apiPath = try pathWithQuery(from: url)
        let urlLiteral = try jsonLiteral(for: apiPath)
        let bodyLiteral = try body.map { try jsonLiteral(for: $0) } ?? "null"
        let optionsLiteral = try jsonLiteral(for: [
            "a1": a1,
            "platform": "Mac OS"
        ])

        let cookieLiteral = try jsonLiteral(for: cookies)

        let jsCode = """
        (function() {
            global.document.cookie = \(cookieLiteral);
            return global.XhsMnsV2.sign(\(urlLiteral), \(bodyLiteral), \(optionsLiteral));
        })();
        """

        var resultDict: [String: String] = [:]
        var capturedError: SignError?

        queue.sync {
            do {
                guard let jsResult = context.evaluateScript(jsCode) else {
                    throw SignError.invalidResult
                }
                if let exception = context.exception {
                    context.exception = nil
                    throw SignError.jsException("sign: \(exception.toString() ?? "unknown")")
                }

                guard !jsResult.isUndefined, let dict = jsResult.toDictionary() as? [String: String] else {
                    throw SignError.invalidResult
                }
                resultDict = dict
            } catch let error as SignError {
                capturedError = error
            } catch {
                capturedError = .unknown
            }
        }

        if let error = capturedError {
            throw error
        }

        return resultDict
    }

    public func requestUserId(from cookies: String) -> String? {
        return cookieValue(named: "x-user-id-creator.xiaohongshu.com", in: cookies)
            ?? cookieValue(named: "x-user-id.xiaohongshu.com", in: cookies)
    }

    public func cookieValue(named name: String, in cookies: String) -> String? {
        for cookie in cookies.split(separator: ";") {
            let parts = cookie.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            if key == name {
                return String(parts[1])
            }
        }
        return nil
    }

    private func pathWithQuery(from urlString: String) throws -> String {
        guard let components = URLComponents(string: urlString) else {
            throw SignError.invalidURL
        }

        var path = components.path
        if let query = components.percentEncodedQuery, !query.isEmpty {
            path += "?\(query)"
        }
        return path
    }

    private func jsonLiteral(for value: Any) throws -> String {
        if value is NSNull {
            return "null"
        }

        if let string = value as? String {
            let data = try JSONSerialization.data(withJSONObject: [string], options: [])
            guard var json = String(data: data, encoding: .utf8),
                  json.count >= 2 else {
                throw SignError.jsonEncodingFailed
            }
            json.removeFirst()
            json.removeLast()
            return json
        }

        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SignError.jsonEncodingFailed
        }
        return json
    }

    private static func evaluateScript(in context: JSContext, script: String, label: String) -> JSValue? {
        let result = context.evaluateScript(script)
        if context.exception != nil {
            print("[XHSSigning] Error evaluating \(label): \(context.exception?.toString() ?? "unknown")")
            context.exception = nil
        }
        return result
    }

    private static let bootstrapScript = """
    if (typeof global === 'undefined') { var global = this; }
    global.window = global;
    global.self = global;
    global.top = global;
    global.parent = global;
    global.globalThis = global;
    if (typeof console === 'undefined') {
        global.console = { log: function(){}, error: function(){}, warn: function(){} };
    }
    if (typeof setTimeout === 'undefined') {
        global.setTimeout = function(cb) { if (typeof cb === 'function') { cb(); } return 0; };
    }
    if (typeof clearTimeout === 'undefined') {
        global.clearTimeout = function() {};
    }
    global.location = {
        href: 'https://www.xiaohongshu.com/explore',
        host: 'www.xiaohongshu.com',
        hostname: 'www.xiaohongshu.com',
        origin: 'https://www.xiaohongshu.com',
        protocol: 'https:',
        pathname: '/explore',
        search: '',
        hash: '',
        port: '',
        reload: function(){},
        assign: function(){},
        replace: function(){}
    };
    global.document = {
        createElement: function(tag) {
            var el = {
                style: {},
                tagName: tag,
                setAttribute: function(){},
                getAttribute: function(){ return null; },
                appendChild: function(){},
                removeChild: function(){},
                addEventListener: function(){},
                innerHTML: '',
                textContent: ''
            };
            if (tag === 'canvas') {
                el.getContext = function() {
                    return {
                        fillRect: function(){},
                        fillText: function(){},
                        measureText: function(){ return { width: 10 }; },
                        getImageData: function(){ return { data: new Uint8Array(100) }; },
                        canvas: { toDataURL: function(){ return 'data:,'; } }
                    };
                };
                el.toDataURL = function(){ return 'data:,'; };
            }
            if (tag === 'a') {
                el.href = '';
            }
            return el;
        },
        body: { appendChild: function(){}, removeChild: function(){}, style: {} },
        head: { appendChild: function(){} },
        querySelectorAll: function(){ return []; },
        querySelector: function(){ return null; },
        getElementById: function(){ return null; },
        getElementsByTagName: function(){ return []; },
        addEventListener: function(){},
        removeEventListener: function(){},
        createEvent: function(){ return { initEvent: function(){} }; },
        cookie: '',
        documentElement: {
            style: {},
            getAttribute: function(){ return null; },
            clientWidth: 1920,
            clientHeight: 1080
        },
        createTextNode: function(){ return {}; },
        readyState: 'complete',
        hidden: false,
        visibilityState: 'visible',
        title: ''
    };
    global.document.location = global.location;
    global.navigator = {
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        platform: 'MacIntel',
        language: 'zh-CN',
        languages: ['zh-CN', 'zh'],
        hardwareConcurrency: 8,
        deviceMemory: 8,
        maxTouchPoints: 0,
        vendor: 'Google Inc.',
        appVersion: '5.0',
        cookieEnabled: true,
        plugins: { length: 5, item: function(){ return null; }, namedItem: function(){ return null; }, refresh: function(){} },
        mimeTypes: { length: 2, item: function(){ return null; }, namedItem: function(){ return null; } },
        connection: { effectiveType: '4g', downlink: 10, rtt: 50 },
        webdriver: false,
        getBattery: function(){ return Promise.resolve({ charging: true, level: 1 }); }
    };
    global.screen = { width: 1920, height: 1080, availWidth: 1920, availHeight: 1050, colorDepth: 24, pixelDepth: 24 };
    var __ls = {};
    global.localStorage = {
        getItem: function(key) { return __ls[key] || null; },
        setItem: function(key, value) { __ls[key] = String(value); },
        removeItem: function(key) { delete __ls[key]; },
        clear: function() { __ls = {}; },
        length: 0,
        key: function() { return null; }
    };
    var __ss = {};
    global.sessionStorage = {
        getItem: function(key) { return __ss[key] || null; },
        setItem: function(key, value) { __ss[key] = String(value); },
        removeItem: function(key) { delete __ss[key]; },
        clear: function() { __ss = {}; },
        length: 0,
        key: function() { return null; }
    };
    global.history = { length: 2, pushState: function(){}, replaceState: function(){}, back: function(){}, forward: function(){} };
    global.XMLHttpRequest = function() {
        this.open = function(){};
        this.send = function(){};
        this.setRequestHeader = function(){};
        this.addEventListener = function(){};
    };
    global.fetch = function() {
        return Promise.resolve({ json: function(){ return {}; }, text: function(){ return ''; } });
    };
    global.crypto = {
        getRandomValues: function(arr) {
            for (var i = 0; i < arr.length; i++) {
                arr[i] = Math.floor(Math.random() * 256);
            }
            return arr;
        },
        subtle: {}
    };
    global.btoa = global.btoa || function(s) { return s; };
    global.atob = global.atob || function(s) { return s; };
    global.TextEncoder = global.TextEncoder || function() {};
    global.TextEncoder.prototype.encode = function(str) {
        var encoded = unescape(encodeURIComponent(str));
        var bytes = new Uint8Array(encoded.length);
        for (var i = 0; i < encoded.length; i++) {
            bytes[i] = encoded.charCodeAt(i);
        }
        return bytes;
    };
    global.TextDecoder = global.TextDecoder || function() {};
    global.TextDecoder.prototype.decode = function(arr) {
        var bytes = arr instanceof Uint8Array ? arr : new Uint8Array(arr || []);
        var result = '';
        for (var i = 0; i < bytes.length; i++) {
            result += String.fromCharCode(bytes[i]);
        }
        return result;
    };
    global.Buffer = global.Buffer || {
        from: function(input) {
            if (typeof input === 'string') {
                var encoded = unescape(encodeURIComponent(input));
                var arr = [];
                for (var i = 0; i < encoded.length; i++) {
                    arr.push(encoded.charCodeAt(i));
                }
                return arr;
            }
            return Array.prototype.slice.call(input);
        }
    };
    global.requestAnimationFrame = function(cb) { return setTimeout(cb, 16); };
    global.cancelAnimationFrame = function(id) { clearTimeout(id); };
    global.Image = function(){};
    global.HTMLElement = function(){};
    global.HTMLCanvasElement = function(){};
    global.Event = function(type) { this.type = type; };
    global.CustomEvent = global.Event;
    global.MutationObserver = function() {
        this.observe = function(){};
        this.disconnect = function(){};
        this.takeRecords = function(){ return []; };
    };
    global.performance = {
        now: function(){ return Date.now(); },
        timing: { navigationStart: Date.now() },
        getEntriesByType: function(){ return []; },
        mark: function(){},
        measure: function(){}
    };
    global.chrome = {};
    global.Reflect = Reflect;
    global.Proxy = Proxy;
    global.webpackChunkxhs_pc_web = [];
    var __directEval = eval;
    global.eval = function(code) { return __directEval(code); };
    """
}