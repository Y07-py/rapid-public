//
//  Logging.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/07.
//

import Foundation
import OSLog

enum LogLevel: Int, CustomStringConvertible {
    case verbose = 0
    case debug = 10
    case info = 20
    case warning = 30
    case error = 40
    case critical = 50
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        case .verbose: return "VERBOSE"
        }
    }
}

struct LogRecord {
    let level: LogLevel
    let message: String
    let name: String
    let timestamp: Date
    let file: String
    let function: String
    let line: Int
}

protocol LogHandler {
    func emit(_ record: LogRecord)
}

struct ConsoleLogHandler: LogHandler {
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    
    func emit(_ record: LogRecord) {
        let time = dateFormatter.string(from: record.timestamp)
        let fileame = (record.file as NSString).lastPathComponent
        let formatted = "[\(time)] [\(record.level)] [\(record.name)] " +
        "[\(fileame):\(record.line) \(record.function)] - \(record.message)"
        
        print(formatted)
    }
}

final class Logger {
    static let shared: Logger = {
        let name = Bundle.main.bundleIdentifier ?? "DEFAULT APP"
        let logger = Logger(name: name)
        
        return logger
    }()
    
    private let name: String
    private var propagate: Bool = false
    private var level: LogLevel = .info
    private static var handlers: [LogHandler] = [ConsoleLogHandler()]
    
    private init(name: String) {
        self.name = name
    }
    
    func setLevel(_ level: LogLevel) {
        self.level = level
    }
    
    private func log(_ level: LogLevel,
                     _ message: @autoclosure () -> String,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        guard level.rawValue >= self.level.rawValue else { return }
        let record = LogRecord(level: level,
                               message: message(),
                               name: name,
                               timestamp: Date(),
                               file: file,
                               function: function,
                               line: line)
        for handler in Logger.handlers {
            handler.emit(record)
        }
    }
    
    func debug(_ message: @autoclosure () -> String,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        log(.debug, message(), file: file, function: function, line: line)
    }
    
    func info(_ message: @autoclosure () -> String,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
        log(.info, message(), file: file, function: function, line: line)
    }
    
    func warning(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
        log(.warning, message(), file: file, function: function, line: line)
    }
    
    func error(_ message: @autoclosure () -> String,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        log(.error, message(), file: file, function: function, line: line)
    }
    
    func critical(_ message: @autoclosure () -> String,
                  file: String = #file,
                  fucntion: String = #function,
                  line: Int = #line) {
        log(.critical, message(), file: file, function: fucntion, line: line)
    }
    
    func verbose(_ message: @autoclosure () -> String,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
        log(.verbose, message(), file: file, function: function, line: line)
    }
    
    private static func defaultLevel() -> LogLevel {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }
    
    static func addhandler(_ handler: LogHandler) {
        handlers.append(handler)
    }
}
