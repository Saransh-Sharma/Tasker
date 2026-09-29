import Foundation

extension LoggingService {
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

    static func pruneExpiredLogs(in directory: URL, now: Date) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = now.addingTimeInterval(-logRetentionInterval)
        for file in files where file.pathExtension == "log" {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoff else { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}
