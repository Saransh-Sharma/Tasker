import Foundation

/// Prompt payloads for the capture-field and top-three suggestion routes.
///
/// Extracted from `AISuggestionService` so the roster construction has room to
/// carry both a prompt-inlined and a context-carried form without pushing that
/// file past its size ratchet.
extension AISuggestionService {
    struct SuggestionPromptPayload {
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

    struct TopThreePromptPayload {
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

        var taskRows: String {
            tasks.map { task in
                let due = task.dueDate?.ISO8601Format() ?? "none"
                return """
                {"task_id":"\(task.id.uuidString)","title":"\(escape(task.title))","priority":"\(task.priority.evaWireName)","energy":"\(task.energy.rawValue)","due":"\(due)"}
                """
            }.joined(separator: "\n")
        }

        /// Executes escape.
        private func escape(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
    }
}
