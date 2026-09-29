import Foundation

struct LLMChatContextPartialFlags {
    let missingService: Bool
    let todayTimedOut: Bool
    let overdueTimedOut: Bool
    let upcomingTimedOut: Bool
    let habitsTimedOut: Bool

    var contextPartial: Bool {
        missingService || todayTimedOut || overdueTimedOut || upcomingTimedOut || habitsTimedOut
    }

    var partialReasons: [String] {
        var reasons: [String] = []
        if missingService { reasons.append("missing_service") }
        if todayTimedOut { reasons.append("today_timeout") }
        if overdueTimedOut { reasons.append("overdue_timeout") }
        if upcomingTimedOut { reasons.append("upcoming_timeout") }
        if habitsTimedOut { reasons.append("habits_timeout") }
        return reasons
    }

    func asDictionary() -> [String: Any] {
        [
            "missing_service": missingService,
            "today_timed_out": todayTimedOut,
            "overdue_timed_out": overdueTimedOut,
            "upcoming_timed_out": upcomingTimedOut,
            "habits_timed_out": habitsTimedOut,
            "context_partial": contextPartial
        ]
    }
}

struct LLMChatContextMetadata {
    let timezone: String
    let generatedAtISO: String
    let contextVersion: Int
    let contextPartial: Bool
    let partialReasons: [String]
    let injectionPolicy: String

    func asDictionary() -> [String: Any] {
        [
            "timezone": timezone,
            "generated_at_iso": generatedAtISO,
            "context_version": contextVersion,
            "context_partial": contextPartial,
            "partial_reasons": partialReasons,
            "injection_policy": injectionPolicy
        ]
    }
}

struct LLMChatContextEnvelope {
    let todayJSON: String
    let overdueJSON: String
    let upcomingJSON: String
    let habitsJSON: String
    let metadata: LLMChatContextMetadata
    let partialFlags: LLMChatContextPartialFlags

    func toJSONString() -> String {
        let payload: [String: Any] = [
            "today": Self.decodeJSONObject(from: todayJSON),
            "overdue": Self.decodeJSONObject(from: overdueJSON),
            "upcoming": Self.decodeJSONObject(from: upcomingJSON),
            "habits": Self.decodeJSONObject(from: habitsJSON),
            "metadata": metadata.asDictionary(),
            "partial_flags": partialFlags.asDictionary()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    var promptBlock: String {
        """
        Context JSON:
        \(toJSONString())
        """
    }

    /// Executes decodeJSONObject.
    private static func decodeJSONObject(from raw: String) -> Any {
        guard let data = raw.data(using: .utf8) else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) else { return [:] }
        if let dictionary = object as? [String: Any] {
            return dictionary
        }
        if let array = object as? [Any] {
            return array
        }
        return [:]
    }
}

struct LLMChatContextBuildResult {
    let payload: String
    let usedTimeoutFallback: Bool
    let envelope: LLMChatContextEnvelope
}

enum LLMChatContextEnvelopeBuilder {
    /// Executes build.
    static func build(
        timeoutMs: UInt64,
        service: LLMContextProjectionService?,
        injectionPolicy: String = "per_turn",
        budgets: LLMChatBudgets = .active,
        contextStrategy: LLMChatContextStrategy = V2FeatureFlags.llmChatContextStrategy
    ) async -> LLMChatContextBuildResult {
        guard let service else {
            let partialFlags = LLMChatContextPartialFlags(
                missingService: true,
                todayTimedOut: false,
                overdueTimedOut: false,
                upcomingTimedOut: false,
                habitsTimedOut: false
            )
            let metadata = LLMChatContextMetadata(
                timezone: TimeZone.current.identifier,
                generatedAtISO: Date().ISO8601Format(),
                contextVersion: 3,
                contextPartial: partialFlags.contextPartial,
                partialReasons: partialFlags.partialReasons,
                injectionPolicy: injectionPolicy
            )
            let envelope = LLMChatContextEnvelope(
                todayJSON: "{}",
                overdueJSON: "{}",
                upcomingJSON: "{}",
                habitsJSON: "{}",
                metadata: metadata,
                partialFlags: partialFlags
            )
            return LLMChatContextBuildResult(
                payload: envelope.promptBlock,
                usedTimeoutFallback: true,
                envelope: envelope
            )
        }

        let scopedService = service.withProjectionBudget(
            maxTasksPerSlice: budgets.maxProjectionTasksPerSlice,
            compactTaskPayload: contextStrategy == .bounded
        )

        let todayValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
            await scopedService.buildTodayJSON()
        }

        var overdueValue: (payload: String, timedOut: Bool) = ("{}", false)
        var upcomingValue: (payload: String, timedOut: Bool) = ("{}", false)
        var habitsValue: (payload: String, timedOut: Bool) = ("{}", false)

        if Task.isCancelled {
            overdueValue = ("{}", true)
            upcomingValue = ("{}", true)
            habitsValue = ("{}", true)
        } else if todayValue.timedOut {
            // Under pressure, avoid launching additional projection work this turn.
            overdueValue = ("{}", true)
            upcomingValue = ("{}", true)
            habitsValue = ("{}", true)
            logWarning(
                event: "chat_context_slice_short_circuit",
                message: "Skipped overdue/upcoming/habit context slices after today slice timeout",
                fields: ["slice": "today"]
            )
        } else {
            overdueValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
                await scopedService.buildOverdueJSON()
            }
            if Task.isCancelled {
                upcomingValue = ("{}", true)
            } else if overdueValue.timedOut {
                upcomingValue = ("{}", true)
                logWarning(
                    event: "chat_context_slice_short_circuit",
                    message: "Skipped upcoming context slice after overdue timeout",
                    fields: ["slice": "overdue"]
                )
            } else {
                upcomingValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
                    await scopedService.buildUpcomingJSON()
                }
            }
            if Task.isCancelled || overdueValue.timedOut || upcomingValue.timedOut {
                habitsValue = ("{}", true)
                logWarning(
                    event: "chat_context_slice_short_circuit",
                    message: "Skipped habits context slice after upstream slice timeout",
                    fields: ["slice": Task.isCancelled ? "cancelled" : (overdueValue.timedOut ? "overdue" : "upcoming")]
                )
            } else {
                habitsValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
                    await scopedService.buildHabitJSON()
                }
            }
        }

        let partialFlags = LLMChatContextPartialFlags(
            missingService: false,
            todayTimedOut: todayValue.timedOut,
            overdueTimedOut: overdueValue.timedOut,
            upcomingTimedOut: upcomingValue.timedOut,
            habitsTimedOut: habitsValue.timedOut
        )
        let metadata = LLMChatContextMetadata(
            timezone: TimeZone.current.identifier,
            generatedAtISO: Date().ISO8601Format(),
            contextVersion: 3,
            contextPartial: partialFlags.contextPartial,
            partialReasons: partialFlags.partialReasons,
            injectionPolicy: injectionPolicy
        )
        let envelope = LLMChatContextEnvelope(
            todayJSON: todayValue.payload,
            overdueJSON: overdueValue.payload,
            upcomingJSON: upcomingValue.payload,
            habitsJSON: habitsValue.payload,
            metadata: metadata,
            partialFlags: partialFlags
        )
        return LLMChatContextBuildResult(
            payload: envelope.promptBlock,
            usedTimeoutFallback: partialFlags.contextPartial,
            envelope: envelope
        )
    }
}
