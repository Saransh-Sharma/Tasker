//
//  UniversalInputAdapters.swift
//  LifeBoard
//
//  Created by System on 31/07/26.
//

import Foundation

/// Adapter for resolving explicit command intents.
public struct CommandIntentAdapter: LifeThreadIntentAdapter {
    
    public init() {}
    
    private struct CommandDefinition: Sendable {
        let patterns: [String]
        let resolution: @Sendable (LifeThreadIntentInput, String) -> LifeThreadIntentResolution?
    }
    
    private let definitions: [CommandDefinition] = [
        CommandDefinition(patterns: ["start journaling about", "journal about"]) { input, matchText in
            let trailing = Self.extractTrailingContent(fullText: input.text, prefix: matchText)
            let seed = CaptureSeed(rawText: trailing, parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .journal, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        },
        CommandDefinition(patterns: ["start journaling", "open journal", "journal", "/journal"]) { input, _ in
            // An empty seed opens the native Journal text writer immediately
            // without putting the trigger phrase into the entry.
            let seed = CaptureSeed(rawText: "", parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .journal, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        },
        CommandDefinition(patterns: ["i want to journal about", "write about", "thinking about"]) { input, matchText in
            let trailing = Self.extractTrailingContent(fullText: input.text, prefix: matchText)
            let seed = CaptureSeed(rawText: trailing, parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .journal, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        },
        CommandDefinition(patterns: ["add a note:", "add a note", "new note", "add note", "note:", "add note:", "/note", "note to self"]) { input, matchText in
            // Extract trailing content so the editor pre-fills "launch ideas"
            // rather than the trigger phrase "add a note: launch ideas".
            let trailing = Self.extractTrailingContent(
                fullText: input.text, prefix: matchText
            )
            let seed = CaptureSeed(rawText: trailing, parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .note, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        },
        CommandDefinition(patterns: [
            "check my meetings", "check meetings", "check my calendar",
            "today's schedule", "todays schedule", "show calendar",
            "show my schedule", "my meetings", "what's next", "whats next"
        ]) { _, _ in
            return .surfaceAction(.showTodaySchedule)
        },
        CommandDefinition(patterns: ["start planning", "plan my day", "day plan", "start the day", "/today", "/plan"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .planDay, routeLabel: String(localized: "Day plan")
            ))
        },
        CommandDefinition(patterns: ["weekly plan", "plan my week", "weekly planner", "plan my week", "/week"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .weeklyPlanner, routeLabel: String(localized: "Plan week")
            ))
        },
        CommandDefinition(patterns: ["day rescue", "rescue my day", "rescue the day"]) { _, _ in
            return .surfaceAction(.dayRescue)
        },
        CommandDefinition(patterns: ["overdue rescue", "clear overdue", "overdue tasks", "show overdue", "/overdue"]) { _, _ in
            return .surfaceAction(.overdueRescue)
        },
        CommandDefinition(patterns: ["weekly review", "review my week"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .weeklyReview, routeLabel: String(localized: "Review week")
            ))
        },
        CommandDefinition(patterns: ["backlog", "show backlog", "open backlog"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .backlog, routeLabel: String(localized: "Backlog")
            ))
        }
    ]
    
    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        let lowercasedText = input.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        for definition in definitions {
            for pattern in definition.patterns {
                let lowercasedPattern = pattern.lowercased()
                
                if lowercasedText.hasPrefix(lowercasedPattern) {
                    if lowercasedText == lowercasedPattern || lowercasedText.hasPrefix(lowercasedPattern + " ") || lowercasedPattern.hasSuffix(":") {
                        return definition.resolution(input, pattern)
                    }
                }
            }
        }
        
        return nil
    }
    
    public static func extractTrailingContent(fullText: String, prefix: String) -> String {
        let lowercasedFull = fullText.lowercased()
        let lowercasedPrefix = prefix.lowercased()

        guard let range = lowercasedFull.range(of: lowercasedPrefix) else {
            return fullText
        }

        var trailing = fullText[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        // Pattern prefixes like "add a note:" or "note:" usually carry a
        // colon following the trigger. Strip it so the editor prefills the
        // user's actual content, not the leftover colon.
        if trailing.hasPrefix(":") || trailing.hasPrefix("–") || trailing.hasPrefix("-") {
            trailing = String(trailing.dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trailing
    }
}

/// Decides when composer text is a task, and when a task is certain enough to
/// save without opening the editor.
///
/// A task used to need a leading verb ("buy", "call"…), so "Dentist fri 3pm"
/// fell through to Eva. Now any text carrying a recognized token — a date,
/// time, duration, `+project`, `#tag`, `@place`, repeat, or priority — is a
/// task, unless it reads as a question or as journal/note language.
public enum QuickCaptureSavePolicy {
    private static let questionOpeners: Set<String> = [
        "what", "what's", "whats", "how", "how's", "why", "when", "when's", "where", "who",
        "which", "should", "can", "could", "would", "is", "are", "am", "do", "does", "did",
        "will", "help", "show", "tell", "explain", "summarize", "summarise", "find", "list"
    ]

    /// Openers that belong to reflection or notes, not to a to-do.
    private static let proseOpeners: [String] = [
        "i ", "i'm ", "im ", "i've ", "ive ", "i was ", "my ", "today was ", "yesterday ",
        "i want to journal", "write about", "thinking about", "note about", "note to self",
        "add note", "make a note", "note for", "journal"
    ]

    public static func hasStructure(_ parsed: ParsedCapture?) -> Bool {
        guard let parsed else { return false }
        return parsed.dueDate != nil
            || parsed.duration != nil
            || parsed.projectName != nil
            || parsed.tags.isEmpty == false
            || parsed.context != nil
            || parsed.repeatPattern != nil
            || parsed.priority != nil
    }

    public static func looksLikeQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasSuffix("?") { return true }
        let firstWord = trimmed.split(whereSeparator: { $0.isWhitespace || $0 == "," }).first.map(String.init) ?? ""
        return questionOpeners.contains(firstWord)
    }

    public static func looksLikeProse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return proseOpeners.contains(where: { trimmed.hasPrefix($0) })
    }

    /// A few words with no verb, no structure, and no question ("Dentist",
    /// "milk"). It could be a task or something to ask the assistant, so the
    /// composer asks instead of guessing. It used to fall through to a chat
    /// and switch tabs, which lost the capture.
    public static func isPlainPhrase(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.count <= 60 else { return false }
        guard looksLikeQuestion(trimmed) == false, looksLikeProse(trimmed) == false else { return false }
        return trimmed.split(whereSeparator: \.isWhitespace).count <= 4
    }

    /// Structure without a verb is enough to call it a task.
    public static func isTaskShapedWithoutMarker(_ text: String, parsed: ParsedCapture) -> Bool {
        hasStructure(parsed)
            && parsed.cleanTitle.isEmpty == false
            && looksLikeQuestion(text) == false
            && looksLikeProse(text) == false
    }

    /// Saves on Send with a receipt and Undo instead of opening the editor.
    /// Dictation always reviews in the editor: a misheard date is easy to miss.
    public static func canSaveInPlace(_ seed: CaptureSeed?) -> Bool {
        guard let seed, seed.inputSource == .typed, let parsed = seed.parsedCapture else { return false }
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false, title.count <= 200 else { return false }
        guard looksLikeQuestion(seed.rawText) == false, looksLikeProse(seed.rawText) == false else { return false }
        return hasStructure(parsed) || TaskCaptureIntentAdapter.hasExplicitMarker(seed.rawText)
    }

    /// Receipt copy: says what was added and where it landed, in the person's terms.
    public static func receiptMessage(
        title: String,
        scheduledStartAt: Date?,
        dueDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let name = "“\(title)”"
        if let start = scheduledStartAt {
            let time = start.formatted(date: .omitted, time: .shortened)
            return "Added \(name) · \(dayPhrase(for: start, now: now, calendar: calendar)) \(time)"
        }
        if let day = dueDate {
            return "Added \(name) · \(dayPhrase(for: day, now: now, calendar: calendar))"
        }
        return "Added \(name) to Inbox"
    }

    private static func dayPhrase(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

/// Adapter for resolving task capture intents using TaskCaptureParser.
public struct TaskCaptureIntentAdapter: LifeThreadIntentAdapter {

    public init() {}

    /// Prefixes that flag an ambiguous note-vs-task prefix that the
    /// `CaptureLanguageIntentAdapter` should resolve into a clarification.
    /// Returning `nil` here lets the ambiguity adapter present two
    /// concrete action choices instead of eagerly producing a task.
    private static let ambiguityPrefixes: [String] = [
        "make a note for tomorrow",
        "note for next week",
        "make a note for next week",
        "note for tomorrow"
    ]

    /// Imperative task markers. The verb must be followed by at least one
    /// non-trigger word — bare "send" or "schedule" with no content does
    /// not classify as a task and falls through so the next adapter meets
    /// the full phrase.
    static func hasExplicitMarker(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let markers = [
            "remind me", "add task", "todo", "remember to", "don't forget",
            "dont forget", "need to",
            "buy", "call", "email", "send", "pick up", "schedule", "book",
            "finish", "submit", "review", "prepare", "pay", "renew", "return",
            "follow up", "complete", "create", "update", "fix",
            "add to inbox", "task:"
        ]
        for marker in markers {
            guard trimmed.hasPrefix(marker) else { continue }
            // Require following content; a bare marker alone ("send",
            // "schedule") is no longer classified as a task.
            let trailing = trimmed.dropFirst(marker.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trailing.isEmpty == false {
                return true
            }
        }
        return false
    }

    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        let lowercasedText = input.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lowercasedText.isEmpty == false else { return nil }

        // Let ambiguous phrases fall through so the capture-language adapter
        // can offer a concrete note-versus-task clarification.
        for prefix in Self.ambiguityPrefixes where lowercasedText.hasPrefix(prefix) {
            return nil
        }

        let parsed = TaskCaptureParser.parse(input.text)
        guard Self.hasExplicitMarker(lowercasedText)
            || QuickCaptureSavePolicy.isTaskShapedWithoutMarker(input.text, parsed: parsed) else { return nil }
        let seed = CaptureSeed(rawText: input.text, parsedCapture: parsed, inputSource: input.inputSource)
        return .captureDraft(LifeThreadCaptureDraft(
            id: UUID(), kind: .task, text: input.text,
            attachments: input.attachments, destination: input.destination, seed: seed
        ))
    }
}

/// Adapter for resolving specific capture language patterns for notes and journals.
public struct CaptureLanguageIntentAdapter: LifeThreadIntentAdapter {
    
    public init() {}
    
    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        let lowercasedText = input.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check for ambiguous note/task intents. These are the prefixes that
        // naturally read either way ("make a note for tomorrow" could mean
        // "remind me about this tomorrow" or "save this text"). The
        // `TaskCaptureIntentAdapter` yields `nil` for these inputs so this
        // adapter is the one that sees them.
        let ambiguityPrefixes = [
            "make a note for tomorrow",
            "make a note for next week",
            "note for next week",
            "note for tomorrow"
        ]
        if ambiguityPrefixes.contains(where: { lowercasedText.hasPrefix($0) }) {
            let noteOption = ClarificationOption(
                id: UUID(),
                label: "Note",
                systemImage: "note.text",
                resolution: .captureDraft(LifeThreadCaptureDraft(
                    id: UUID(), kind: .note, text: input.text,
                    attachments: input.attachments, destination: input.destination,
                    seed: CaptureSeed(
                        rawText: input.text,
                        parsedCapture: nil,
                        inputSource: input.inputSource
                    )
                ))
            )
            let parsed = TaskCaptureParser.parse(input.text)
            let taskOption = ClarificationOption(
                id: UUID(),
                label: "Task",
                systemImage: "checkmark.circle",
                resolution: .captureDraft(LifeThreadCaptureDraft(
                    id: UUID(), kind: .task, text: input.text,
                    attachments: input.attachments, destination: input.destination,
                    seed: CaptureSeed(rawText: input.text, parsedCapture: parsed, inputSource: input.inputSource)
                ))
            )
            return .clarification(ClarificationRequest(
                question: String(localized: "Note or task?"),
                options: [noteOption, taskOption],
                originalText: input.text
            ))
        }
        
        // Journal prefixes
        let journalPrefixes = ["i want to journal about", "write about", "thinking about"]
        for prefix in journalPrefixes {
            if lowercasedText.hasPrefix(prefix) {
                let trailing = extractTrailingContent(fullText: input.text, prefix: prefix)
                let seed = CaptureSeed(rawText: trailing, parsedCapture: nil, inputSource: input.inputSource)
                return .captureDraft(LifeThreadCaptureDraft(id: UUID(), kind: .journal, text: input.text, attachments: input.attachments, destination: input.destination, seed: seed))
            }
        }
        
        // Note prefixes
        let notePrefixes = ["note about", "add note:", "note to self"]
        for prefix in notePrefixes {
            if lowercasedText.hasPrefix(prefix) {
                let trailing = extractTrailingContent(fullText: input.text, prefix: prefix)
                let seed = CaptureSeed(rawText: trailing, parsedCapture: nil, inputSource: input.inputSource)
                return .captureDraft(LifeThreadCaptureDraft(id: UUID(), kind: .note, text: input.text, attachments: input.attachments, destination: input.destination, seed: seed))
            }
        }
        
        return nil
    }
    
    private func extractTrailingContent(fullText: String, prefix: String) -> String {
        let lowercasedFull = fullText.lowercased()
        let lowercasedPrefix = prefix.lowercased()
        
        guard let range = lowercasedFull.range(of: lowercasedPrefix) else {
            return fullText
        }
        
        var trailing = fullText[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if trailing.hasPrefix(":") {
            trailing = String(trailing.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trailing
    }
}
