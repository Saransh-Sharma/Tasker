import SwiftUI

extension InboxView {
    /// The title as it would be filed: the parser strips the date phrase, so
    /// showing the raw text next to a date chip would misrepresent what filing
    /// this capture actually produces.
    func proposalTitle(for item: InboxItem) -> String {
        guard let parsed = store.proposal(for: item), parsed.cleanTitle.isEmpty == false else {
            return item.title
        }
        return parsed.cleanTitle
    }

    /// Shown, never applied.
    ///
    /// The parser rewrites the title and assigns a date; before this the drain
    /// committed both silently, so a capture could acquire a due date the user
    /// never saw. These chips are the review step that makes the proposal
    /// visible and disagreeable-with.
    func reviewChips(for parsed: ParsedCapture) -> some View {
        // Two rows rather than one: scheduling on top, classification beneath.
        // A single HStack of up to six chips truncates at accessibility text
        // sizes, and DESIGN.md's rule is to stack metadata before truncating
        // content that carries meaning.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let due = parsed.dueDate {
                    chip(
                        parsed.isAllDay
                            ? due.formatted(date: .abbreviated, time: .omitted)
                            : due.formatted(date: .abbreviated, time: .shortened),
                        symbol: "calendar"
                    )
                }
                if let duration = parsed.duration {
                    chip(Self.durationLabel(duration), symbol: "timer")
                }
                if parsed.repeatPattern != nil {
                    chip("Repeats", symbol: "arrow.triangle.2.circlepath")
                }
                if let priority = parsed.priority {
                    chip(priority.displayName, symbol: "flag")
                }
            }
            HStack(spacing: 8) {
                if let project = parsed.projectName {
                    chip(project, symbol: "folder")
                }
                if let context = parsed.context {
                    chip(context, symbol: "mappin.and.ellipse")
                }
                ForEach(parsed.tags, id: \.self) { tag in
                    chip(tag, symbol: "number")
                }
            }
            if let matched = parsed.matchedText {
                chip("from “\(matched)”", symbol: "text.magnifyingglass")
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.proposalAccessibilityLabel(parsed))
    }

    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    /// One sentence covering every proposal, ending in the fact that matters
    /// most: none of it has been applied yet.
    private static func proposalAccessibilityLabel(_ parsed: ParsedCapture) -> String {
        var parts: [String] = []
        if let due = parsed.dueDate {
            parts.append("date \(due.formatted(date: .abbreviated, time: parsed.isAllDay ? .omitted : .shortened))")
        }
        if let duration = parsed.duration { parts.append("duration \(durationLabel(duration))") }
        if parsed.repeatPattern != nil { parts.append("repeating") }
        if let priority = parsed.priority { parts.append("priority \(priority.displayName)") }
        if let project = parsed.projectName { parts.append("project \(project)") }
        if let context = parsed.context { parts.append("context \(context)") }
        if parsed.tags.isEmpty == false {
            parts.append("tags \(ListFormatter.localizedString(byJoining: parsed.tags))")
        }
        guard parts.isEmpty == false else { return "Nothing proposed" }
        return "Proposed \(ListFormatter.localizedString(byJoining: parts)). Not yet applied."
    }

    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.lifeboard.surfaceSecondary)
        )
    }
}
