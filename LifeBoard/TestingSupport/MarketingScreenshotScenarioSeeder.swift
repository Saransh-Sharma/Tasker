import CoreData
import Foundation
import UIKit

/// Test-only, deterministic planning evidence for public product captures.
///
/// This stage is deliberately separate from the older Home workspace seeder:
/// it owns typed planning records, stable identities, and fixed-clock placement
/// without changing production startup or persistence behavior.
@MainActor
enum MarketingScreenshotScenarioSeeder {
    static func seedPlanningStage(
        referenceDate: Date,
        plannedTaskIDs: [UUID]
    ) async throws {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let container = appDelegate.persistentContainer else {
            throw NSError(
                domain: "MarketingScreenshotScenario",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The test planning store is unavailable."]
            )
        }

        let repository = CoreDataPlanningRepository(container: container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let today = calendar.startOfDay(for: referenceDate)
        let planningDay = PlanningDay(date: today, timeZone: calendar.timeZone, calendar: calendar)
        let migrationState = try await HealthPrivacyMigrationCoordinator(container: container).migrate()
        guard migrationState == .validated || migrationState == .notNeeded else {
            throw NSError(
                domain: "MarketingScreenshotScenario",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The private wellness store was not ready for a deterministic capture."]
            )
        }

        let metadata = plannedTaskIDs.enumerated().map { index, taskID in
            PlanningTaskMetadata(
                taskID: taskID,
                planningDay: planningDay,
                commitmentLevel: index == 0 ? .mustDo : .standard,
                availability: .actionable,
                planningContext: .work,
                unscheduledDisposition: .inbox,
                pinOrder: index,
                updatedAt: referenceDate
            )
        }
        try await repository.saveTaskMetadata(metadata)

        let blocks = [
            InternalTimeBlock(
                id: UUID(uuidString: "A7000000-0000-0000-0000-000000000001") ?? UUID(),
                title: "Partner launch brief",
                startAt: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: today) ?? referenceDate,
                endAt: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today) ?? referenceDate,
                taskID: plannedTaskIDs.first,
                planningContext: .work,
                isFixed: false,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            InternalTimeBlock(
                id: UUID(uuidString: "A7000000-0000-0000-0000-000000000002") ?? UUID(),
                title: "Pricing decision pass",
                startAt: calendar.date(bySettingHour: 10, minute: 20, second: 0, of: today) ?? referenceDate,
                endAt: calendar.date(bySettingHour: 10, minute: 50, second: 0, of: today) ?? referenceDate,
                taskID: plannedTaskIDs.dropFirst().first,
                planningContext: .work,
                isFixed: false,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            InternalTimeBlock(
                id: UUID(uuidString: "A7000000-0000-0000-0000-000000000003") ?? UUID(),
                title: "Lunch and reset",
                startAt: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today) ?? referenceDate,
                endAt: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? referenceDate,
                planningContext: .personal,
                isFixed: true,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        ]
        for block in blocks {
            try await repository.saveTimeBlock(block)
        }

        if ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_MARKETING_ACTIVE_FOCUS") {
            _ = try await repository.start(
                taskID: plannedTaskIDs.first,
                timeBlockID: blocks.first?.id,
                targetDuration: 50 * 60,
                at: referenceDate.addingTimeInterval(-8 * 60)
            )
        }

        let trackRepository = CoreDataTrackFoundationRepository(container: container)
        try await trackRepository.saveHydrationTarget(
            HydrationTarget(
                id: UUID(uuidString: "A7100000-0000-0000-0000-000000000001") ?? UUID(),
                amount: 2_200,
                unit: .milliliters,
                updatedAt: referenceDate
            )
        )
        for (index, amount) in [350.0, 500.0, 420.0].enumerated() {
            let timestamp = calendar.date(
                bySettingHour: 8 + (index * 3),
                minute: index == 1 ? 20 : 5,
                second: 0,
                of: today
            ) ?? referenceDate
            try await trackRepository.saveHydrationLog(
                HydrationLog(
                    id: UUID(uuidString: "A7110000-0000-0000-0000-00000000000\(index + 1)") ?? UUID(),
                    amount: amount,
                    unit: .milliliters,
                    timestamp: timestamp,
                    note: index == 0 ? "After the morning walk" : nil,
                    capturedTimeZone: calendar.timeZone,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }

        let sleepDurations = [7.2, 7.6, 6.8, 7.9, 7.4, 6.9, 7.7]
        for (index, duration) in sleepDurations.enumerated() {
            guard let wakeDay = calendar.date(byAdding: .day, value: -index, to: today),
                  let wake = calendar.date(bySettingHour: 6, minute: 50, second: 0, of: wakeDay),
                  let bedtime = calendar.date(byAdding: .minute, value: -Int(duration * 60), to: wake) else {
                continue
            }
            try await trackRepository.saveSleepContextRecord(
                SleepContextRecord(
                    id: UUID(uuidString: String(format: "A7120000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                    bedtime: bedtime,
                    wakeTime: wake,
                    perceivedRest: index == 2 || index == 5 ? 3 : 4,
                    interruptionCount: index == 2 ? 2 : 1,
                    notes: index == 5 ? "Late dinner; kept the morning lighter." : nil,
                    createdAt: wake
                )
            )
        }

        try await seedGoalsAndRoutines(
            repository: trackRepository,
            referenceDate: referenceDate,
            today: today,
            calendar: calendar,
            plannedTaskIDs: plannedTaskIDs
        )
        try await seedWellness(container: container, referenceDate: referenceDate, today: today, calendar: calendar)
        try await seedNutrition(container: container, referenceDate: referenceDate, today: today, calendar: calendar)
        try await seedFastingJournalAndKnowledge(
            container: container,
            referenceDate: referenceDate,
            today: today,
            calendar: calendar
        )
        try await seedLifeMoments(container: container, referenceDate: referenceDate, today: today, calendar: calendar)
    }

    private static func seedGoalsAndRoutines(
        repository: CoreDataTrackFoundationRepository,
        referenceDate: Date,
        today: Date,
        calendar: Calendar,
        plannedTaskIDs: [UUID]
    ) async throws {
        let goalID = UUID(uuidString: "A7200000-0000-0000-0000-000000000001") ?? UUID()
        let goal = GoalDefinition(
            id: goalID,
            title: "Launch the partner experience calmly",
            type: .completion,
            targetValue: 4,
            unitLabel: "milestones",
            targetDate: calendar.date(byAdding: .day, value: 12, to: today),
            createdAt: calendar.date(byAdding: .day, value: -21, to: referenceDate) ?? referenceDate,
            updatedAt: referenceDate,
            intent: .outcome,
            status: .active,
            baselineValue: 0,
            confidenceRaw: "steady",
            whyItMatters: "Ship excellent work without borrowing from recovery.",
            checkInCadenceRaw: "weekly"
        )
        try await repository.saveGoal(goal)
        for (index, taskID) in plannedTaskIDs.prefix(3).enumerated() {
            try await repository.saveGoalLink(
                GoalLink(
                    id: UUID(uuidString: String(format: "A7210000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                    goalID: goalID,
                    source: .task,
                    sourceID: taskID,
                    createdAt: referenceDate
                )
            )
        }

        let routineID = UUID(uuidString: "A7220000-0000-0000-0000-000000000001") ?? UUID()
        let routine = RoutineDefinition(
            id: routineID,
            title: "Clear start",
            steps: [
                RoutineStep(
                    id: UUID(uuidString: "A7230000-0000-0000-0000-000000000001") ?? UUID(),
                    title: "Review today’s capacity",
                    kind: .instruction,
                    ordinal: 0,
                    duration: 120
                ),
                RoutineStep(
                    id: UUID(uuidString: "A7230000-0000-0000-0000-000000000002") ?? UUID(),
                    title: "Choose one launch outcome",
                    kind: .checkIn,
                    ordinal: 1,
                    duration: 180
                ),
                RoutineStep(
                    id: UUID(uuidString: "A7230000-0000-0000-0000-000000000003") ?? UUID(),
                    title: "Protect the first focus block",
                    kind: .timer,
                    ordinal: 2,
                    duration: 1_500
                )
            ],
            createdAt: calendar.date(byAdding: .day, value: -18, to: referenceDate) ?? referenceDate,
            updatedAt: referenceDate
        )
        try await repository.saveRoutine(routine)
        try await repository.saveRoutineSchedule(
            RoutineSchedule(
                id: UUID(uuidString: "A7240000-0000-0000-0000-000000000001") ?? UUID(),
                routineID: routineID,
                weekdays: Set(2...6),
                daypart: .morning,
                reminderTimeMinutes: 8 * 60 + 15,
                timeZoneIdentifier: calendar.timeZone.identifier,
                updatedAt: referenceDate
            )
        )
    }

    private static func seedWellness(
        container: NSPersistentContainer,
        referenceDate: Date,
        today: Date,
        calendar: Calendar
    ) async throws {
        let repository = CoreDataWellnessRepository(container: container)
        for index in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -index, to: today),
                  let observed = calendar.date(bySettingHour: 7, minute: 10, second: 0, of: day) else { continue }
            try await repository.save(
                BodyMetricSample(
                    id: UUID(uuidString: String(format: "A7300000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                    kind: .restingHeartRate,
                    value: [61, 60, 63, 62, 64, 61, 60][index],
                    unit: .beatsPerMinute,
                    observedAt: observed,
                    capturedTimeZone: calendar.timeZone,
                    source: index.isMultiple(of: 2) ? .watch : .healthKit,
                    sourceIdentifier: "apple-health-resting-heart-rate",
                    createdAt: observed,
                    updatedAt: observed
                )
            )
        }
        let walkStart = calendar.date(bySettingHour: 7, minute: 20, second: 0, of: today) ?? referenceDate
        try await repository.save(
            WorkoutRecord(
                id: UUID(uuidString: "A7310000-0000-0000-0000-000000000001") ?? UUID(),
                activityKind: "Outdoor walk",
                startedAt: walkStart,
                endedAt: walkStart.addingTimeInterval(2_220),
                energyKilocalories: 186,
                distanceMeters: 3_800,
                source: .watch,
                sourceIdentifier: "apple-health-workout",
                note: "Easy pace before the workday",
                createdAt: walkStart,
                updatedAt: walkStart.addingTimeInterval(2_220)
            )
        )
        try await repository.save(
            MovementContextRecord(
                id: UUID(uuidString: "A7320000-0000-0000-0000-000000000001") ?? UUID(),
                startedAt: today,
                endedAt: referenceDate,
                steps: 6_842,
                distanceMeters: 5_120,
                activeEnergyKilocalories: 324,
                source: .healthKit,
                sourceIdentifier: "apple-health-daily-activity",
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        )
    }

    private static func seedNutrition(
        container: NSPersistentContainer,
        referenceDate: Date,
        today: Date,
        calendar: Calendar
    ) async throws {
        let repository = CoreDataNutritionRepository(container: container)
        let dailyTarget = try NutritionMacros(
            calories: 2_150,
            proteinGrams: 120,
            carbohydrateGrams: 240,
            fatGrams: 72,
            fiberGrams: 30
        )
        try await repository.save(
            NutritionGoal(
                id: UUID(uuidString: "A7400000-0000-0000-0000-000000000001") ?? UUID(),
                targetMacros: dailyTarget,
                effectiveFrom: today,
                capturedTimeZone: calendar.timeZone,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        )

        let foods: [(String, NutritionMealSlot, Double, Double, Double, Double, Double, Int, String)] = [
            ("Greek yogurt, berries and almonds", .breakfast, 178, 140, 11, 14, 5, 8, "A balanced start before the launch review"),
            ("Roasted vegetable grain bowl", .lunch, 310, 132, 5, 21, 3.5, 13, "Lunch between decision blocks"),
            ("Apple with peanut butter", .snack, 150, 190, 7, 25, 8, 16, "Afternoon reset")
        ]
        for (index, item) in foods.enumerated() {
            let serving = try FoodServingDefinition(
                id: UUID(uuidString: String(format: "A7410000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                name: "serving",
                grams: item.2
            )
            let macros = try NutritionMacros(
                calories: item.3,
                proteinGrams: item.4,
                carbohydrateGrams: item.5,
                fatGrams: item.6,
                fiberGrams: Double(index + 4)
            )
            let food = try FoodItem(
                id: UUID(uuidString: String(format: "A7420000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                name: item.0,
                macrosPer100Grams: macros,
                servings: [serving],
                isFavorite: index == 0,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
            try await repository.save(food)
            let loggedAt = calendar.date(bySettingHour: item.7, minute: index == 1 ? 15 : 10, second: 0, of: today) ?? referenceDate
            try await repository.save(
                NutritionLogEntry(
                    id: UUID(uuidString: String(format: "A7430000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                    food: food,
                    mealSlot: item.1,
                    quantity: 1,
                    serving: serving,
                    loggedAt: loggedAt,
                    capturedTimeZone: calendar.timeZone,
                    note: item.8,
                    createdAt: loggedAt,
                    updatedAt: loggedAt
                )
            )
        }
    }

    private static func seedFastingJournalAndKnowledge(
        container: NSPersistentContainer,
        referenceDate: Date,
        today: Date,
        calendar: Calendar
    ) async throws {
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        try await repository.saveFastingSession(
            FastingSessionValue(
                id: UUID(uuidString: "A7500000-0000-0000-0000-000000000001") ?? UUID(),
                startedAt: referenceDate.addingTimeInterval(-9 * 3_600),
                targetDuration: 14 * 3_600,
                reminderOffsets: [12 * 3_600],
                note: "Gentle overnight window; stop whenever recovery needs change.",
                updatedAt: referenceDate
            )
        )
        try await repository.saveFastingSession(
            FastingSessionValue(
                id: UUID(uuidString: "A7500000-0000-0000-0000-000000000002") ?? UUID(),
                startedAt: referenceDate.addingTimeInterval(-33 * 3_600),
                endedAt: referenceDate.addingTimeInterval(-19 * 3_600),
                targetDuration: 14 * 3_600,
                note: "Felt steady; broke the fast before the morning walk.",
                completionKind: .planned,
                updatedAt: referenceDate.addingTimeInterval(-19 * 3_600)
            )
        )

        let dayID = UUID(uuidString: "A7510000-0000-0000-0000-000000000001") ?? UUID()
        let journalBlocks = [
            JournalBlockValue(
                id: UUID(uuidString: "A7520000-0000-0000-0000-000000000001") ?? UUID(),
                dayID: dayID,
                kind: .prompt,
                text: "What made today feel workable?",
                promptID: "daily-workable",
                createdAt: referenceDate.addingTimeInterval(-1_800),
                updatedAt: referenceDate.addingTimeInterval(-1_800),
                ordinal: 0
            ),
            JournalBlockValue(
                id: UUID(uuidString: "A7520000-0000-0000-0000-000000000002") ?? UUID(),
                dayID: dayID,
                kind: .text,
                text: "The pricing decision became clear once I protected a quiet block. I moved the reimbursement task instead of forcing it into an already full afternoon.",
                createdAt: referenceDate.addingTimeInterval(-1_700),
                updatedAt: referenceDate.addingTimeInterval(-1_700),
                ordinal: 1
            ),
            JournalBlockValue(
                id: UUID(uuidString: "A7520000-0000-0000-0000-000000000003") ?? UUID(),
                dayID: dayID,
                kind: .mood,
                mood: .calm,
                energy: 4,
                createdAt: referenceDate.addingTimeInterval(-1_600),
                updatedAt: referenceDate.addingTimeInterval(-1_600),
                ordinal: 2
            )
        ]
        try await repository.saveJournalDay(
            JournalDayValue(
                id: dayID,
                day: today,
                summary: "Clear decisions, protected energy, and a calmer handoff.",
                isStarred: true,
                createdAt: referenceDate.addingTimeInterval(-2_000),
                updatedAt: referenceDate,
                blocks: journalBlocks
            )
        )

        let spaceID = UUID(uuidString: "A7530000-0000-0000-0000-000000000001") ?? UUID()
        let folderID = UUID(uuidString: "A7540000-0000-0000-0000-000000000001") ?? UUID()
        try await repository.saveKnowledgeSpace(
            KnowledgeSpaceValue(id: spaceID, title: "Life library", icon: "books.vertical", createdAt: referenceDate, updatedAt: referenceDate)
        )
        try await repository.saveKnowledgeFolder(
            KnowledgeFolderValue(id: folderID, spaceID: spaceID, title: "Partner launch", ordinal: 0)
        )
        let notes: [(String, String)] = [
            ("Pricing decision notes", "Keep the choice legible: customer value, support cost, and the smallest reversible next step."),
            ("Launch handoff checklist", "Confirm owner, decision deadline, customer message, rollback trigger, and the next calm review point."),
            ("Course notes: humane systems", "Reliable systems make room for recovery; they do not require a perfect streak to stay useful.")
        ]
        for (index, note) in notes.enumerated() {
            let noteID = UUID(uuidString: String(format: "A7550000-0000-0000-0000-%012d", index + 1)) ?? UUID()
            try await repository.saveKnowledgeNote(
                KnowledgeNoteValue(
                    id: noteID,
                    spaceID: spaceID,
                    folderID: index < 2 ? folderID : nil,
                    title: note.0,
                    isPinned: index == 0,
                    isFavorite: index < 2,
                    createdAt: calendar.date(byAdding: .day, value: -(index + 2), to: referenceDate) ?? referenceDate,
                    updatedAt: referenceDate.addingTimeInterval(Double(-index * 600)),
                    blocks: [
                        KnowledgeBlockValue(
                            id: UUID(uuidString: String(format: "A7560000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                            noteID: noteID,
                            kind: .paragraph,
                            text: note.1,
                            ordinal: 0,
                            createdAt: referenceDate,
                            updatedAt: referenceDate
                        )
                    ],
                    lastOpenedAt: index == 0 ? referenceDate : nil
                )
            )
        }
    }

    private static func seedLifeMoments(
        container: NSPersistentContainer,
        referenceDate: Date,
        today: Date,
        calendar: Calendar
    ) async throws {
        let repository = CoreDataLifeMomentRepository(container: container)
        let moments: [(String, LifeMomentKind, Int, LifeMomentRecurrenceRule, String)] = [
            ("Weekend with Maya", .countdown, 9, .none, "Train booked; keep Saturday morning unplanned."),
            ("Parents’ anniversary", .anniversary, 24, .yearly, "Call together and send the photo book."),
            ("First gallery submission", .milestone, 46, .none, "Select twelve photographs and write the short series note.")
        ]
        for (index, moment) in moments.enumerated() {
            let eventDate = calendar.date(byAdding: .day, value: moment.2, to: today) ?? referenceDate
            try await repository.save(
                LifeMoment(
                    id: UUID(uuidString: String(format: "A7600000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                    title: moment.0,
                    kind: moment.1,
                    eventDate: eventDate,
                    recurrenceRule: moment.3,
                    capturedTimeZone: calendar.timeZone,
                    note: moment.4,
                    permitsHomeDisplay: index == 0,
                    createdAt: referenceDate,
                    updatedAt: referenceDate
                )
            )
        }
    }
}
