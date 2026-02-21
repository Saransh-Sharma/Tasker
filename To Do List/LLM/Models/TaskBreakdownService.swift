import Foundation

struct TaskBreakdownOutput {
    let steps: [String]
    let modelName: String?
    let routeBanner: String?
}

@MainActor
final class TaskBreakdownService {
    @MainActor static let shared = TaskBreakdownService(
        llm: LLMEvaluator(),
        appManager: AppManager()
    )
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

    /// Executes generateSteps.
    func generateSteps(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) async -> [String] {
        await generate(taskTitle: taskTitle, taskDetails: taskDetails, projectName: projectName).steps
    }

    /// Executes generate.
    func generate(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) async -> TaskBreakdownOutput {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            return TaskBreakdownOutput(steps: [], modelName: nil, routeBanner: nil)
        }

        let route = AIChatModeRouter.route(for: .breakdown, appManager: appManager)
        guard let modelName = route.selectedModelName else {
            return TaskBreakdownOutput(
                steps: heuristicBreakdown(
                    taskTitle: trimmedTitle,
                    taskDetails: taskDetails,
                    projectName: projectName
                ),
                modelName: nil,
                routeBanner: route.bannerMessage
            )
        }

        let thread = Thread()
        thread.messages.append(
            Message(
                role: .user,
                content: breakdownUserPrompt(
                    taskTitle: trimmedTitle,
                    taskDetails: taskDetails,
                    projectName: projectName
                ),
                thread: thread
            )
        )
        let output = await llm.generate(
            modelName: modelName,
            thread: thread,
            systemPrompt: breakdownSystemPrompt
        )
        if let steps = decodeSteps(from: output), steps.isEmpty == false {
            return TaskBreakdownOutput(
                steps: steps,
                modelName: modelName,
                routeBanner: route.bannerMessage
            )
        }

        return TaskBreakdownOutput(
            steps: heuristicBreakdown(
                taskTitle: trimmedTitle,
                taskDetails: taskDetails,
                projectName: projectName
            ),
            modelName: modelName,
            routeBanner: route.bannerMessage
        )
    }

    private var breakdownSystemPrompt: String {
        """
        You break one task into actionable subtasks.
        Return ONLY a JSON array of strings, no markdown and no prose.
        Rules:
        - return 3 to 6 steps
        - each step should be actionable and under 2 hours
        - keep each step under 80 characters
        """
    }

    /// Executes breakdownUserPrompt.
    private func breakdownUserPrompt(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) -> String {
        """
        task_title: "\(taskTitle)"
        task_details: "\(taskDetails?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"
        project_name: "\(projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"
        """
    }

    /// Executes decodeSteps.
    private func decodeSteps(from raw: String) -> [String]? {
        let candidates = [
            raw.trimmingCharacters(in: .whitespacesAndNewlines),
            repairJSON(raw)
        ]
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            guard let parsed = try? JSONDecoder().decode([String].self, from: data) else { continue }
            let normalized = normalizeSteps(parsed)
            if normalized.isEmpty == false {
                return normalized
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
        if let first = stripped.firstIndex(of: "["),
           let last = stripped.lastIndex(of: "]"),
           first <= last {
            return String(stripped[first...last])
        }
        return stripped
    }

    /// Executes normalizeSteps.
    private func normalizeSteps(_ input: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for raw in input {
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.isEmpty == false else { continue }
            let dedupeKey = normalized.lowercased()
            guard seen.insert(dedupeKey).inserted else { continue }
            output.append(normalized)
            if output.count == 6 {
                break
            }
        }
        return output
    }

    /// Executes heuristicBreakdown.
    private func heuristicBreakdown(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) -> [String] {
        var steps: [String] = []
        if let details = taskDetails?.trimmingCharacters(in: .whitespacesAndNewlines), details.isEmpty == false {
            let sentences = details
                .split(separator: ".")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            steps.append(contentsOf: sentences.prefix(3).map { "Handle: \($0)" })
        }

        if steps.isEmpty {
            let prefix = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let project = (prefix?.isEmpty == false) ? " for \(prefix!)" : ""
            steps = [
                "Define success criteria\(project)",
                "Gather required inputs and references",
                "Draft the first pass",
                "Review and finalize deliverable"
            ]
        }

        return Array(normalizeSteps(steps).prefix(6))
    }
}
