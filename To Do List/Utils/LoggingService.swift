import Foundation
import os.log
import os.signpost
#if canImport(Darwin)
import Darwin
#endif

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
final class LoggingService: @unchecked Sendable {
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
    private let stateLock = NSLock()

    /// Timestamp formatter factory (UTC, fixed precision for stable logs)
    private static func makeTimestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static let defaultLogPreviewLength = 160

    static func previewText(_ text: String, maxLength: Int = defaultLogPreviewLength) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength))
    }

    // MARK: - Initialization

    /// Initializes a new instance.
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
        stateLock.lock()
        defer { stateLock.unlock() }
        self.minimumLogLevel = level
    }

    /// Configure runtime log verbosity from process arguments.
    /// Currently supports `-TASKER_VERBOSE_LOGS` and `-TASKER_VERBOSE_PERF_TRACE`
    /// for debug-level verbosity.
    func configureFromLaunchArguments(_ arguments: [String]) {
        if arguments.contains("-TASKER_VERBOSE_LOGS")
            || arguments.contains("-TASKER_VERBOSE_PERF_TRACE") {
            stateLock.lock()
            defer { stateLock.unlock() }
            minimumLogLevel = .debug
        }
    }

    /// Configure file logging
    /// - Parameters:
    ///   - enabled: Whether to log to a file
    ///   - fileURL: Optional custom file URL; if nil, uses default location
    func configureFileLogging(enabled: Bool, fileURL: URL? = nil) {
        stateLock.lock()
        defer { stateLock.unlock() }
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
        stateLock.lock()
        let minimumLogLevel = self.minimumLogLevel
        let logToConsole = self.logToConsole
        let logToFile = self.logToFile
        let logFileURL = self.logFileURL
        stateLock.unlock()

        guard level.rawValue >= minimumLogLevel.rawValue else { return }

        let cmp = component ?? Self.componentName(from: file)
        let ts = Self.makeTimestampFormatter().string(from: Date())

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

    /// Executes debug.
    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    /// Executes info.
    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    /// Executes warning.
    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    /// Executes error.
    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, event: "legacy_message", message: Self.singleLine(message), file: file, function: function, line: line)
    }

    /// Executes fatal.
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

    /// Executes componentName.
    private static func componentName(from file: String) -> String {
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        return name.isEmpty ? "UnknownComponent" : name
    }

    /// Executes sanitizeEvent.
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

    /// Executes sanitizeFieldKey.
    private static func sanitizeFieldKey(_ key: String) -> String {
        let sanitized = sanitizeEvent(key)
        return sanitized.isEmpty ? "field" : sanitized
    }

    /// Executes singleLine.
    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Executes formatMessage.
    private static func formatMessage(_ value: String) -> String {
        let escaped = singleLine(value)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Executes formatFieldValue.
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

        stateLock.lock()
        defer { stateLock.unlock() }

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

public struct TaskerPerformanceInterval: Sendable {
    fileprivate let name: StaticString
    fileprivate let signpostID: OSSignpostID?
    fileprivate let isEnabled: Bool
}

public enum TaskerPerformanceTrace {
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private static let launchEnvironment = ProcessInfo.processInfo.environment
    private static let performanceLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tasker",
        category: "performance"
    )
    private static let pointsOfInterestLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tasker",
        category: .pointsOfInterest
    )
    private static let tracingEnabled =
        launchEnvironment["PERFORMANCE_TEST"] == "1"
        || launchArguments.contains("-TASKER_ENABLE_PERF_TRACE")
        || launchArguments.contains("-TASKER_VERBOSE_PERF_TRACE")
    private static let pointsOfInterestEnabled =
        tracingEnabled
        || launchEnvironment["OS_ACTIVITY_TOOLS_PRIVACY"] == "YES"
        || launchEnvironment["OS_LOG_DT_HOOK_MODE"] != nil

    public static var isEnabled: Bool { tracingEnabled }
    public static var isPointsOfInterestEnabled: Bool { pointsOfInterestEnabled }

    /// Begins a signposted interval for Instruments correlation.
    public static func begin(_ name: StaticString) -> TaskerPerformanceInterval {
        guard tracingEnabled || pointsOfInterestEnabled else {
            return TaskerPerformanceInterval(name: name, signpostID: nil, isEnabled: false)
        }
        let signpostID = OSSignpostID(log: performanceLog)
        if tracingEnabled {
            os_signpost(.begin, log: performanceLog, name: name, signpostID: signpostID)
        }
        if pointsOfInterestEnabled {
            os_signpost(.begin, log: pointsOfInterestLog, name: name, signpostID: signpostID)
        }
        return TaskerPerformanceInterval(name: name, signpostID: signpostID, isEnabled: true)
    }

    /// Ends a previously started signposted interval.
    public static func end(_ interval: TaskerPerformanceInterval) {
        guard interval.isEnabled, let signpostID = interval.signpostID else { return }
        if tracingEnabled {
            os_signpost(.end, log: performanceLog, name: interval.name, signpostID: signpostID)
        }
        if pointsOfInterestEnabled {
            os_signpost(.end, log: pointsOfInterestLog, name: interval.name, signpostID: signpostID)
        }
    }

    /// Emits a point-in-time event to the performance log.
    public static func event(_ name: StaticString) {
        guard tracingEnabled || pointsOfInterestEnabled else { return }
        if tracingEnabled {
            os_signpost(.event, log: performanceLog, name: name)
        }
        if pointsOfInterestEnabled {
            os_signpost(.event, log: pointsOfInterestLog, name: name)
        }
    }

    /// Emits a point-in-time event with a numeric payload for quick Instruments correlation.
    public static func event(_ name: StaticString, value: Int) {
        guard tracingEnabled || pointsOfInterestEnabled else { return }
        if tracingEnabled {
            os_signpost(.event, log: performanceLog, name: name, "%{public}ld", value)
        }
        if pointsOfInterestEnabled {
            os_signpost(.event, log: pointsOfInterestLog, name: name, "%{public}ld", value)
        }
    }
}

enum TaskerMemoryDiagnostics {
    #if DEBUG
    private static func makeByteFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }
    #endif

    static func checkpoint(
        event: String,
        message: String,
        component: String = "memory",
        fields: [String: String] = [:],
        counts: [String: Int] = [:]
    ) {
        #if DEBUG
        var resolvedFields = fields
        if let residentBytes = residentFootprintBytes() {
            resolvedFields["resident_mb"] = String(format: "%.1f", Double(residentBytes) / 1_048_576)
            resolvedFields["resident_human"] = makeByteFormatter().string(fromByteCount: Int64(residentBytes))
        }
        if let physFootprintBytes = physicalFootprintBytes() {
            resolvedFields["phys_footprint_mb"] = String(format: "%.1f", Double(physFootprintBytes) / 1_048_576)
            resolvedFields["phys_footprint_human"] = makeByteFormatter().string(fromByteCount: Int64(physFootprintBytes))
        }
        for key in counts.keys.sorted() {
            resolvedFields[key] = String(counts[key] ?? 0)
        }

        LoggingService.shared.log(
            level: .debug,
            component: component,
            event: event,
            message: message,
            fields: resolvedFields
        )
        #else
        _ = event
        _ = message
        _ = component
        _ = fields
        _ = counts
        #endif
    }

    #if DEBUG
    private static func residentFootprintBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    integerPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.resident_size)
    }

    private static func physicalFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    integerPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
    #endif
}

// MARK: - Global Convenience Functions

/// Executes logDebug.
public func logDebug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.debug(message, file: file, function: function, line: line)
}

/// Executes logDebug.
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

/// Executes logDebug.
public func logDebug(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(
        level: .debug,
        component: component,
        event: event,
        message: message,
        fields: fields,
        file: file,
        function: function,
        line: line
    )
}

/// Executes logInfo.
public func logInfo(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(
        level: .info,
        component: component,
        event: event,
        message: message,
        fields: fields,
        file: file,
        function: function,
        line: line
    )
}

/// Executes logInfo.
public func logInfo(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.info(message, file: file, function: function, line: line)
}

/// Executes logInfo.
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

/// Executes logWarning.
public func logWarning(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.warning(message, file: file, function: function, line: line)
}

/// Executes logWarning.
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

/// Executes logError.
public func logError(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.error(message, file: file, function: function, line: line)
}

/// Executes logError.
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

/// Executes logFatal.
public func logFatal(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.fatal(message, file: file, function: function, line: line)
}

/// Executes logFatal.
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

/// Executes logError.
public func logError(
    _ error: Error,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    LoggingService.shared.log(error: error, file: file, function: function, line: line)
}

/// Executes logWarning.
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

/// Executes logError.
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

/// Executes logFatal.
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
