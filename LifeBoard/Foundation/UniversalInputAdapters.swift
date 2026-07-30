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
                route: .planDay, routeLabel: "Day Plan"
            ))
        },
        CommandDefinition(patterns: ["weekly plan", "plan my week", "weekly planner", "plan my week", "/week"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .weeklyPlanner, routeLabel: "Weekly Planner"
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
                route: .weeklyReview, routeLabel: "Weekly Review"
            ))
        },
        CommandDefinition(patterns: ["backlog", "show backlog", "open backlog"]) { _, _ in
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .backlog, routeLabel: "Backlog"
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
    private static func hasExplicitMarker(_ text: String) -> Bool {
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

        guard Self.hasExplicitMarker(lowercasedText) else { return nil }
        let parsed = TaskCaptureParser.parse(input.text)
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
                question: "Did you mean to create a note or schedule a task?",
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
