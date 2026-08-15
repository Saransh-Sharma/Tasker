//
//  UniversalInputSemanticAdapter.swift
//  LifeBoard
//
//  Semantic intent adapter for the universal input pipeline. Submitted input
//  uses the same Cloud EVA / Offline EVA provider seam as the rest of the app.
//  Live preview remains deterministic. The adapter produces only
//  allow-listed resolutions and never invoke repositories, save records,
//  or access protected journal content. Unparseable output yields `nil`
//  and the resolver terminal `.answer` becomes an EVA conversation.
//

import Foundation

/// Allow-list of intent labels that the semantic adapters are permitted
/// to emit. The model can never directly return arbitrary resolution
/// cases — every emitted label is mapped through this list, and any
/// unrecognised value yields `nil` (drops to the next adapter or to EVA).
public enum UniversalInputSemanticIntent: String, CaseIterable, Sendable {
    case captureTask
    case captureNote
    case captureJournal
    case startPlanning
    case weeklyPlanner
    case dayRescue
    case overdueRescue
    case showSchedule
    case clarify
    case conversation
}

/// Shared bounded semantic result. Cloud EVA and Offline EVA encode the same
/// fields so one downstream mapper handles either provider.
public struct UniversalInputSemanticResult: Sendable, Equatable {
    public let intent: UniversalInputSemanticIntent
    public let rawText: String?
    public let clarifyOptions: [String]
    public let confidence: Double
}

public struct UniversalInputSemanticAdapter: LifeThreadIntentAdapter {
    typealias Classifier = @Sendable (LifeThreadIntentInput) async -> UniversalInputSemanticResult?

    private let classifier: Classifier

    public init() {
        classifier = Self.classify
    }

    init(classifier: @escaping Classifier) {
        self.classifier = classifier
    }

    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        guard V2FeatureFlags.universalInputSemanticClassifierEnabled else { return nil }
        guard let result = await classifier(input) else { return nil }
        return map(result, input: input)
    }

    private static func classify(_ input: LifeThreadIntentInput) async -> UniversalInputSemanticResult? {
        await classifyWithEva(input)
    }

    @MainActor
    private static func classifyWithEva(_ input: LifeThreadIntentInput) async -> UniversalInputSemanticResult? {
        let route = AIChatModeRouter.route(for: .addTaskSuggestion)
        let cloudReady = EvaCloudAccountState.shared.canUseCloud(route: .universalInputClassification)
        let resolvedModelName: String
        if cloudReady {
            resolvedModelName = route.selectedModelName ?? "cloud-eva"
        } else {
            guard let requestedModelName = route.selectedModelName else { return nil }
            let readiness = await LLMRuntimeCoordinator.shared.ensureReady(modelName: requestedModelName)
            guard readiness.ready else { return nil }
            resolvedModelName = readiness.resolvedModelName
        }

        let prompt = """
        Classify this universal-input request:
        \(input.text)

        Context:
        activeRoot=\(input.destination)
        calendarAvailable=\(input.calendarAvailable)
        dayRescueEligible=\(input.dayRescueEligible)
        overdueRescueEligible=\(input.overdueRescueEligible)

        Return one JSON object only:
        {"intent":"captureTask|captureNote|captureJournal|startPlanning|weeklyPlanner|dayRescue|overdueRescue|showSchedule|clarify|conversation","rawText":"optional capture content","clarifyOptions":["0 to 3 short labels"],"confidence":0.0}
        Use only an allowed intent. Prefer conversation when no action is clearly requested.
        """
        let thread = Thread()
        let message = Message(role: .user, content: prompt, thread: thread)
        thread.messages = [message]
        let output = await LLMRuntimeCoordinator.shared.evaluator.generate(
            modelName: resolvedModelName,
            thread: thread,
            systemPrompt: "You are a private, on-device intent classifier. Output valid JSON only. Never invent personal context.",
            profile: .universalInputClassification
        )
        return decodeModelResult(output)
    }

    private struct MLXSemanticDTO: Decodable {
        let intent: String
        let rawText: String?
        let clarifyOptions: [String]?
        let confidence: Double
    }

    private static func decodeModelResult(_ output: String) -> UniversalInputSemanticResult? {
        let stripped = output
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if let first = stripped.firstIndex(of: "{"),
           let last = stripped.lastIndex(of: "}"),
           first <= last {
            candidate = String(stripped[first...last])
        } else {
            candidate = stripped
        }
        guard let data = candidate.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(MLXSemanticDTO.self, from: data),
              let intent = UniversalInputSemanticIntent(
                rawValue: decoded.intent.trimmingCharacters(in: .whitespacesAndNewlines)
              ) else {
            return nil
        }
        let raw = decoded.rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return UniversalInputSemanticResult(
            intent: intent,
            rawText: raw?.isEmpty == false ? raw : nil,
            clarifyOptions: decoded.clarifyOptions ?? [],
            confidence: min(max(decoded.confidence, 0), 1)
        )
    }

    private func map(_ result: UniversalInputSemanticResult, input: LifeThreadIntentInput) -> LifeThreadIntentResolution? {
        guard result.confidence >= 0.55 else { return nil }
        guard result.confidence < 0.78,
              result.intent != .clarify,
              result.intent != .conversation,
              let predicted = mapAllowListed(result, input: input) else {
            return mapAllowListed(result, input: input)
        }
        return .clarification(ClarificationRequest(
            question: "I think you want to \(confirmationLabel(for: result.intent)). Continue?",
            options: [
                ClarificationOption(
                    id: UUID(),
                    label: "Continue",
                    systemImage: confirmationImage(for: result.intent),
                    resolution: predicted
                ),
                ClarificationOption(
                    id: UUID(),
                    label: "Ask Eva",
                    systemImage: "bubble.left.and.bubble.right",
                    resolution: .answer(LifeThreadAnswerRequest(
                        prompt: input.text,
                        destination: input.destination
                    ))
                )
            ],
            originalText: input.text
        ))
    }

    private func mapAllowListed(
        _ result: UniversalInputSemanticResult,
        input: LifeThreadIntentInput
    ) -> LifeThreadIntentResolution? {
        switch result.intent {
        case .captureTask:
            let parsed = TaskCaptureParser.parse(input.text)
            let raw = result.rawText ?? input.text
            let seed = CaptureSeed(rawText: raw, parsedCapture: parsed, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .task, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        case .captureNote:
            let raw = result.rawText ?? input.text
            let seed = CaptureSeed(rawText: raw, parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .note, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        case .captureJournal:
            let raw = result.rawText ?? input.text
            let seed = CaptureSeed(rawText: raw, parsedCapture: nil, inputSource: input.inputSource)
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .journal, text: input.text,
                attachments: input.attachments, destination: input.destination, seed: seed
            ))
        case .startPlanning:
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .planDay, routeLabel: "Day Plan"
            ))
        case .weeklyPlanner:
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil,
                route: .weeklyPlanner, routeLabel: "Weekly Planner"
            ))
        case .dayRescue:
            return .surfaceAction(.dayRescue)
        case .overdueRescue:
            // Don't lead the user into the overdue deck if there's nothing
            // in it; surface it as a suggestion -> clarification instead.
            guard input.overdueRescueEligible else {
                return .clarification(ClarificationRequest(
                    question: "There are no overdue tasks. Want to plan today instead?",
                    options: [
                        ClarificationOption(
                            id: UUID(), label: "Plan today", systemImage: "calendar",
                            resolution: .navigation(LifeThreadNavigationRequest(
                                destination: .plan, sourceReference: nil,
                                route: .planDay, routeLabel: "Day Plan"
                            ))
                        ),
                        ClarificationOption(
                            id: UUID(), label: "Open Eva", systemImage: "bubble.left.and.bubble.right",
                            resolution: .answer(LifeThreadAnswerRequest(prompt: input.text, destination: input.destination))
                        )
                    ],
                    originalText: input.text
                ))
            }
            return .surfaceAction(.overdueRescue)
        case .showSchedule:
            return .surfaceAction(.showTodaySchedule)
        case .clarify:
            let optionLabels = result.clarifyOptions.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            let options: [ClarificationOption]
            if optionLabels.isEmpty {
                options = fallbackClarificationOptions(input: input)
            } else {
                options = optionLabels.map { label in
                    ClarificationOption(
                        id: UUID(),
                        label: label,
                        systemImage: clarificationImage(for: label),
                        resolution: clarificationResolution(for: label, input: input)
                    )
                }
            }
            guard options.isEmpty == false else { return nil }
            return .clarification(ClarificationRequest(
                question: "I want to make sure I understand. Which did you mean?",
                options: options,
                originalText: input.text
            ))
        case .conversation:
            return nil  // fall through to EVA via the resolver's terminal .answer
        }
    }

    private func confirmationLabel(for intent: UniversalInputSemanticIntent) -> String {
        switch intent {
        case .captureTask: return "create a task"
        case .captureNote: return "add a note"
        case .captureJournal: return "start a journal entry"
        case .startPlanning: return "plan today"
        case .weeklyPlanner: return "plan your week"
        case .dayRescue: return "rescue today"
        case .overdueRescue: return "review overdue tasks"
        case .showSchedule: return "check today’s meetings"
        case .clarify, .conversation: return "continue"
        }
    }

    private func confirmationImage(for intent: UniversalInputSemanticIntent) -> String {
        switch intent {
        case .captureTask: return "checkmark.circle"
        case .captureNote: return "note.text"
        case .captureJournal: return "book"
        case .startPlanning: return "calendar"
        case .weeklyPlanner: return "calendar.badge.clock"
        case .dayRescue: return "sun.max"
        case .overdueRescue: return "exclamationmark.arrow.triangle.2.circlepath"
        case .showSchedule: return "calendar.day.timeline.left"
        case .clarify, .conversation: return "questionmark.circle"
        }
    }

    private func fallbackClarificationOptions(input: LifeThreadIntentInput) -> [ClarificationOption] {
        [
            ClarificationOption(
                id: UUID(), label: "Note", systemImage: "note.text",
                resolution: .captureDraft(LifeThreadCaptureDraft(
                    id: UUID(), kind: .note, text: input.text,
                    attachments: input.attachments, destination: input.destination,
                    seed: CaptureSeed(rawText: input.text, parsedCapture: nil, inputSource: input.inputSource)
                ))
            ),
            ClarificationOption(
                id: UUID(), label: "Task", systemImage: "checkmark.circle",
                resolution: .captureDraft(LifeThreadCaptureDraft(
                    id: UUID(), kind: .task, text: input.text,
                    attachments: input.attachments, destination: input.destination,
                    seed: CaptureSeed(rawText: input.text, parsedCapture: TaskCaptureParser.parse(input.text), inputSource: input.inputSource)
                ))
            )
        ]
    }

    private func clarificationImage(for label: String) -> String {
        switch label.lowercased() {
        case "note": return "note.text"
        case "task": return "checkmark.circle"
        case "journal": return "book"
        case "plan", "plan today", "day plan": return "calendar"
        case "weekly", "weekly planner": return "calendar.badge.clock"
        case "eva", "ask eva", "open eva": return "bubble.left.and.bubble.right"
        default: return "questionmark.circle"
        }
    }

    private func clarificationResolution(for label: String, input: LifeThreadIntentInput) -> LifeThreadIntentResolution {
        switch label.lowercased() {
        case "note":
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .note, text: input.text,
                attachments: input.attachments, destination: input.destination,
                seed: CaptureSeed(rawText: input.text, parsedCapture: nil, inputSource: input.inputSource)
            ))
        case "task":
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .task, text: input.text,
                attachments: input.attachments, destination: input.destination,
                seed: CaptureSeed(rawText: input.text, parsedCapture: TaskCaptureParser.parse(input.text), inputSource: input.inputSource)
            ))
        case "journal":
            return .captureDraft(LifeThreadCaptureDraft(
                id: UUID(), kind: .journal, text: input.text,
                attachments: input.attachments, destination: input.destination,
                seed: CaptureSeed(rawText: input.text, parsedCapture: nil, inputSource: input.inputSource)
            ))
        case "plan", "plan today", "day plan":
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil, route: .planDay, routeLabel: "Day Plan"
            ))
        case "weekly", "weekly planner":
            return .navigation(LifeThreadNavigationRequest(
                destination: .plan, sourceReference: nil, route: .weeklyPlanner, routeLabel: "Weekly Planner"
            ))
        case "eva", "ask eva", "open eva":
            return .answer(LifeThreadAnswerRequest(prompt: input.text, destination: input.destination))
        default:
            return .answer(LifeThreadAnswerRequest(prompt: input.text, destination: input.destination))
        }
    }
}

/// Helper: race an async operation against a bounded delay. Yields `nil`
/// when the delay wins so callers can fall through to the next adapter.
private func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            try? await operation()
        }
        group.addTask {
            try? await Task.sleep(for: duration)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
