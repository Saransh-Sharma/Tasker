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
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fatal: return .fault
        }
    }

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .fatal: return "FATAL"
        }
    }
}

/// Logging service for consistent application-wide logging
final class LoggingService {
    // MARK: - Properties

    /// Singleton instance for global access
    static let shared = LoggingService()

    /// The minimum log level to display
    private(set) var minimumLogLevel: LogLevel = .warning

    /// Whether to log to the console
    private(set) var logToConsole: Bool = true

    /// Whether to log to a file
    private(set) var logToFile: Bool = false

    /// URL of the log file, if file logging is enabled
    private(set) var logFileURL: URL?

    /// System logger object
    private let osLog: OSLog

    /// Timestamp formatter (UTC, fixed precision for stable logs)
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        self.osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.tasker", category: "general")
        self.minimumLogLevel = .warning
        configureFromLaunchArguments(ProcessInfo.processInfo.arguments)
        setupLogFile()
    }

    // MARK: - Configuration

    /// Set the minimum log level to display
    /// - Parameter level: The minimum log level
    func setMinimumLogLevel(_ level: LogLevel) {
        self.minimumLogLevel = level
    }

    /// Configure runtime log verbosity from process arguments.
    /// Currently supports `-TASKER_VERBOSE_LOGS` for debug-level verbosity.
    func configureFromLaunchArguments(_ arguments: [String]) {
        if arguments.contains("-TASKER_VERBOSE_LOGS") {
            minimumLogLevel = .debug
        }
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

    // MARK: - Structured API

    /// Standardized event log API.
    /// Format: `ts=<ISO8601UTC> lvl=<LEVEL> cmp=<Component> evt=<event_name> msg="<message>" key=value ...`
    func log(
        level: LogLevel,
        component: String? = nil,
        event: String,
        message: String,
        fields: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.rawValue >= minimumLogLevel.rawValue else { return }

        let cmp = component ?? Self.componentName(from: file)
        let ts = Self.timestampFormatter.string(from: Date())

        var chunks: [String] = [
            "ts=\(ts)",
            "lvl=\(level.label)",
            "cmp=\(Self.formatFieldValue(cmp))",
            "evt=\(Self.formatFieldValue(Self.sanitizeEvent(event)))",
            "msg=\(Self.formatMessage(message))"
        ]

        for key in fields.keys.sorted() {
            guard !key.isEmpty else { continue }
            chunks.append("\(Self.sanitizeFieldKey(key))=\(Self.formatFieldValue(fields[key] ?? ""))")
        }

        let formattedMessage = chunks.joined(separator: " ")

        if logToConsole {
            os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
        }

        if logToFile, let fileURL = logFileURL {
            writeToLogFile(formattedMessage, fileURL: fileURL)
        }

        _ = function
        _ = line
    }

    // MARK: - Legacy Compatibility Methods

    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    func fatal(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .fatal, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    /// Log an error object, extracting structured metadata.
    func log(
        error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let nsError = error as NSError
        log(
            level: .error,
            event: "legacy_error",
            message: Self.singleLine(nsError.localizedDescription),
            fields: [
                "domain": nsError.domain,
                "code": String(nsError.code)
            ],
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Helpers

    private static func componentName(from file: String) -> String {
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        return name.isEmpty ? "UnknownComponent" : name
    }

    private static func sanitizeEvent(_ event: String) -> String {
        let trimmed = event.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "legacy_message" }

        // Convert to snake_case-ish: alnum preserved, everything else collapsed to underscores.
        var output = ""
        var previousWasUnderscore = false
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.append(Character(scalar).lowercased())
                previousWasUnderscore = false
            } else if !previousWasUnderscore {
                output.append("_")
                previousWasUnderscore = true
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .isEmpty ? "legacy_message" : output.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func sanitizeFieldKey(_ key: String) -> String {
        let sanitized = sanitizeEvent(key)
        return sanitized.isEmpty ? "field" : sanitized
    }

    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatMessage(_ value: String) -> String {
        let escaped = singleLine(value)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func formatFieldValue(_ value: String) -> String {
        let normalized = singleLine(value)
        let safePattern = "^[A-Za-z0-9._:/-]+$"
        if normalized.range(of: safePattern, options: .regularExpression) != nil {
            return normalized
        }

        let escaped = normalized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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

public func logDebug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.debug(message, file: file, function: function, line: line)
}

public func logDebug(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let suffix = terminator == "\n" ? "" : terminator
    LoggingService.shared.debug(message + suffix, file: file, function: function, line: line)
}

public func logInfo(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.info(message, file: file, function: function, line: line)
}

public func logInfo(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let suffix = terminator == "\n" ? "" : terminator
    LoggingService.shared.info(message + suffix, file: file, function: function, line: line)
}

public func logWarning(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.warning(message, file: file, function: function, line: line)
}

public func logWarning(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let suffix = terminator == "\n" ? "" : terminator
    LoggingService.shared.warning(message + suffix, file: file, function: function, line: line)
}

public func logError(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.error(message, file: file, function: function, line: line)
}

public func logError(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let suffix = terminator == "\n" ? "" : terminator
    LoggingService.shared.error(message + suffix, file: file, function: function, line: line)
}

public func logFatal(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.fatal(message, file: file, function: function, line: line)
}

public func logFatal(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let suffix = terminator == "\n" ? "" : terminator
    LoggingService.shared.fatal(message + suffix, file: file, function: function, line: line)
}

public func logError(
    _ error: Error,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(error: error, file: file, function: function, line: line)
}

public func logWarning(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(
        level: .warning,
        component: component,
        event: event,
        message: message,
        fields: fields,
        file: file,
        function: function,
        line: line
    )
}

public func logError(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(
        level: .error,
        component: component,
        event: event,
        message: message,
        fields: fields,
        file: file,
        function: function,
        line: line
    )
}

public func logFatal(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(
        level: .fatal,
        component: component,
        event: event,
        message: message,
        fields: fields,
        file: file,
        function: function,
        line: line
    )
}
