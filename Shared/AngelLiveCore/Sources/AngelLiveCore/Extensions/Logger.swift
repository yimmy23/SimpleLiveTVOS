//
//  Logger.swift
//  AngelLiveCore
//
//  统一的日志系统，替代散落的 print 语句
//

import Foundation
import os.log

/// 日志级别
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// 日志分类
public enum LogCategory: String {
    case player = "Player"
    case danmu = "Danmu"
    case network = "Network"
    case favorite = "Favorite"
    case cloudKit = "CloudKit"
    case general = "General"
    case plugin = "Plugin"
}

/// 统一的日志工具
public enum Logger {

    /// 最低日志级别，低于此级别的日志不会输出
    #if DEBUG
    nonisolated(unsafe) public static var minimumLevel: LogLevel = .debug
    #else
    nonisolated(unsafe) public static var minimumLevel: LogLevel = .warning
    #endif

    /// 是否启用日志输出
    nonisolated(unsafe) public static var isEnabled: Bool = true
    
    // MARK: - 便捷方法
    
    /// 调试日志
    public static func debug(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, line: line)
    }
    
    /// 信息日志
    public static func info(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .info, category: category, file: file, line: line)
    }
    
    /// 警告日志
    public static func warning(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, line: line)
    }
    
    /// 错误日志
    public static func error(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .error, category: category, file: file, line: line)
    }
    
    /// 错误日志（带 Error 对象）
    public static func error(_ error: Error, message: String? = nil, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        let errorMessage = message.map { "\($0): \(error.localizedDescription)" } ?? error.localizedDescription
        log(errorMessage, level: .error, category: category, file: file, line: line)
    }
    
    // MARK: - 核心日志方法
    
    private static func log(_ message: String, level: LogLevel, category: LogCategory, file: String, line: Int) {
        guard isEnabled && level >= minimumLevel else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.emoji) [\(category.rawValue)] \(message)"
        
        #if DEBUG
        // Debug 模式下输出到控制台，包含文件和行号
        print("\(logMessage) (\(fileName):\(line))")
        #else
        // Release 模式下使用 os_log
        let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.angellive", category: category.rawValue)
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
        #endif
    }
}
