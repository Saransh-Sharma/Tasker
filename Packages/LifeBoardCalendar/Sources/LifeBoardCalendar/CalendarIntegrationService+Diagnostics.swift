import Foundation

public final class CalendarDiagnosticsStore: @unchecked Sendable {
    public static let shared = CalendarDiagnosticsStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let storageKey = "calendar.diagnostics.recentEntries"
    private let maxStoredEntries = 20

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record(
        level: String,
        event: String,
        message: String,
        fields: [String: String]
    ) {
        let line = formattedLine(level: level, event: event, message: message, fields: fields)
        lock.lock()
        var entries = defaults.stringArray(forKey: storageKey) ?? []
        entries.append(line)
        if entries.count > maxStoredEntries {
            entries = Array(entries.suffix(maxStoredEntries))
        }
        defaults.set(entries, forKey: storageKey)
        lock.unlock()
    }

    public func recentEntriesText(limit: Int = 20) -> String {
        lock.lock()
        let entries = defaults.stringArray(forKey: storageKey) ?? []
        lock.unlock()

        let limitedEntries = entries.suffix(max(1, limit))
        guard limitedEntries.isEmpty == false else {
            return "No calendar diagnostics recorded yet."
        }
        return limitedEntries.joined(separator: "\n")
    }

    public func reset() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    private func formattedLine(
        level: String,
        event: String,
        message: String,
        fields: [String: String]
    ) -> String {
        var chunks = [
            "lvl=\(level)",
            "cmp=CalendarIntegration",
            "evt=\(event)",
            "msg=\"\(singleLine(message))\""
        ]
        for key in fields.keys.sorted() {
            guard key.isEmpty == false else { continue }
            chunks.append("\(key)=\(formattedValue(fields[key] ?? ""))")
        }
        return chunks.joined(separator: " ")
    }

    private func formattedValue(_ value: String) -> String {
        let singleLineValue = singleLine(value)
        guard singleLineValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              singleLineValue.contains("\"") == false else {
            return "\"\(singleLineValue.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return singleLineValue
    }

    private func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

public enum CalendarAccessDiagnostics {
    public static let eventKitDaemonErrorDomain = "EKCADErrorDomain"
    public static let eventKitDaemonXPCErrorCode = 1015
}
