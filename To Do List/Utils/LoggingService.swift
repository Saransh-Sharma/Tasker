import Foundation
import os.log

/// Log level enumeration
public enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case fatal = 4
    
    /// Convert LogLevel to OSLogType for system logging
    var osLogType: OSLogType {
        switch self {
        case .debug:    return .debug
        case .info:     return .info
        case .warning:  return .default
        case .error:    return .error
        case .fatal:    return .fault
        }
    }
    
    /// Emoji prefix for log messages to improve readability
    var emoji: String {
        switch self {
        case .debug:    return "🔍"
        case .info:     return "ℹ️"
        case .warning:  return "⚠️"
        case .error:    return "❌"
        case .fatal:    return "🔥"
        }
    }
}

/// Logging service for consistent application-wide logging
final class LoggingService {
    // MARK: - Properties
    
    /// Singleton instance for global access
    static let shared = LoggingService()
    
    /// The minimum log level to display
    private(set) var minimumLogLevel: LogLevel = .debug
    
    /// Whether to include timestamps in log messages
    private(set) var includeTimestamps: Bool = true
    
    /// Whether to include the calling file name and line number
    private(set) var includeSourceInfo: Bool = true
    
    /// Whether to log to the console
    private(set) var logToConsole: Bool = true
    
    /// Whether to log to a file
    private(set) var logToFile: Bool = false
    
    /// URL of the log file, if file logging is enabled
    private(set) var logFileURL: URL?
    
    /// System logger object
    private let osLog: OSLog
    
    // MARK: - Initialization
    
    private init() {
        self.osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.tasker", category: "general")
        
        #if DEBUG
        self.minimumLogLevel = .debug
        #else
        self.minimumLogLevel = .warning // Reduce log level in release to minimize warnings
        #endif
        
        setupLogFile()
    }
    
    // MARK: - Configuration
    
    /// Set the minimum log level to display
    /// - Parameter level: The minimum log level
    func setMinimumLogLevel(_ level: LogLevel) {
        self.minimumLogLevel = level
    }
    
    /// Enable or disable timestamp inclusion in logs
    /// - Parameter enabled: Whether to include timestamps
    func setTimestampLogging(_ enabled: Bool) {
        self.includeTimestamps = enabled
    }
    
    /// Enable or disable source information (file name, line number) in logs
    /// - Parameter enabled: Whether to include source information
    func setSourceInfoLogging(_ enabled: Bool) {
        self.includeSourceInfo = enabled
    }
    
    /// Configure file logging
    /// - Parameters:
    ///   - enabled: Whether to log to a file
    ///   - fileURL: Optional custom file URL; if nil, uses default location
    func configureFileLogging(enabled: Bool, fileURL: URL? = nil) {
        self.logToFile = enabled
        
        if let customURL = fileURL {
            self.logFileURL = customURL
        } else if enabled && self.logFileURL == nil {
            setupLogFile()
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a message at debug level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log a message at info level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Log a message at warning level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Log a message at error level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    /// Log a message at fatal level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func fatal(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fatal, file: file, function: function, line: line)
    }
    
    /// Log an error object, extracting the localized description
    /// - Parameters:
    ///   - error: The error to log
    ///   - file: The file where the log was called (auto-filled)
    ///   - function: The function where the log was called (auto-filled)
    ///   - line: The line where the log was called (auto-filled)
    func log(
        error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let nsError = error as NSError
        let message = """
        Error: \(nsError.localizedDescription)
        Domain: \(nsError.domain)
        Code: \(nsError.code)
        \(nsError.userInfo)
        """
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    /// Core logging method that handles all log output
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    private func log(
        _ message: String,
        level: LogLevel,
        file: String,
        function: String,
        line: Int
    ) {
        guard level.rawValue >= minimumLogLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        var components = [String]()
        
        // Add timestamp if configured
        if includeTimestamps {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            components.append("[\(dateFormatter.string(from: Date()))]")
        }
        
        // Add log level with emoji
        components.append(level.emoji + " [\(String(describing: level).uppercased())]")
        
        // Add source info if configured
        if includeSourceInfo {
            components.append("[\(fileName):\(line) \(function)]")
        }
        
        // Add message
        components.append(message)
        
        let formattedMessage = components.joined(separator: " ")
        
        // Log to console if configured
        if logToConsole {
            os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
        }
        
        // Log to file if configured and possible
        if logToFile, let fileURL = logFileURL {
            writeToLogFile(formattedMessage, fileURL: fileURL)
        }
    }
    
    /// Set up the log file
    private func setupLogFile() {
        guard logFileURL == nil else { return }
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs")
        
        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            do {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            } catch {
                os_log("Failed to create logs directory: %{public}@", log: osLog, type: .error, error.localizedDescription)
                return
            }
        }
        
        // Create log file name with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        logFileURL = logsDirectory.appendingPathComponent("tasker_\(today).log")
    }
    
    /// Write a log message to the log file
    /// - Parameters:
    ///   - message: The message to write
    ///   - fileURL: The URL of the log file
    private func writeToLogFile(_ message: String, fileURL: URL) {
        let fullMessage = message + "\n"
        guard let data = fullMessage.data(using: .utf8) else { return }
        
        // Append to log file or create it if it doesn't exist
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } catch {
                // If we can't append, try to overwrite
                try? data.write(to: fileURL, options: .atomic)
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Global Convenience Functions

/// Log a message at debug level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logDebug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.debug(message, file: file, function: function, line: line)
}

/// Log a message at info level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logInfo(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.info(message, file: file, function: function, line: line)
}

/// Log a message at warning level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logWarning(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.warning(message, file: file, function: function, line: line)
}

/// Log a message at error level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logError(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.error(message, file: file, function: function, line: line)
}

/// Log a message at fatal level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logFatal(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.fatal(message, file: file, function: function, line: line)
}

/// Log an Error object
/// - Parameters:
///   - error: The error to log
///   - file: The file where the log was called (auto-filled)
///   - function: The function where the log was called (auto-filled)
///   - line: The line where the log was called (auto-filled)
public func logError(
    _ error: Error,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(error: error, file: file, function: function, line: line)
}
