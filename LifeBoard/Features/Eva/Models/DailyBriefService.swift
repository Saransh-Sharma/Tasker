import Foundation
import MLXLMCommon

struct DailyBriefOutput {
    struct Tradeoff: Equatable {
        let drop: String
        let because: String
    }

    let brief: String
    let modelName: String?
    let routeBanner: String?
    let fixedCommitments: [String]
    let nextMove: String?
    let tradeoff: Tradeoff?
    let evidenceTaskIDs: [UUID]
    /// Advisory model output. Capacity-aware surfaces must use their local
    /// `CapacityBudget` as the source of truth.
    let modelSaysOvercommitted: Bool?

    init(
        brief: String,
        modelName: String?,
        routeBanner: String?,
        fixedCommitments: [String] = [],
        nextMove: String? = nil,
        tradeoff: Tradeoff? = nil,
        evidenceTaskIDs: [UUID] = [],
        modelSaysOvercommitted: Bool? = nil
    ) {
        self.brief = brief
        self.modelName = modelName
        self.routeBanner = routeBanner
        self.fixedCommitments = fixedCommitments
        self.nextMove = nextMove
        self.tradeoff = tradeoff
        self.evidenceTaskIDs = evidenceTaskIDs
        self.modelSaysOvercommitted = modelSaysOvercommitted
    }
}

@MainActor
final class DailyBriefService {
    @MainActor static let shared = DailyBriefService()

    private let defaults = UserDefaults.standard
    private let cachePrefix = "assistant.daily_brief."
    private let llm: LLMEvaluator
    private let dateProvider: () -> Date

    /// Initializes a new instance.
    init(
        llm: LLMEvaluator? = nil,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.llm = llm ?? LLMRuntimeCoordinator.shared.evaluator
        self.dateProvider = dateProvider
    }

    /// Executes cachedBrief.
    func cachedBrief(for date: Date = Date()) -> String? {
        defaults.string(forKey: cacheKey(for: date))
    }

    /// Executes saveBrief.
    func saveBrief(_ brief: String, for date: Date = Date()) {
        defaults.set(brief, forKey: cacheKey(for: date))
    }

    /// Executes generateBriefOutput.
    func generateBriefOutput(
        todayOpenCount: Int,
        overdueCount: Int,
        completedTodayCount: Int,
        streak: Int,
        habitSignals: [LifeBoardHabitSignal] = []
    ) async -> DailyBriefOutput {
        let resolvedHabitSignals = await resolveHabitSignals(suppliedSignals: habitSignals)
        let route = AIChatModeRouter.route(for: .dailyBrief)
        guard let modelName = EvaModelSelection.resolve(route.selectedModelName) else {
            return DailyBriefOutput(
                brief: fallbackBrief(
                    todayOpenCount: todayOpenCount,
                    overdueCount: overdueCount,
                    completedTodayCount: completedTodayCount,
                    streak: streak,
                    habitSignals: resolvedHabitSignals
                ),
                modelName: nil,
                routeBanner: route.bannerMessage
            )
        }

        // The counts alone cannot support a brief worth reading: they say five
        // things are due without saying which, so the answer can only ever be
        // generic encouragement. On cloud the roster travels as typed context and
        // the model can name the actual work; offline keeps the counts, which is
        // what a 0.6B model can handle.
        let cloudContext = await EvaTurnContextAssembler.sections(
            budget: EvaContextBudget.resolveForChat(route: .dailyBrief, currentModelName: modelName, offlineModel: .defaultModel),
            compactProjection: "",
            executiveState: nil,
            slashCommandState: nil,
            personalMemory: nil,
            habitSignals: resolvedHabitSignals,
            evidence: .notProvided,
            consent: EvaCloudAccountState.shared.consent,
            route: .dailyBrief
        )
        let thread = Thread()
        thread.messages.append(
            Message(
                role: .user,
                content: """
                today_open: \(todayOpenCount)
                overdue: \(overdueCount)
                completed_today: \(completedTodayCount)
                streak_days: \(streak)
                \(habitPromptLines(from: resolvedHabitSignals))
                """,
                thread: thread
            )
        )
        let output = await llm.generate(
            modelName: modelName,
            thread: thread,
            systemPrompt: """
            You write concise morning planning briefs.
            Return ONLY JSON, no markdown and no prose.
            Schema:
            {"brief":"4 short bullets with one clear next action","fixedCommitments":["read-only commitment"],"nextMove":"one action","tradeoff":{"drop":"work to move","because":"capacity fact"},"evidenceTaskIDs":["uuid"],"isOvercommitted":false}
            Omit optional fields when the supplied context cannot support them.
            """,
            profile: .dailyBrief,
            requestOptions: .structuredOutput(for: ModelConfiguration.getModelByName(modelName) ?? .defaultModel),
            cloudContext: cloudContext
        )
        if let structured = decodeStructuredOutput(
            from: output,
            modelName: modelName,
            routeBanner: route.bannerMessage
        ) {
            return structured
        }

        return DailyBriefOutput(
            brief: fallbackBrief(
                todayOpenCount: todayOpenCount,
                overdueCount: overdueCount,
                completedTodayCount: completedTodayCount,
                streak: streak,
                habitSignals: resolvedHabitSignals
            ),
            modelName: modelName,
            routeBanner: route.bannerMessage
        )
    }

    /// Executes generateBrief.
    func generateBrief(
        todayOpenCount: Int,
        overdueCount: Int,
        completedTodayCount: Int,
        streak: Int,
        habitSignals: [LifeBoardHabitSignal] = []
    ) async -> String {
        fallbackBrief(
            todayOpenCount: todayOpenCount,
            overdueCount: overdueCount,
            completedTodayCount: completedTodayCount,
            streak: streak,
            habitSignals: await resolveHabitSignals(suppliedSignals: habitSignals)
        )
    }

    private func resolveHabitSignals(suppliedSignals: [LifeBoardHabitSignal]) async -> [LifeBoardHabitSignal] {
        guard suppliedSignals.isEmpty, let repository = LLMContextRepositoryFactory.habitRuntimeReadRepository else {
            return suppliedSignals
        }
        let calendar = Calendar.current
        let referenceDate = dateProvider()
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        return await withCheckedContinuation { continuation in
            repository.fetchSignals(start: startOfDay, end: endOfDay) { result in
                let summaries = (try? result.get()) ?? []
                continuation.resume(
                    returning: summaries.map { LifeBoardHabitSignal(summary: $0, referenceDate: referenceDate) }
                )
            }
        }
    }

    /// The v2 brief carries its structure rather than one paragraph.
    ///
    /// Every field beyond `brief` is optional so an offline model, which only
    /// ever produced the single string, still decodes. The extra fields exist so
    /// the product can show the tradeoff as a tradeoff and trace a claim back to
    /// the record it rests on, instead of rendering prose and hoping.
    private struct BriefEnvelope: Decodable {
        struct Tradeoff: Decodable {
            let drop: String
            let because: String
        }

        let brief: String
        let fixedCommitments: [String]?
        let nextMove: String?
        let tradeoff: Tradeoff?
        let evidenceTaskIDs: [UUID]?
        let isOvercommitted: Bool?
    }

    /// Decodes the structured daily-brief contract into the client model used
    /// by capacity-aware surfaces. Kept internal so contract tests can pin every
    /// field without constructing a model-provider session.
    func decodeStructuredOutput(
        from raw: String,
        modelName: String? = nil,
        routeBanner: String? = nil
    ) -> DailyBriefOutput? {
        guard let envelope = decodeBrief(from: raw) else { return nil }
        return DailyBriefOutput(
            brief: envelope.brief,
            modelName: modelName,
            routeBanner: routeBanner,
            fixedCommitments: envelope.fixedCommitments ?? [],
            nextMove: envelope.nextMove.flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            },
            tradeoff: envelope.tradeoff.map {
                DailyBriefOutput.Tradeoff(drop: $0.drop, because: $0.because)
            },
            evidenceTaskIDs: envelope.evidenceTaskIDs ?? [],
            modelSaysOvercommitted: envelope.isOvercommitted
        )
    }

    /// Executes decodeBrief.
    private func decodeBrief(from raw: String) -> BriefEnvelope? {
        let candidates = [
            raw.trimmingCharacters(in: .whitespacesAndNewlines),
            repairJSON(raw)
        ]
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let envelope = try? JSONDecoder().decode(BriefEnvelope.self, from: data) {
                let trimmed = envelope.brief.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return BriefEnvelope(
                        brief: trimmed,
                        fixedCommitments: envelope.fixedCommitments,
                        nextMove: envelope.nextMove,
                        tradeoff: envelope.tradeoff,
                        evidenceTaskIDs: envelope.evidenceTaskIDs,
                        isOvercommitted: envelope.isOvercommitted
                    )
                }
            }
        }
        return nil
    }

    /// Executes repairJSON.
    private func repairJSON(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = stripped.firstIndex(of: "{"),
           let last = stripped.lastIndex(of: "}"),
           first <= last {
            return String(stripped[first...last])
        }
        return stripped
    }

    /// Executes fallbackBrief.
    private func fallbackBrief(
        todayOpenCount: Int,
        overdueCount: Int,
        completedTodayCount: Int,
        streak: Int,
        habitSignals: [LifeBoardHabitSignal] = []
    ) -> String {
        let habitSummary = habitSummaryLines(from: habitSignals)
        return """
        Morning brief:
        • Today open: \(todayOpenCount)
        • Overdue: \(overdueCount)
        • Completed today: \(completedTodayCount)
        • Streak: \(streak) day(s)
        \(habitSummary)
        Next move: pick one high-impact task and start for 15 minutes.
        """
    }

    private func habitPromptLines(from habitSignals: [LifeBoardHabitSignal]) -> String {
        guard habitSignals.isEmpty == false else { return "" }

        let summary = summarizeHabits(habitSignals)
        return """
        habit_due: \(summary.dueHabits)
        habit_success: \(summary.successes)
        habit_lapse: \(summary.lapses)
        habit_risk: \(summary.atRisk)
        """
    }

    private func habitSummaryLines(from habitSignals: [LifeBoardHabitSignal]) -> String {
        guard habitSignals.isEmpty == false else { return "" }

        let summary = summarizeHabits(habitSignals)
        return """
        • Habits due: \(summary.dueHabits)
        • Habit wins: \(summary.successes)
        • Habit lapses: \(summary.lapses)
        • Habit risk: \(summary.atRisk)
        """
    }

    private func summarizeHabits(_ habitSignals: [LifeBoardHabitSignal]) -> HabitBriefSummary {
        let dueSignals = habitSignals.filter { $0.isDueToday || $0.isOverdue || $0.outcomeRaw != nil }
        let successes = dueSignals.filter { signal in
            guard let outcome = signal.outcomeRaw?.lowercased() else { return false }
            return ["completed", "abstained", "success", "successful"].contains(outcome)
        }.count
        let lapses = dueSignals.filter { signal in
            guard let outcome = signal.outcomeRaw?.lowercased() else { return false }
            return ["lapsed", "lapse"].contains(outcome)
        }.count
        let atRisk = habitSignals.filter { signal in
            signal.isOverdue || (signal.riskStateRaw?.lowercased().contains("risk") ?? false)
        }.count
        return HabitBriefSummary(dueHabits: dueSignals.count, successes: successes, lapses: lapses, atRisk: atRisk)
    }

    private struct HabitBriefSummary {
        let dueHabits: Int
        let successes: Int
        let lapses: Int
        let atRisk: Int
    }

    /// Executes cacheKey.
    private func cacheKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return cachePrefix + formatter.string(from: date)
    }
}
