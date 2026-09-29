import SwiftUI

/// What Eva applied (and what was set aside), read back. Each row names the
/// prompt, the cards that landed, and whether Undo is still open. Reads the
/// store that `MessageView` writes; nothing here mutates.
struct EvaAppliedRunHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [EvaAppliedRunHistoryEntry] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    StatusSurface(
                        state: .noRecord,
                        title: String(localized: "Nothing applied yet"),
                        message: String(localized: "Changes you apply appear here.")
                    )
                    .padding(20)
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.summary.isEmpty ? entry.prompt : entry.summary)
                                .lifeboardFont(.body)
                                .lineLimit(3)
                            HStack(spacing: 8) {
                                Text(entry.appliedAt.formatted(date: .abbreviated, time: .shortened))
                                Text("·")
                                Text(statusText(for: entry))
                            }
                            .lifeboardFont(.meta)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            if entry.appliedCards.isEmpty == false {
                                Text(entry.appliedCards.map(\.title).joined(separator: ", "))
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("eva.history.\(entry.runID.uuidString)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Applied changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.keyboardShortcut(.cancelAction) }
            }
        }
        .accessibilityIdentifier("eva.history.sheet")
        .onAppear { entries = EvaAppliedRunHistoryStore.shared.entries() }
    }

    private func statusText(for entry: EvaAppliedRunHistoryEntry) -> String {
        if entry.status == "dismissed" { return String(localized: "Not applied") }
        let appliedCount = entry.appliedCards.count
        let skippedCount = entry.discardedCardCount
        let applied = skippedCount > 0
            ? String(localized: "\(appliedCount) applied, \(skippedCount) skipped")
            : String(localized: "\(appliedCount) applied")
        if entry.undoStatus == AssistantCardStatus.undoAvailable.rawValue, entry.undoExpiresAt > Date() {
            let until = entry.undoExpiresAt.formatted(date: .omitted, time: .shortened)
            return String(localized: "\(applied) · Undo until \(until)")
        }
        return String(localized: "\(applied) · Undo expired")
    }
}
