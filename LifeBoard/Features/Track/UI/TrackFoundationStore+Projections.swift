import Foundation

extension TrackFoundationStore {
    static func projections(
        hydrationLogs: [HydrationLog],
        medicationEvents: [MedicationEventValue],
        checkIns: [MoodEnergyCheckInValue],
        sleepRecords: [SleepContextRecord],
        routines: [RoutineDefinition],
        routineRuns: [RoutineRun],
        goals: [GoalProgressSnapshot],
        habitGrades: [HabitGradeSnapshot],
        trackers: [TrackerDefinitionValue],
        trackerEntries: [TrackerEntryValue],
        journalDays: [JournalEvidenceSummary],
        correctionReceipts: [TrackCorrectionReceipt],
        now: Date
    ) -> (context: [TrackContextEnvelope], events: [NormalizedLifeEvent]) {
        let zone = TimeZone.current
        func day(_ date: Date) -> PlanningDay { PlanningDay(date: date, timeZone: zone) }
        let policy = EvidenceAuthorizationPolicy()
        let projector = NormalizedLifeEventProjector(policy: policy, timeZone: zone)
        var context: [TrackContextEnvelope] = []
        var events: [NormalizedLifeEvent] = []

        func makeEvent(
            id: String,
            sourceID: UUID,
            domain: String,
            kind: String,
            occurredAt: Date,
            numericValue: Double?,
            completeness: ProjectionCompleteness,
            sensitivity: DataSensitivity,
            provenance: String,
            evidence: [EvidenceReference],
            receipt: MutationReceiptReference? = nil,
            reversal: ReversalState = .notApplicable
        ) -> NormalizedLifeEvent {
            NormalizedLifeEvent(
                id: id, sourceID: sourceID, domain: domain, kind: kind,
                occurredAt: occurredAt, localDay: day(occurredAt), numericValue: numericValue,
                completeness: completeness, sensitivity: sensitivity,
                allowedDestinations: policy.allowedDestinations(domain: domain, sensitivity: sensitivity),
                provenance: provenance, evidence: evidence,
                freshness: policy.freshness(domain: domain, occurredAt: occurredAt, now: now),
                authorization: .authorized, redaction: .none,
                receipt: receipt, reversal: reversal
            )
        }

        func correctionMetadata(
            domain: TrackCorrectionDomain,
            sourceID: UUID
        ) -> (MutationReceiptReference?, ReversalState) {
            guard let receipt = correctionReceipts
                .filter({ $0.domain == domain && $0.sourceID == sourceID })
                .max(by: { lhs, rhs in lhs.appliedAt < rhs.appliedAt }) else {
                return (nil, .notApplicable)
            }
            return (receipt.reference, receipt.reversalState)
        }

        for log in hydrationLogs {
            let correction = correctionMetadata(domain: .hydration, sourceID: log.id)
            let destinations: Set<Destination> = [.home, .track, .insights]
            context.append(.init(
                id: "hydration:\(log.id.uuidString)", sourceID: log.id, sourceType: "hydration",
                timestamp: log.timestamp, localDay: day(log.timestamp), completeness: .complete,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: destinations, provenance: "Water log"
            ))
            events.append(projector.event(
                sourceID: log.id, domain: "hydration", kind: "recorded", occurredAt: log.timestamp,
                numericValue: HydrationMeasurementService.milliliters(log.amount, unit: log.unit),
                provenance: "Water log", evidenceDisplay: "Hydration log",
                receipt: correction.0, reversal: correction.1, now: now
            ))
        }
        for event in medicationEvents {
            let correction = correctionMetadata(domain: .medication, sourceID: event.id)
            context.append(.init(
                id: "medication:\(event.id.uuidString)", sourceID: event.id, sourceType: "medicationEvent",
                timestamp: event.scheduledAt, localDay: day(event.scheduledAt), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.home, .track], provenance: "Medication log"
            ))
            events.append(makeEvent(
                id: "medication:\(event.id.uuidString)", sourceID: event.id, domain: "medication",
                kind: event.status.rawValue, occurredAt: event.scheduledAt, numericValue: nil,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "Medication log",
                evidence: [EvidenceReference(sourceID: event.id, kind: "medication", display: "Medication event")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for checkIn in checkIns {
            let correction = correctionMetadata(domain: .mood, sourceID: checkIn.id)
            let timestamp = checkIn.createdAt
            context.append(.init(
                id: "mood:\(checkIn.id.uuidString)", sourceID: checkIn.id, sourceType: "moodEnergy",
                timestamp: timestamp, localDay: day(timestamp), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.track], provenance: "Mood & energy check-in"
            ))
            let moodValence = JournalMood.dialOrder.firstIndex(of: checkIn.mood).map { Double($0 - 4) }
            events.append(makeEvent(
                id: "mood:\(checkIn.id.uuidString)", sourceID: checkIn.id, domain: "mood",
                kind: checkIn.mood.rawValue, occurredAt: timestamp, numericValue: moodValence,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "Mood & energy check-in",
                evidence: [EvidenceReference(sourceID: checkIn.id, kind: "mood", display: "Mood & energy check-in")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for record in sleepRecords {
            let correction = correctionMetadata(domain: .sleep, sourceID: record.id)
            context.append(.init(
                id: "sleep:\(record.id.uuidString)", sourceID: record.id, sourceType: "sleepContext",
                timestamp: record.createdAt, localDay: day(record.createdAt), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.track], provenance: "Sleep you entered"
            ))
            events.append(makeEvent(
                id: "sleep:\(record.id.uuidString)", sourceID: record.id, domain: "sleep",
                kind: "context", occurredAt: record.createdAt, numericValue: nil,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "Sleep you entered",
                evidence: [EvidenceReference(sourceID: record.id, kind: "sleep", display: "Sleep context")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for routine in routines {
            context.append(.init(
                id: "routine:\(routine.id.uuidString)", sourceID: routine.id, sourceType: "dueRoutine",
                timestamp: now, localDay: day(now), completeness: .complete,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: [.home, .track, .plan], provenance: "Routine schedule"
            ))
            events.append(makeEvent(
                id: "routine:\(routine.id.uuidString)", sourceID: routine.id, domain: "routine",
                kind: "due", occurredAt: now, numericValue: nil,
                completeness: .complete, sensitivity: .privateStandard,
                provenance: "Routine schedule",
                evidence: [EvidenceReference(sourceID: routine.id, kind: "routine", display: routine.title)]
            ))
        }
        for run in routineRuns {
            events.append(projector.event(
                sourceID: run.id, domain: "routine", kind: run.status.rawValue,
                occurredAt: run.endedAt ?? run.updatedAt, provenance: "Routine",
                evidenceDisplay: run.versionSnapshot.title, evidenceRouteID: run.routineID, now: now
            ))
        }
        for grade in habitGrades {
            events.append(projector.event(
                sourceID: grade.habitID, domain: "habit", kind: "thirty_day_grade",
                occurredAt: grade.generatedAt, numericValue: grade.grade,
                completeness: grade.grade == nil ? .partial : .complete,
                provenance: "30-day habit history",
                evidenceDisplay: "Habit history", now: now
            ))
        }
        let trackerByID = Dictionary(uniqueKeysWithValues: trackers.map { ($0.id, $0) })
        for entry in trackerEntries {
            let definition = trackerByID[entry.trackerID]
            let correction = correctionMetadata(domain: .tracker, sourceID: entry.id)
            events.append(projector.event(
                sourceID: entry.id, domain: "tracker", kind: definition?.kind.rawValue ?? "entry",
                occurredAt: entry.timestamp,
                numericValue: entry.numericValue ?? entry.booleanValue.map { $0 ? 1 : 0 },
                provenance: "Tracker entry",
                evidenceDisplay: definition?.title ?? "Tracker entry", evidenceRouteID: entry.trackerID,
                receipt: correction.0, reversal: correction.1, now: now
            ))
        }
        for journal in journalDays {
            // The shared exclusion contract applies before a journal source
            // can become Eva evidence, even when this projection carries only
            // a display-safe identity and no journal text.
            guard journal.aiExclusion.permitsAssistantEvidence else { continue }
            events.append(projector.event(
                sourceID: journal.id, domain: "journal", kind: "day_updated",
                occurredAt: journal.updatedAt, sensitivity: .privateSensitive,
                provenance: "Journal",
                evidenceDisplay: "Journal entry", now: now
            ))
        }
        for goal in goals {
            let completeness: ProjectionCompleteness = goal.missingLinkCount == 0 ? .complete : .partial
            context.append(.init(
                id: "goal:\(goal.goalID.uuidString)", sourceID: goal.goalID, sourceType: "goalProgress",
                timestamp: now, localDay: day(now),
                completeness: completeness,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: [.home, .track, .insights], provenance: "Goal links"
            ))
            events.append(makeEvent(
                id: "goal:\(goal.goalID.uuidString)", sourceID: goal.goalID, domain: "goal",
                kind: "progress", occurredAt: now, numericValue: goal.progressFraction,
                completeness: completeness, sensitivity: .privateStandard,
                provenance: "Goal links",
                evidence: [EvidenceReference(sourceID: goal.goalID, kind: "goal", display: "Goal progress")]
            ))
        }
        return (context, events)
    }
}
