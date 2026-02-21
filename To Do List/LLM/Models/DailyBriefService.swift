import Foundation

struct DailyBriefOutput {
    let brief: String
    let modelName: String?
    let routeBanner: String?
}

@MainActor
final class DailyBriefService {
    @MainActor static let shared = DailyBriefService(
        llm: LLMEvaluator(),
        appManager: AppManager()
    )

    private let defaults = UserDefaults.standard
    private let cachePrefix = "assistant.daily_brief."
    private let llm: LLMEvaluator
    private let appManager: AppManager

    /// Initializes a new instance.
    init(
        llm: LLMEvaluator,
        appManager: AppManager
    ) {
        self.llm = llm
        self.appManager = appManager
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
        streak: Int
    ) async -> DailyBriefOutput {
        let route = AIChatModeRouter.route(for: .dailyBrief, appManager: appManager)
        guard let modelName = route.selectedModelName else {
            return DailyBriefOutput(
                brief: fallbackBrief(
                    todayOpenCount: todayOpenCount,
                    overdueCount: overdueCount,
                    completedTodayCount: completedTodayCount,
                    streak: streak
                ),
                modelName: nil,
                routeBanner: route.bannerMessage
            )
        }

        let thread = Thread()
        thread.messages.append(
            Message(
                role: .user,
                content: """
                today_open: \(todayOpenCount)
                overdue: \(overdueCount)
                completed_today: \(completedTodayCount)
                streak_days: \(streak)
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
            {"brief":"4 short bullets with one clear next action"}
            """
        )
        if let brief = decodeBrief(from: output) {
            return DailyBriefOutput(brief: brief, modelName: modelName, routeBanner: route.bannerMessage)
        }

        return DailyBriefOutput(
            brief: fallbackBrief(
                todayOpenCount: todayOpenCount,
                overdueCount: overdueCount,
                completedTodayCount: completedTodayCount,
                streak: streak
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
        streak: Int
    ) -> String {
        fallbackBrief(
            todayOpenCount: todayOpenCount,
            overdueCount: overdueCount,
            completedTodayCount: completedTodayCount,
            streak: streak
        )
    }

    private struct BriefEnvelope: Decodable {
        let brief: String
    }

    /// Executes decodeBrief.
    private func decodeBrief(from raw: String) -> String? {
        let candidates = [
            raw.trimmingCharacters(in: .whitespacesAndNewlines),
            repairJSON(raw)
        ]
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let envelope = try? JSONDecoder().decode(BriefEnvelope.self, from: data) {
                let trimmed = envelope.brief.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
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
        streak: Int
    ) -> String {
        """
        Morning brief:
        • Today open: \(todayOpenCount)
        • Overdue: \(overdueCount)
        • Completed today: \(completedTodayCount)
        • Streak: \(streak) day(s)
        Next move: pick one high-impact task and start for 15 minutes.
        """
    }

    /// Executes cacheKey.
    private func cacheKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return cachePrefix + formatter.string(from: date)
    }
}
