import Foundation
import MLXLMCommon

struct TaskBreakdownOutput {
    let steps: [String]
    let modelName: String?
    let routeBanner: String?
}

@MainActor
final class TaskBreakdownService {
    @MainActor static let shared = TaskBreakdownService()

    private let llm: LLMEvaluator

    var lastGenerationTimedOut: Bool {
        llm.lastGenerationTimedOut
    }

    /// Initializes a new instance.
    init(llm: LLMEvaluator? = nil) {
        self.llm = llm ?? LLMRuntimeCoordinator.shared.evaluator
    }

    /// Executes generateSteps.
    func generateSteps(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) async -> [String] {
        await generate(taskTitle: taskTitle, taskDetails: taskDetails, projectName: projectName).steps
    }

    /// Executes immediateHeuristicSteps.
    func immediateHeuristicSteps(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) -> TaskBreakdownOutput {
        let route = AIChatModeRouter.route(for: .breakdown)
        let fallback = heuristicBreakdown(
            taskTitle: taskTitle,
            taskDetails: taskDetails,
            projectName: projectName
        )
        return TaskBreakdownOutput(
            steps: enforceStepContract(candidate: fallback, fallback: fallback),
            modelName: nil,
            routeBanner: route.bannerMessage
        )
    }

    /// Executes generate.
    func generate(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) async -> TaskBreakdownOutput {
        await refine(
            taskTitle: taskTitle,
            taskDetails: taskDetails,
            projectName: projectName
        )
    }

    /// Executes refine.
    func refine(
        taskTitle: String,
        taskDetails: String?,
        projectName: String?
    ) async -> TaskBreakdownOutput {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            return TaskBreakdownOutput(steps: [], modelName: nil, routeBanner: nil)
        }

        let route = AIChatModeRouter.route(for: .breakdown)
        let fallbackSteps = heuristicBreakdown(
            taskTitle: trimmedTitle,
            taskDetails: taskDetails,
            projectName: projectName
        )

        guard let modelName = route.selectedModelName else {
            return TaskBreakdownOutput(
                steps: enforceStepContract(candidate: fallbackSteps, fallback: fallbackSteps),
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
            systemPrompt: breakdownSystemPrompt,
            profile: .breakdown,
            requestOptions: .structuredOutput(for: ModelConfiguration.getModelByName(modelName) ?? .defaultModel)
        )

        let parsed = decodeSteps(from: output) ?? []
        return TaskBreakdownOutput(
            steps: enforceStepContract(candidate: parsed, fallback: fallbackSteps),
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

    /// Executes enforceStepContract.
    private func enforceStepContract(candidate: [String], fallback: [String]) -> [String] {
        var merged = normalizeSteps(candidate)
        let fallbackNormalized = normalizeSteps(fallback)

        if merged.count < 3 {
            for step in fallbackNormalized where merged.count < 3 {
                if merged.contains(where: { $0.caseInsensitiveCompare(step) == .orderedSame }) == false {
                    merged.append(step)
                }
            }
        }

        if merged.count < 3 {
            let defaults = [
                "Define success criteria",
                "Gather inputs and constraints",
                "Draft and complete first pass"
            ]
            for step in defaults where merged.count < 3 {
                if merged.contains(where: { $0.caseInsensitiveCompare(step) == .orderedSame }) == false {
                    merged.append(step)
                }
            }
        }

        if merged.count > 6 {
            merged = Array(merged.prefix(6))
        }

        return merged
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
