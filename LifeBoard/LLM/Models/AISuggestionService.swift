import Foundation

struct TaskFieldSuggestion: Codable, Equatable {
    var priority: TaskPriority
    var energy: TaskEnergy
    var type: TaskType
    var context: TaskContext
    var rationale: String
    var confidence: Double
    var modelName: String?
    var routeBanner: String?
}

struct AITopTaskSuggestion: Codable, Equatable {
    var taskID: UUID
    var title: String
    var rationale: String
    var confidence: Double
    var modelName: String?
    var routeBanner: String?
}

@MainActor
final class AISuggestionService {
    typealias GenerateOutputHandler = @MainActor (String, Thread, String, LLMGenerationProfile, (@MainActor () -> Void)?) async -> String

    @MainActor static let shared = AISuggestionService()

    private let llm: LLMEvaluator
    private let generateOutput: GenerateOutputHandler

    var lastGenerationTimedOut: Bool {
        llm.lastGenerationTimedOut
    }

    /// Initializes a new instance.
    init(
        llm: LLMEvaluator? = nil,
        generateOutput: GenerateOutputHandler? = nil
    ) {
        let runtimeLLM = llm ?? LLMRuntimeCoordinator.shared.evaluator
        self.llm = runtimeLLM
        self.generateOutput = generateOutput ?? { modelName, thread, systemPrompt, profile, onFirstToken in
            await runtimeLLM.generate(
                modelName: modelName,
                thread: thread,
                systemPrompt: systemPrompt,
                profile: profile,
                onFirstToken: onFirstToken
            )
        }
    }

    /// Executes suggestFields.
    func suggestFields(
        for title: String,
        projectName: String,
        now: Date = Date()
    ) async -> TaskFieldSuggestion? {
        await refineFieldSuggestion(for: title, projectName: projectName, now: now)
    }

    /// Executes immediateFieldSuggestion.
    func immediateFieldSuggestion(
        for title: String,
        projectName: String,
        now: Date = Date()
    ) -> TaskFieldSuggestion? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 5 else { return nil }
        let route = AIChatModeRouter.route(for: .addTaskSuggestion)
        var suggestion = heuristicSuggestion(for: trimmed, projectName: projectName, now: now)
        suggestion.modelName = nil
        suggestion.routeBanner = route.bannerMessage
        return suggestion
    }

    /// Executes refineFieldSuggestion.
    func refineFieldSuggestion(
        for title: String,
        projectName: String,
        now: Date = Date()
    ) async -> TaskFieldSuggestion? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 5 else { return nil }

        let route = AIChatModeRouter.route(for: .addTaskSuggestion)
        var fallback = heuristicSuggestion(for: trimmed, projectName: projectName, now: now)
        fallback.modelName = nil
        fallback.routeBanner = route.bannerMessage

        guard let modelName = route.selectedModelName else {
            return fallback
        }

        let payload = SuggestionPromptPayload(
            title: trimmed,
            projectName: projectName,
            hour: Calendar.current.component(.hour, from: now),
            weekday: Calendar.current.component(.weekday, from: now)
        )
        let thread = Thread()
        thread.messages.append(Message(role: .user, content: payload.userPrompt, thread: thread))
        let output = await generateOutput(modelName, thread, payload.systemPrompt, .addTaskSuggestion, nil)

        if let parsed = decodeSuggestion(from: output) {
            return TaskFieldSuggestion(
                priority: parsed.priority,
                energy: parsed.energy,
                type: parsed.type,
                context: parsed.context,
                rationale: parsed.rationale,
                confidence: parsed.confidence,
                modelName: modelName,
                routeBanner: route.bannerMessage
            )
        }

        fallback.modelName = modelName
        return fallback
    }

    /// Executes immediateTopThree.
    func immediateTopThree(from tasks: [TaskDefinition]) -> [AITopTaskSuggestion] {
        guard tasks.isEmpty == false else { return [] }
        let openTasks = tasks.filter { !$0.isComplete }
        guard openTasks.isEmpty == false else { return [] }

        let route = AIChatModeRouter.route(for: .topThree)
        return heuristicTopThree(
            from: openTasks,
            modelName: nil,
            routeBanner: route.bannerMessage
        )
    }

    /// Executes chooseTopThree.
    func chooseTopThree(from tasks: [TaskDefinition]) async -> [AITopTaskSuggestion] {
        await refineTopThree(from: tasks)
    }

    /// Executes refineTopThree.
    func refineTopThree(from tasks: [TaskDefinition]) async -> [AITopTaskSuggestion] {
        guard tasks.isEmpty == false else { return [] }
        let openTasks = tasks.filter { !$0.isComplete }
        guard openTasks.isEmpty == false else { return [] }

        let route = AIChatModeRouter.route(for: .topThree)
        let fallback = heuristicTopThree(
            from: openTasks,
            modelName: nil,
            routeBanner: route.bannerMessage
        )

        guard let modelName = route.selectedModelName else {
            return fallback
        }

        let promptPayload = TopThreePromptPayload(tasks: Array(openTasks.prefix(40)))
        let thread = Thread()
        thread.messages.append(Message(role: .user, content: promptPayload.userPrompt, thread: thread))
        let output = await generateOutput(modelName, thread, promptPayload.systemPrompt, .topThree, nil)

        if let parsed = decodeTopThree(from: output, validIDs: Set(openTasks.map(\.id))) {
            let lookup = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0.title) })
            var suggestions = parsed.prefix(3).compactMap { item -> AITopTaskSuggestion? in
                guard let title = lookup[item.taskID] else { return nil }
                return AITopTaskSuggestion(
                    taskID: item.taskID,
                    title: title,
                    rationale: item.rationale,
                    confidence: item.confidence,
                    modelName: modelName,
                    routeBanner: route.bannerMessage
                )
            }
            if suggestions.count < 3 {
                let existing = Set(suggestions.map(\.taskID))
                let fill = heuristicTopThree(
                    from: openTasks.filter { !existing.contains($0.id) },
                    modelName: modelName,
                    routeBanner: route.bannerMessage
                )
                suggestions.append(contentsOf: fill.prefix(3 - suggestions.count))
            }
            return Array(suggestions.prefix(3))
        }

        return heuristicTopThree(
            from: openTasks,
            modelName: modelName,
            routeBanner: route.bannerMessage
        )
    }

    /// Executes refineDynamicChips.
    func refineDynamicChips(
        baseChips: [String],
        openTaskCount: Int,
        overdueCount: Int,
        now: Date = Date()
    ) async -> [String] {
        let fallback = normalizeDynamicChips(baseChips)
        guard fallback.isEmpty == false else { return [] }

        let route = AIChatModeRouter.route(for: .dynamicChips)
        guard let modelName = route.selectedModelName else {
            return fallback
        }

        let systemPrompt = """
        You generate short starter prompts for a task assistant empty state.
        Return ONLY JSON with this schema:
        {"chips":["string"]}
        Rules:
        - 3 to 6 chips
        - each chip under 60 characters
        - action-oriented and user-voiced
        - no markdown and no numbering
        """

        let base = fallback.map { "\"\(escape($0))\"" }.joined(separator: ",")
        let userPrompt = """
        open_task_count: \(openTaskCount)
        overdue_count: \(overdueCount)
        weekday: \(Calendar.current.component(.weekday, from: now))
        base_chips: [\(base)]
        """

        let thread = Thread()
        thread.messages.append(Message(role: .user, content: userPrompt, thread: thread))
        let output = await generateOutput(modelName, thread, systemPrompt, .dynamicChips, nil)

        guard let decoded = decodeDynamicChips(from: output), decoded.isEmpty == false else {
            return fallback
        }
        return decoded
    }

    private struct SuggestionPromptPayload {
        let title: String
        let projectName: String
        let hour: Int
        let weekday: Int

        var systemPrompt: String {
            """
            You classify productivity task-capture fields.
            Return ONLY JSON, no markdown and no prose.
            Schema:
            {"priority":"none|low|high|max","energy":"low|medium|high","type":"morning|evening|upcoming","context":"anywhere|home|office|computer|phone|errands|outdoor|gym|commute|meeting","rationale":"max 8 words","confidence":0.0}
            """
        }

        var userPrompt: String {
            """
            title: "\(title)"
            project: "\(projectName)"
            hour: \(hour)
            weekday: \(weekday)
            """
        }
    }

    private struct SuggestionLLMResponse: Decodable {
        let priority: String
        let energy: String
        let type: String
        let context: String
        let rationale: String
        let confidence: Double
    }

    private struct TopThreePromptPayload {
        let tasks: [TaskDefinition]

        var systemPrompt: String {
            """
            You rank the top 3 tasks for focus.
            Return ONLY JSON, no markdown and no prose.
            Schema:
            {"items":[{"task_id":"UUID","rationale":"max 12 words","confidence":0.0}]}
            Rules:
            - Select 1 to 3 task_ids from provided tasks only.
            - Prefer overdue or near-due work, then high priority.
            """
        }

        var userPrompt: String {
            let lines = tasks.map { task in
                let due = task.dueDate?.ISO8601Format() ?? "none"
                return """
                {"task_id":"\(task.id.uuidString)","title":"\(escape(task.title))","priority":"\(task.priority.rawValue)","energy":"\(task.energy.rawValue)","due":"\(due)"}
                """
            }.joined(separator: "\n")

            return "tasks:\n\(lines)"
        }

        /// Executes escape.
        private func escape(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
    }

    private struct TopThreeLLMEnvelope: Decodable {
        let items: [TopThreeLLMItem]
    }

    private struct TopThreeLLMItem: Decodable {
        let taskID: UUID
        let rationale: String
        let confidence: Double

        enum CodingKeys: String, CodingKey {
            case taskID = "task_id"
            case rationale
            case confidence
        }
    }

    private struct DynamicChipsEnvelope: Decodable {
        let chips: [String]
    }

    /// Executes decodeSuggestion.
    private func decodeSuggestion(from raw: String) -> TaskFieldSuggestion? {
        for data in jsonDataCandidates(from: raw) {
            guard let data else { continue }
            guard let decoded = try? JSONDecoder().decode(SuggestionLLMResponse.self, from: data) else { continue }
            guard let priority = parseTaskPriority(decoded.priority) else { continue }
            guard let energy = TaskEnergy(rawValue: decoded.energy.lowercased()) else { continue }
            guard let type = parseTaskType(decoded.type) else { continue }
            guard let context = TaskContext(rawValue: decoded.context.lowercased()) else { continue }

            let trimmedRationale = decoded.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
            return TaskFieldSuggestion(
                priority: priority,
                energy: energy,
                type: type,
                context: context,
                rationale: trimmedRationale.isEmpty ? "task pattern detected" : trimmedRationale,
                confidence: clamp(decoded.confidence, min: 0.0, max: 1.0),
                modelName: nil,
                routeBanner: nil
            )
        }
        return nil
    }

    /// Executes decodeTopThree.
    private func decodeTopThree(
        from raw: String,
        validIDs: Set<UUID>
    ) -> [TopThreeLLMItem]? {
        for data in jsonDataCandidates(from: raw) {
            guard let data else { continue }
            guard let envelope = try? JSONDecoder().decode(TopThreeLLMEnvelope.self, from: data) else { continue }
            let filtered = envelope.items.filter { validIDs.contains($0.taskID) }
            if filtered.isEmpty == false {
                return filtered.map {
                    TopThreeLLMItem(
                        taskID: $0.taskID,
                        rationale: $0.rationale.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: clamp($0.confidence, min: 0.0, max: 1.0)
                    )
                }
            }
        }
        return nil
    }

    /// Executes decodeDynamicChips.
    private func decodeDynamicChips(from raw: String) -> [String]? {
        for data in jsonDataCandidates(from: raw) {
            guard let data else { continue }
            if let envelope = try? JSONDecoder().decode(DynamicChipsEnvelope.self, from: data) {
                return normalizeDynamicChips(envelope.chips)
            }
        }
        return nil
    }

    /// Executes jsonDataCandidates.
    private func jsonDataCandidates(from raw: String) -> [Data?] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let repaired = repairJSONWrapper(trimmed)
        return [trimmed.data(using: .utf8), repaired.data(using: .utf8)]
    }

    /// Executes repairJSONWrapper.
    private func repairJSONWrapper(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBrace = stripped.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let lastBrace = stripped.lastIndex(where: { $0 == "}" || $0 == "]" }),
           firstBrace <= lastBrace {
            return String(stripped[firstBrace...lastBrace])
        }
        return stripped
    }

    /// Executes normalizeDynamicChips.
    private func normalizeDynamicChips(_ chips: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for raw in chips {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            normalized.append(trimmed)
            if normalized.count == 6 { break }
        }
        return normalized
    }

    /// Executes parseTaskType.
    private func parseTaskType(_ value: String) -> TaskType? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "morning": return .morning
        case "evening": return .evening
        case "upcoming": return .upcoming
        case "inbox": return .inbox
        default: return nil
        }
    }

    /// Executes parseTaskPriority.
    private func parseTaskPriority(_ value: String) -> TaskPriority? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "none", "p0": return TaskPriority.none
        case "low", "p1": return .low
        case "high", "p2": return .high
        case "max", "maximum", "p3": return .max
        default: return nil
        }
    }

    /// Executes clamp.
    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }

    /// Executes heuristicSuggestion.
    private func heuristicSuggestion(
        for title: String,
        projectName: String,
        now: Date
    ) -> TaskFieldSuggestion {
        let lower = title.lowercased()
        let urgentKeywords = ["urgent", "asap", "today", "deadline", "important", "now"]
        let phoneKeywords = ["call", "text", "sms", "phone"]
        let computerKeywords = ["email", "report", "review", "docs", "document", "spreadsheet", "code", "pr"]
        let errandsKeywords = ["buy", "pickup", "drop off", "grocery", "store", "pharmacy"]
        let highEnergyKeywords = ["plan", "design", "write", "analyze", "strategy", "draft", "brainstorm"]

        let isUrgent = urgentKeywords.contains { lower.contains($0) }
        let isPhone = phoneKeywords.contains { lower.contains($0) }
        let isComputer = computerKeywords.contains { lower.contains($0) }
        let isErrand = errandsKeywords.contains { lower.contains($0) }
        let isHighEnergy = highEnergyKeywords.contains { lower.contains($0) }

        let hour = Calendar.current.component(.hour, from: now)
        let priority: TaskPriority = isUrgent ? .high : .low
        let energy: TaskEnergy = isHighEnergy ? .high : (isUrgent ? .medium : .low)
        let type: TaskType = (hour < 13) ? .morning : .evening
        let context: TaskContext = {
            if isPhone { return .phone }
            if isComputer { return .computer }
            if isErrand { return .errands }
            if projectName.lowercased().contains("home") { return .home }
            return .anywhere
        }()

        return TaskFieldSuggestion(
            priority: priority,
            energy: energy,
            type: type,
            context: context,
            rationale: buildRationale(
                isUrgent: isUrgent,
                isPhone: isPhone,
                isComputer: isComputer,
                isErrand: isErrand
            ),
            confidence: isUrgent || isPhone || isComputer || isErrand ? 0.78 : 0.62,
            modelName: nil,
            routeBanner: nil
        )
    }

    /// Executes heuristicTopThree.
    private func heuristicTopThree(
        from tasks: [TaskDefinition],
        modelName: String?,
        routeBanner: String?
    ) -> [AITopTaskSuggestion] {
        let now = Date()
        let calendar = Calendar.current
        let ranked = tasks
            .map { task -> (TaskDefinition, Double) in
                var score = Double(task.priority.scorePoints)
                if let dueDate = task.dueDate {
                    if calendar.isDateInToday(dueDate) {
                        score += 3.0
                    } else if dueDate < now {
                        score += 4.0
                    } else if dueDate.timeIntervalSince(now) < 48 * 3_600 {
                        score += 2.0
                    }
                }
                if task.energy == .low { score += 0.3 }
                if task.energy == .high { score += 0.8 }
                return (task, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.updatedAt > rhs.0.updatedAt }
                return lhs.1 > rhs.1
            }

        return ranked.prefix(3).enumerated().map { index, pair in
            let (task, score) = pair
            return AITopTaskSuggestion(
                taskID: task.id,
                title: task.title,
                rationale: topTaskRationale(task: task),
                confidence: min(0.95, max(0.55, score / 10.0)),
                modelName: modelName,
                routeBanner: index == 0 ? routeBanner : nil
            )
        }
    }

    /// Executes buildRationale.
    private func buildRationale(
        isUrgent: Bool,
        isPhone: Bool,
        isComputer: Bool,
        isErrand: Bool
    ) -> String {
        if isUrgent { return "deadline language detected" }
        if isPhone { return "communication verb detected" }
        if isComputer { return "computer-work terms detected" }
        if isErrand { return "out-of-home cue detected" }
        return "general capture pattern"
    }

    /// Executes topTaskRationale.
    private func topTaskRationale(task: TaskDefinition) -> String {
        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(dueDate) { return "due today and high impact" }
            if dueDate < Date() { return "overdue and should be recovered" }
        }
        if task.priority == .high {
            return "high priority first"
        }
        return "good momentum candidate"
    }

    /// Executes escape.
    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
