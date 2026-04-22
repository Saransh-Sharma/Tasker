//
//  To_Do_ListTests.swift
//  To Do ListTests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest
import Combine
import CoreData
import UserNotifications
import MLXLMCommon
@testable import To_Do_List

final class AppDelegateCloudKitPreflightTests: XCTestCase {

    func testCloudKitMirroringModeDisablesForXCTestConfigurationRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "xctest_runtime"))
    }

    func testCloudKitMirroringModeDisablesForInjectedTestHostRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: ["XCInjectBundleInto": "/tmp/This Day.app/This Day"],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "xctest_runtime"))
    }

    func testCloudKitMirroringModeDisablesForSimulatorRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: [],
                isSimulator: true
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "simulator_runtime"))
    }

#if DEBUG
    func testCloudKitMirroringModeDisablesForLaunchArgumentOverride() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: ["-TASKER_DISABLE_CLOUDKIT"],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "launch_arg_disable_cloudkit"))
    }
#endif

    func testCloudKitMirroringModeEnablesForSupportedRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .enabled)
    }
}

final class HomeSectionStateRegressionTests: XCTestCase {
    func testFocusNowSectionStateClampsNegativeMaxVisibleCount() {
        let state = FocusNowSectionState(
            rows: [.task(TaskDefinition(title: "Pinned candidate"))],
            pinnedTaskIDs: [],
            maxVisibleCount: -1
        )

        XCTAssertEqual(state.maxVisibleCount, 0)
        XCTAssertEqual(state.rows, [])
        XCTAssertEqual(state.visibleCount, 0)
    }

    func testRescueTailStateUsesAllRowsForPreview() {
        let state = RescueTailState(
            rows: [
                .task(TaskDefinition(title: "Rescue 1")),
                .task(TaskDefinition(title: "Rescue 2"))
            ],
            mode: .compact,
            isInlineExpanded: false,
            subtitle: "2 tasks are 2+ weeks overdue"
        )

        XCTAssertEqual(state.previewRows.count, 2)
        XCTAssertEqual(state.totalCount, 2)
        XCTAssertTrue(state.isCompact)
    }
}

final class HabitCoreDataSchemaRegressionTests: XCTestCase {
    func testCurrentCompiledTaskModelIncludesHabitRuntimeAndGamificationSchema() throws {
        let model = try currentCompiledTaskModel()
        let habitEntity = try XCTUnwrap(model.entitiesByName["HabitDefinition"])
        let taskEntity = try XCTUnwrap(model.entitiesByName["TaskDefinition"])
        let expectedHabitFields: Set<String> = [
            "kindRaw",
            "trackingModeRaw",
            "iconSymbolName",
            "iconCategoryKey",
            "colorHex",
            "notes",
            "archivedAt",
            "successMask14Raw",
            "failureMask14Raw",
            "lastHistoryRollDate"
        ]
        let expectedTaskFields: Set<String> = [
            "iconSymbolName"
        ]

        XCTAssertTrue(expectedHabitFields.isSubset(of: Set(habitEntity.attributesByName.keys)))
        XCTAssertTrue(expectedTaskFields.isSubset(of: Set(taskEntity.attributesByName.keys)))
        XCTAssertNil(CoreDataHabitRepository.schemaValidationError(in: model))
        XCTAssertNil(CoreDataGamificationRepository.schemaValidationError(in: model))
    }

    func testLegacyCompiledTaskModelExcludesHabitRuntimeOnlyFields() throws {
        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3.mom")
        let habitEntity = try XCTUnwrap(legacyModel.entitiesByName["HabitDefinition"])
        let legacyFields = Set(habitEntity.attributesByName.keys)

        XCTAssertFalse(legacyFields.contains("kindRaw"))
        XCTAssertFalse(legacyFields.contains("trackingModeRaw"))
        XCTAssertFalse(legacyFields.contains("iconSymbolName"))
        XCTAssertFalse(legacyFields.contains("iconCategoryKey"))
        XCTAssertFalse(legacyFields.contains("colorHex"))
        XCTAssertFalse(legacyFields.contains("notes"))
        XCTAssertFalse(legacyFields.contains("archivedAt"))
        XCTAssertFalse(legacyFields.contains("successMask14Raw"))
        XCTAssertFalse(legacyFields.contains("failureMask14Raw"))
        XCTAssertFalse(legacyFields.contains("lastHistoryRollDate"))
    }

    func testTaskModelCurrentVersionPointsToTaskIconsSourceModel() throws {
        let currentVersionFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("To Do List/TaskModelV3.xcdatamodeld/.xccurrentversion")
        let contents = try String(contentsOf: currentVersionFile, encoding: .utf8)

        XCTAssertTrue(contents.contains("TaskModelV3_TaskIcons.xcdatamodel"))
    }

    func testBootstrapSchemaValidationRejectsMissingHabitRuntimeFields() {
        let model = makeInvalidHabitSchemaModel()

        let error = TaskerPersistentStoreBootstrapService.validateRuntimeSchema(in: model)

        let schemaError = try? XCTUnwrap(error)
        XCTAssertEqual(schemaError?.domain, "CoreDataHabitRepository.Schema")
        XCTAssertTrue((schemaError?.userInfo["missingRequirements"] as? String)?.contains("kindRaw") ?? false)
    }

    func testBootstrapSchemaValidationRejectsMissingTaskIconField() throws {
        let model = try compiledTaskModelVersion(named: "TaskModelV3_Timeline.mom")

        let error = TaskerPersistentStoreBootstrapService.validateRuntimeSchema(in: model)

        let schemaError = try XCTUnwrap(error)
        XCTAssertEqual(schemaError.domain, "TaskerPersistentStoreBootstrapService")
        XCTAssertEqual(schemaError.code, 301)
        XCTAssertTrue((schemaError.userInfo["missingRequirements"] as? String)?.contains("TaskDefinition.iconSymbolName") ?? false)
    }

    func testCoreDataHabitRepositoryReturnsSchemaErrorWhenModelMissesKindRaw() throws {
        let container = try makeContainer(
            name: "BrokenHabitSchema",
            model: makeInvalidHabitSchemaModel(),
            storeType: NSInMemoryStoreType
        )
        let repository = CoreDataHabitRepository(container: container)
        let habit = HabitDefinitionRecord(
            id: UUID(),
            lifeAreaID: UUID(),
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            updatedAt: Date(timeIntervalSince1970: 1_704_067_200)
        )

        do {
            let _: HabitDefinitionRecord = try awaitResult { completion in
                repository.create(habit, completion: completion)
            }
            XCTFail("Expected schema validation failure")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "CoreDataHabitRepository.Schema")
            XCTAssertTrue((nsError.userInfo["missingRequirements"] as? String)?.contains("kindRaw") ?? false)
        }
    }

    func testCreateHabitPersistsRuntimeFieldsUsingCompiledModel() throws {
        let storeURL = temporaryStoreURL(name: "habit-runtime-smoke")
        defer { removeSQLiteArtifacts(at: storeURL) }

        let model = try currentCompiledTaskModel()
        let container = try makeContainer(
            name: "TaskModelV3",
            model: model,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )

        let lifeAreaID = UUID()
        let anchorDate = Date(timeIntervalSince1970: 1_704_067_200)
        let habitRepository = CoreDataHabitRepository(container: container)
        let scheduleRepository = CoreDataScheduleRepository(container: container)
        let occurrenceRepository = CoreDataOccurrenceRepository(container: container)
        let schedulingEngine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let sync = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recompute
        )
        let maintain = MaintainHabitRuntimeUseCase(syncHabitScheduleUseCase: sync)
        let useCase = CreateHabitUseCase(
            habitRepository: habitRepository,
            lifeAreaRepository: CapturingLifeAreaRepository(
                storedAreas: [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
            ),
            projectRepository: MockProjectRepository(projects: []),
            scheduleRepository: scheduleRepository,
            maintainHabitRuntimeUseCase: maintain
        )

        let created = try awaitResult { completion in
            useCase.execute(
                request: CreateHabitRequest(
                    title: "No smoking",
                    lifeAreaID: lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "nosign", categoryKey: "recovery"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        XCTAssertEqual(created.kind, .negative)
        XCTAssertEqual(created.trackingMode, .lapseOnly)

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
        let persisted = try XCTUnwrap(container.viewContext.fetch(fetchRequest).first)
        XCTAssertEqual(persisted.value(forKey: "kindRaw") as? String, HabitKind.negative.rawValue)
        XCTAssertEqual(persisted.value(forKey: "trackingModeRaw") as? String, HabitTrackingMode.lapseOnly.rawValue)
        unloadPersistentStores(from: container)
    }

    func testCreateHabitNormalizesPositiveLapseOnlyToDailyCheckIn() throws {
        let storeURL = temporaryStoreURL(name: "habit-runtime-positive-normalization")
        defer { removeSQLiteArtifacts(at: storeURL) }

        let model = try currentCompiledTaskModel()
        let container = try makeContainer(
            name: "TaskModelV3",
            model: model,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )

        let lifeAreaID = UUID()
        let anchorDate = Date(timeIntervalSince1970: 1_704_067_200)
        let habitRepository = CoreDataHabitRepository(container: container)
        let scheduleRepository = CoreDataScheduleRepository(container: container)
        let occurrenceRepository = CoreDataOccurrenceRepository(container: container)
        let schedulingEngine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let sync = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recompute
        )
        let maintain = MaintainHabitRuntimeUseCase(syncHabitScheduleUseCase: sync)
        let useCase = CreateHabitUseCase(
            habitRepository: habitRepository,
            lifeAreaRepository: CapturingLifeAreaRepository(
                storedAreas: [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
            ),
            projectRepository: MockProjectRepository(projects: []),
            scheduleRepository: scheduleRepository,
            maintainHabitRuntimeUseCase: maintain
        )

        let created = try awaitResult { completion in
            useCase.execute(
                request: CreateHabitRequest(
                    title: "Meditate",
                    lifeAreaID: lifeAreaID,
                    kind: .positive,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "brain.head.profile", categoryKey: "mindfulness"),
                    cadence: .daily(hour: 7, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        XCTAssertEqual(created.kind, .positive)
        XCTAssertEqual(created.trackingMode, .dailyCheckIn)
        XCTAssertEqual(created.habitType, "check_in")
        unloadPersistentStores(from: container)
    }

    func testPausedHabitsAreExcludedFromSignalQueries() throws {
        let storeURL = temporaryStoreURL(name: "habit-runtime-paused-signals")
        defer { removeSQLiteArtifacts(at: storeURL) }

        let model = try currentCompiledTaskModel()
        let container = try makeContainer(
            name: "TaskModelV3",
            model: model,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )

        let lifeAreaID = UUID()
        let anchorDate = Date(timeIntervalSince1970: 1_704_067_200)
        let habitRepository = CoreDataHabitRepository(container: container)
        let scheduleRepository = CoreDataScheduleRepository(container: container)
        let occurrenceRepository = CoreDataOccurrenceRepository(container: container)
        let schedulingEngine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let sync = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recompute
        )
        let maintain = MaintainHabitRuntimeUseCase(syncHabitScheduleUseCase: sync)
        let createHabit = CreateHabitUseCase(
            habitRepository: habitRepository,
            lifeAreaRepository: CapturingLifeAreaRepository(
                storedAreas: [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
            ),
            projectRepository: MockProjectRepository(projects: []),
            scheduleRepository: scheduleRepository,
            maintainHabitRuntimeUseCase: maintain
        )

        var created = try awaitResult { completion in
            createHabit.execute(
                request: CreateHabitRequest(
                    title: "Stretch",
                    lifeAreaID: lifeAreaID,
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    icon: HabitIconMetadata(symbolName: "figure.cooldown", categoryKey: "movement"),
                    cadence: .daily(hour: 8, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }
        created.isPaused = true
        created.updatedAt = anchorDate.addingTimeInterval(60)
        _ = try awaitResult { completion in
            habitRepository.update(created, completion: completion)
        }

        let readRepository = CoreDataHabitRuntimeReadRepository(container: container)
        let summaries = try awaitResult { completion in
            readRepository.fetchSignals(
                start: Calendar.current.startOfDay(for: anchorDate),
                end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: anchorDate)) ?? anchorDate,
                completion: completion
            )
        }

        XCTAssertTrue(summaries.isEmpty)
        unloadPersistentStores(from: container)
    }

    func testMigratingGamificationStoreToCurrentModelBackfillsHabitRuntimeFields() throws {
        let storeURL = temporaryStoreURL(name: "habit-runtime-migration")
        defer { removeSQLiteArtifacts(at: storeURL) }
        let defaults = UserDefaults.standard
        let runtimeFlagKeys = [
            "tasker.habit.runtime.field_backfill.v1",
            "tasker.habit.runtime.repair_required.v1",
            "tasker.habit.runtime.repair_completed.v1"
        ]
        let originalRuntimeFlagValues: [String: Any?] = Dictionary(uniqueKeysWithValues: runtimeFlagKeys.map { key in
            (key, defaults.object(forKey: key))
        })
        defer {
            for key in runtimeFlagKeys {
                if let value = originalRuntimeFlagValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        for key in runtimeFlagKeys {
            defaults.removeObject(forKey: key)
        }

        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3_Gamification.mom")
        let legacyContainer = try makeContainer(
            name: "TaskModelV3",
            model: legacyModel,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )
        let habitID = UUID()
        legacyContainer.viewContext.performAndWait {
            let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: legacyContainer.viewContext)
            object.setValue(habitID, forKey: "id")
            object.setValue(UUID(), forKey: "lifeAreaID")
            object.setValue("No drinking", forKey: "title")
            object.setValue("quit_lapse_only", forKey: "habitType")
            object.setValue(false, forKey: "isPaused")
            object.setValue(Int32(0), forKey: "streakCurrent")
            object.setValue(Int32(0), forKey: "streakBest")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "createdAt")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? legacyContainer.viewContext.save()
        }
        unloadPersistentStores(from: legacyContainer)

        let currentModel = try currentCompiledTaskModel()
        let migratedContainer = try makeCloudKitContainer(
            name: "TaskModelV3",
            model: currentModel,
            url: storeURL
        )

        TaskerPersistentRuntimeInitializer().initialize(container: migratedContainer)

        let request = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
        request.predicate = NSPredicate(format: "id == %@", habitID as CVarArg)
        let migrated = try XCTUnwrap(migratedContainer.viewContext.fetch(request).first)
        XCTAssertEqual(migrated.value(forKey: "kindRaw") as? String, HabitKind.negative.rawValue)
        XCTAssertEqual(migrated.value(forKey: "trackingModeRaw") as? String, HabitTrackingMode.lapseOnly.rawValue)
        XCTAssertNotNil(migrated.value(forKey: "lastHistoryRollDate") as? Date)
        unloadPersistentStores(from: migratedContainer)
    }

    func testMigrationStillBackfillsWhenLegacyBackfillMarkerIsAlreadySet() throws {
        let storeURL = temporaryStoreURL(name: "habit-runtime-migration-flagged")
        defer { removeSQLiteArtifacts(at: storeURL) }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "tasker.habit.runtime.field_backfill.v1")
        defaults.set(false, forKey: "tasker.habit.runtime.repair_required.v1")
        defaults.set(false, forKey: "tasker.habit.runtime.repair_completed.v1")
        defer {
            defaults.removeObject(forKey: "tasker.habit.runtime.field_backfill.v1")
            defaults.removeObject(forKey: "tasker.habit.runtime.repair_required.v1")
            defaults.removeObject(forKey: "tasker.habit.runtime.repair_completed.v1")
        }

        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3_Gamification.mom")
        let legacyContainer = try makeContainer(
            name: "TaskModelV3",
            model: legacyModel,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )
        let habitID = UUID()
        legacyContainer.viewContext.performAndWait {
            let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: legacyContainer.viewContext)
            object.setValue(habitID, forKey: "id")
            object.setValue(UUID(), forKey: "lifeAreaID")
            object.setValue("No smoking", forKey: "title")
            object.setValue("quit", forKey: "habitType")
            object.setValue(false, forKey: "isPaused")
            object.setValue(Int32(0), forKey: "streakCurrent")
            object.setValue(Int32(0), forKey: "streakBest")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "createdAt")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? legacyContainer.viewContext.save()
        }
        unloadPersistentStores(from: legacyContainer)

        let migratedContainer = try makeCloudKitContainer(
            name: "TaskModelV3",
            model: try currentCompiledTaskModel(),
            url: storeURL
        )

        TaskerPersistentRuntimeInitializer().initialize(container: migratedContainer)

        let request = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
        request.predicate = NSPredicate(format: "id == %@", habitID as CVarArg)
        let migrated = try XCTUnwrap(migratedContainer.viewContext.fetch(request).first)
        XCTAssertEqual(migrated.value(forKey: "kindRaw") as? String, HabitKind.negative.rawValue)
        XCTAssertEqual(migrated.value(forKey: "trackingModeRaw") as? String, HabitTrackingMode.dailyCheckIn.rawValue)
        XCTAssertNotNil(migrated.value(forKey: "lastHistoryRollDate") as? Date)
        unloadPersistentStores(from: migratedContainer)
    }

    func testHabitDefinitionCodableCanonicalizesDefaultsAndOmitsNilConfigs() throws {
        let id = UUID()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let rawJSON = """
        {
          "id": "\(id.uuidString)",
          "title": "Hydrate",
          "habitType": "check_in",
          "kindRaw": "",
          "trackingModeRaw": "",
          "createdAt": 0,
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(HabitDefinitionRecord.self, from: rawJSON)

        XCTAssertEqual(decoded.kindRaw, HabitKind.positive.rawValue)
        XCTAssertEqual(decoded.trackingModeRaw, HabitTrackingMode.dailyCheckIn.rawValue)
        XCTAssertEqual(decoded.kind, .positive)
        XCTAssertEqual(decoded.trackingMode, .dailyCheckIn)
        XCTAssertEqual(Set([decoded]).count, 1)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let encoded = try encoder.encode(decoded)
        let encodedJSON = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(encodedJSON.contains("targetConfigData"))
        XCTAssertFalse(encodedJSON.contains("metricConfigData"))
        XCTAssertFalse(encodedJSON.contains(":null"))
    }

    func testMigratingLegacyStoreCanonicalizesAndDeduplicatesOccurrenceKeys() throws {
        let storeURL = temporaryStoreURL(name: "occurrence-key-migration")
        defer { removeSQLiteArtifacts(at: storeURL) }

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "tasker.occurrence.key_backfill.v1")
        defer {
            defaults.removeObject(forKey: "tasker.occurrence.key_backfill.v1")
        }

        let templateID = UUID()
        let sourceID = UUID()
        let keptOccurrenceID = UUID()
        let duplicateOccurrenceID = UUID()
        let reminderID = UUID()
        let resolutionID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_704_067_200)
        let legacyKey = "\(templateID.uuidString)_2024-01-01T00:00"

        let legacyContainer = try makeContainer(
            name: "TaskModelV3",
            model: try compiledTaskModelVersion(named: "TaskModelV3_Gamification.mom"),
            storeType: NSSQLiteStoreType,
            url: storeURL
        )
        legacyContainer.viewContext.performAndWait {
            let template = NSEntityDescription.insertNewObject(forEntityName: "ScheduleTemplate", into: legacyContainer.viewContext)
            template.setValue(templateID, forKey: "id")
            template.setValue(ScheduleSourceType.habit.rawValue, forKey: "sourceType")
            template.setValue(sourceID, forKey: "sourceID")
            template.setValue("UTC", forKey: "timezoneID")
            template.setValue(TemporalReference.anchored.rawValue, forKey: "temporalReference")
            template.setValue(scheduledAt, forKey: "anchorAt")
            template.setValue(true, forKey: "isActive")
            template.setValue(scheduledAt, forKey: "createdAt")
            template.setValue(scheduledAt, forKey: "updatedAt")

            let duplicate = NSEntityDescription.insertNewObject(forEntityName: "Occurrence", into: legacyContainer.viewContext)
            duplicate.setValue(duplicateOccurrenceID, forKey: "id")
            duplicate.setValue(nil, forKey: "occurrenceKey")
            duplicate.setValue(templateID, forKey: "scheduleTemplateID")
            duplicate.setValue(ScheduleSourceType.habit.rawValue, forKey: "sourceType")
            duplicate.setValue(sourceID, forKey: "sourceID")
            duplicate.setValue(scheduledAt, forKey: "scheduledAt")
            duplicate.setValue(OccurrenceState.pending.rawValue, forKey: "state")
            duplicate.setValue(true, forKey: "isGenerated")
            duplicate.setValue(scheduledAt, forKey: "createdAt")
            duplicate.setValue(scheduledAt, forKey: "updatedAt")

            let reminder = NSEntityDescription.insertNewObject(forEntityName: "Reminder", into: legacyContainer.viewContext)
            reminder.setValue(reminderID, forKey: "id")
            reminder.setValue(ScheduleSourceType.habit.rawValue, forKey: "sourceType")
            reminder.setValue(sourceID, forKey: "sourceID")
            reminder.setValue(duplicateOccurrenceID, forKey: "occurrenceID")
            reminder.setValue("at_time", forKey: "policy")
            reminder.setValue(scheduledAt, forKey: "createdAt")
            reminder.setValue(scheduledAt, forKey: "updatedAt")
            reminder.setValue(duplicate, forKey: "occurrenceRef")

            let kept = NSEntityDescription.insertNewObject(forEntityName: "Occurrence", into: legacyContainer.viewContext)
            kept.setValue(keptOccurrenceID, forKey: "id")
            kept.setValue(legacyKey, forKey: "occurrenceKey")
            kept.setValue(templateID, forKey: "scheduleTemplateID")
            kept.setValue(ScheduleSourceType.habit.rawValue, forKey: "sourceType")
            kept.setValue(sourceID, forKey: "sourceID")
            kept.setValue(scheduledAt, forKey: "scheduledAt")
            kept.setValue(OccurrenceState.completed.rawValue, forKey: "state")
            kept.setValue(true, forKey: "isGenerated")
            kept.setValue(scheduledAt, forKey: "createdAt")
            kept.setValue(scheduledAt.addingTimeInterval(60), forKey: "updatedAt")

            let resolution = NSEntityDescription.insertNewObject(forEntityName: "OccurrenceResolution", into: legacyContainer.viewContext)
            resolution.setValue(resolutionID, forKey: "id")
            resolution.setValue(duplicateOccurrenceID, forKey: "occurrenceID")
            resolution.setValue(OccurrenceResolutionType.completed.rawValue, forKey: "resolutionType")
            resolution.setValue(scheduledAt, forKey: "resolvedAt")
            resolution.setValue(OccurrenceActor.user.rawValue, forKey: "actor")
            resolution.setValue(scheduledAt, forKey: "createdAt")
            resolution.setValue(duplicate, forKey: "occurrenceRef")

            try? legacyContainer.viewContext.save()
        }
        unloadPersistentStores(from: legacyContainer)

        let migratedContainer = try makeCloudKitContainer(
            name: "TaskModelV3",
            model: try currentCompiledTaskModel(),
            url: storeURL
        )

        TaskerPersistentRuntimeInitializer().initialize(container: migratedContainer)

        let occurrenceRequest = NSFetchRequest<NSManagedObject>(entityName: "Occurrence")
        let migratedOccurrences = try migratedContainer.viewContext.fetch(occurrenceRequest)
        XCTAssertEqual(migratedOccurrences.count, 1)
        XCTAssertEqual(
            migratedOccurrences.first?.value(forKey: "occurrenceKey") as? String,
            OccurrenceKeyCodec.encode(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: sourceID
            )
        )
        XCTAssertEqual(migratedOccurrences.first?.value(forKey: "id") as? UUID, keptOccurrenceID)

        let reminderRequest = NSFetchRequest<NSManagedObject>(entityName: "Reminder")
        let reminders = try migratedContainer.viewContext.fetch(reminderRequest)
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.value(forKey: "occurrenceID") as? UUID, keptOccurrenceID)

        let resolutionRequest = NSFetchRequest<NSManagedObject>(entityName: "OccurrenceResolution")
        let resolutions = try migratedContainer.viewContext.fetch(resolutionRequest)
        XCTAssertEqual(resolutions.count, 1)
        XCTAssertEqual(resolutions.first?.value(forKey: "occurrenceID") as? UUID, keptOccurrenceID)

        unloadPersistentStores(from: migratedContainer)
    }

    func testBootstrapMigratesLegacySplitStoresAndReturnsFullSync() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appGroupURL = rootURL.appendingPathComponent("app-group", isDirectory: true)
        let legacyURL = rootURL.appendingPathComponent("legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: appGroupURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let locationService = TaskerPersistentStoreLocationService(
            fileManager: .default,
            appGroupContainerURLProvider: { appGroupURL },
            legacyStoreDirectoryURLProvider: { legacyURL }
        )
        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3_Gamification.mom")
        let currentModel = try currentCompiledTaskModel()
        let cloudURL = appGroupURL.appendingPathComponent(TaskerPersistentStoreLocationService.cloudStoreFileName)
        let localURL = appGroupURL.appendingPathComponent(TaskerPersistentStoreLocationService.localStoreFileName)

        let legacyCloud = try makeConfiguredContainer(
            name: "TaskModelV3",
            model: legacyModel,
            storeType: NSSQLiteStoreType,
            url: cloudURL,
            configuration: "CloudSync"
        )
        legacyCloud.viewContext.performAndWait {
            let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: legacyCloud.viewContext)
            object.setValue(UUID(), forKey: "id")
            object.setValue(UUID(), forKey: "lifeAreaID")
            object.setValue("Legacy split-store habit", forKey: "title")
            object.setValue("check_in", forKey: "habitType")
            object.setValue(false, forKey: "isPaused")
            object.setValue(Int32(0), forKey: "streakCurrent")
            object.setValue(Int32(0), forKey: "streakBest")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "createdAt")
            object.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? legacyCloud.viewContext.save()
        }
        unloadPersistentStores(from: legacyCloud)

        let currentLocal = try makeConfiguredContainer(
            name: "TaskModelV3",
            model: currentModel,
            storeType: NSSQLiteStoreType,
            url: localURL,
            configuration: "LocalOnly"
        )
        currentLocal.viewContext.performAndWait {
            let profile = NSEntityDescription.insertNewObject(forEntityName: "GamificationProfile", into: currentLocal.viewContext)
            profile.setValue(UUID(), forKey: "id")
            profile.setValue(Int64(42), forKey: "xpTotal")
            profile.setValue(Int32(3), forKey: "level")
            profile.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? currentLocal.viewContext.save()
        }
        unloadPersistentStores(from: currentLocal)

        let service = TaskerPersistentStoreBootstrapService(
            storeLocationService: locationService,
            cloudKitRuntimeContextProvider: { CloudKitRuntimeContext(environment: [:], arguments: [], isSimulator: false) },
            enableCloudKitContainerOptions: false
        )

        let result = await service.bootstrapV3PersistentContainer()
        guard case let .ready(container) = result.state else {
            XCTFail("Expected ready persistent bootstrap state")
            return
        }

        XCTAssertEqual(result.syncMode, .fullSync)

        let habitRequest = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
        XCTAssertEqual(try container.viewContext.count(for: habitRequest), 1)

        let profileRequest = NSFetchRequest<NSManagedObject>(entityName: "GamificationProfile")
        XCTAssertEqual(try container.viewContext.count(for: profileRequest), 1)
        unloadPersistentStores(from: container)
    }

    func testBootstrapAutoRebuildsOnlyCloudSyncStoreWhenMetadataIsIncompatible() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appGroupURL = rootURL.appendingPathComponent("app-group", isDirectory: true)
        let legacyURL = rootURL.appendingPathComponent("legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: appGroupURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let locationService = TaskerPersistentStoreLocationService(
            fileManager: .default,
            appGroupContainerURLProvider: { appGroupURL },
            legacyStoreDirectoryURLProvider: { legacyURL }
        )
        let currentModel = try currentCompiledTaskModel()
        let cloudURL = appGroupURL.appendingPathComponent(TaskerPersistentStoreLocationService.cloudStoreFileName)
        let localURL = appGroupURL.appendingPathComponent(TaskerPersistentStoreLocationService.localStoreFileName)

        let incompatibleCloud = try makeContainer(
            name: "TaskModelV3",
            model: currentModel,
            storeType: NSSQLiteStoreType,
            url: cloudURL
        )
        incompatibleCloud.viewContext.performAndWait {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: incompatibleCloud.viewContext)
            task.setValue(UUID(), forKey: "id")
            task.setValue("Wrong topology", forKey: "title")
            task.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "createdAt")
            task.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? incompatibleCloud.viewContext.save()
        }
        unloadPersistentStores(from: incompatibleCloud)

        let currentLocal = try makeConfiguredContainer(
            name: "TaskModelV3",
            model: currentModel,
            storeType: NSSQLiteStoreType,
            url: localURL,
            configuration: "LocalOnly"
        )
        currentLocal.viewContext.performAndWait {
            let profile = NSEntityDescription.insertNewObject(forEntityName: "GamificationProfile", into: currentLocal.viewContext)
            profile.setValue(UUID(), forKey: "id")
            profile.setValue(Int64(84), forKey: "xpTotal")
            profile.setValue(Int32(4), forKey: "level")
            profile.setValue(Date(timeIntervalSince1970: 1_704_067_200), forKey: "updatedAt")
            try? currentLocal.viewContext.save()
        }
        unloadPersistentStores(from: currentLocal)

        let service = TaskerPersistentStoreBootstrapService(
            storeLocationService: locationService,
            cloudKitRuntimeContextProvider: { CloudKitRuntimeContext(environment: [:], arguments: [], isSimulator: false) },
            enableCloudKitContainerOptions: false
        )

        let result = await service.bootstrapV3PersistentContainer()
        guard case let .ready(container) = result.state else {
            XCTFail("Expected ready persistent bootstrap state after CloudSync rebuild")
            return
        }

        XCTAssertEqual(result.syncMode, .fullSync)
        let rebuiltTaskRequest = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        rebuiltTaskRequest.predicate = NSPredicate(format: "title == %@", "Wrong topology")
        XCTAssertEqual(try container.viewContext.count(for: rebuiltTaskRequest), 0)
        let profileRequest = NSFetchRequest<NSManagedObject>(entityName: "GamificationProfile")
        XCTAssertEqual(try container.viewContext.count(for: profileRequest), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloudURL.path))
        unloadPersistentStores(from: container)
    }

    func testSnapshotMappingHandlesLegacyTimelineModelWithoutTaskIconField() throws {
        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3_Timeline.mom")
        let container = try makeContainer(
            name: "TaskModelV3",
            model: legacyModel,
            storeType: NSInMemoryStoreType
        )
        defer { unloadPersistentStores(from: container) }

        let originalFlag = V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled
        V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled = true
        defer { V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled = originalFlag }

        let taskID = UUID()
        let projectID = UUID()
        let now = Date(timeIntervalSince1970: 1_704_067_200)
        container.viewContext.performAndWait {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: container.viewContext)
            task.setValue(taskID, forKey: "id")
            task.setValue(taskID, forKey: "taskID")
            task.setValue(projectID, forKey: "projectID")
            task.setValue("Legacy Snapshot Task", forKey: "title")
            task.setValue(Int32(TaskPriority.low.rawValue), forKey: "priority")
            task.setValue(Int32(TaskType.morning.rawValue), forKey: "taskType")
            task.setValue(false, forKey: "isComplete")
            task.setValue(now, forKey: "dateAdded")
            task.setValue(false, forKey: "isEveningTask")
            task.setValue(now, forKey: "createdAt")
            task.setValue(now, forKey: "updatedAt")
            task.setValue("pending", forKey: "status")
            try? container.viewContext.save()
        }

        let repository = CoreDataTaskDefinitionRepository(container: container)
        let fetched = try awaitResult { completion in
            repository.fetchAll(query: nil, completion: completion)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, taskID)
        XCTAssertNil(fetched.first?.iconSymbolName)
    }

    func testTaskRepositoryMigratesTimelineStoreToCurrentModelWithTaskIconField() throws {
        let storeURL = temporaryStoreURL(name: "task-icon-migration")
        defer { removeSQLiteArtifacts(at: storeURL) }

        let legacyModel = try compiledTaskModelVersion(named: "TaskModelV3_Timeline.mom")
        let legacyContainer = try makeContainer(
            name: "TaskModelV3",
            model: legacyModel,
            storeType: NSSQLiteStoreType,
            url: storeURL
        )

        let taskID = UUID()
        let projectID = UUID()
        let now = Date(timeIntervalSince1970: 1_704_067_200)
        legacyContainer.viewContext.performAndWait {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: legacyContainer.viewContext)
            task.setValue(taskID, forKey: "id")
            task.setValue(taskID, forKey: "taskID")
            task.setValue(projectID, forKey: "projectID")
            task.setValue("Migrated Icon Task", forKey: "title")
            task.setValue(Int32(TaskPriority.low.rawValue), forKey: "priority")
            task.setValue(Int32(TaskType.morning.rawValue), forKey: "taskType")
            task.setValue(false, forKey: "isComplete")
            task.setValue(now, forKey: "dateAdded")
            task.setValue(false, forKey: "isEveningTask")
            task.setValue(now, forKey: "createdAt")
            task.setValue(now, forKey: "updatedAt")
            task.setValue("pending", forKey: "status")
            try? legacyContainer.viewContext.save()
        }
        unloadPersistentStores(from: legacyContainer)

        let migratedContainer = try makeContainer(
            name: "TaskModelV3",
            model: try currentCompiledTaskModel(),
            storeType: NSSQLiteStoreType,
            url: storeURL
        )
        defer { unloadPersistentStores(from: migratedContainer) }

        let repository = CoreDataTaskDefinitionRepository(container: migratedContainer)
        let fetched = try awaitResult { completion in
            repository.fetchAll(query: nil, completion: completion)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, taskID)
        XCTAssertEqual(fetched.first?.title, "Migrated Icon Task")
        XCTAssertNil(fetched.first?.iconSymbolName)
    }

    func testTaskIconPersistsAndClearsWithCurrentModel() throws {
        let container = try makeContainer(
            name: "TaskModelV3",
            model: try currentCompiledTaskModel(),
            storeType: NSInMemoryStoreType
        )
        defer { unloadPersistentStores(from: container) }

        let repository = CoreDataTaskDefinitionRepository(container: container)
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)

        let created = try awaitResult { completion in
            repository.create(
                TaskDefinition(
                    title: "Icon Persistence Task",
                    iconSymbolName: "star.fill",
                    createdAt: createdAt,
                    updatedAt: createdAt
                ),
                completion: completion
            )
        }
        XCTAssertEqual(created.iconSymbolName, "star.fill")

        let fetchedCreated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: created.id, completion: completion)
        }
        XCTAssertEqual(fetchedCreated?.iconSymbolName, "star.fill")

        var updatedTask = created
        updatedTask.iconSymbolName = nil
        updatedTask.updatedAt = createdAt.addingTimeInterval(60)
        _ = try awaitResult { completion in
            repository.update(updatedTask, completion: completion)
        }

        let fetchedUpdated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: created.id, completion: completion)
        }
        XCTAssertNil(fetchedUpdated?.iconSymbolName)
    }

    func testWriteClosedLaunchSkipsStartupMutationWorkflows() throws {
        let appDelegateSource = try workspaceFileContents("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("if shouldRunStartupMutationWorkflows {"),
            "setupCleanArchitecture should gate startup mutation workflows behind shouldRunStartupMutationWorkflows"
        )
        XCTAssertTrue(
            appDelegateSource.contains("private var shouldRunStartupMutationWorkflows: Bool"),
            "AppDelegate should expose a dedicated write-closed startup gate"
        )
        XCTAssertTrue(
            appDelegateSource.contains("guard shouldRunStartupMutationWorkflows else {"),
            "Habit runtime maintenance should fail closed while the app is write-closed"
        )
    }

    func testCurrentCloudSyncModelAvoidsUniquenessConstraintsOnSyncableEntities() throws {
        let model = try currentCompiledTaskModel()
        let constrainedEntities = ["Occurrence"]

        for entityName in constrainedEntities {
            let entity = try XCTUnwrap(
                model.entitiesByName[entityName],
                "Expected \(entityName) to exist in the current TaskModelV3"
            )
            XCTAssertTrue(
                entity.uniquenessConstraints.isEmpty,
                "\(entityName) must not declare uniqueness constraints because CloudSync bootstrap uses NSPersistentCloudKitContainer"
            )
        }
    }

    private func workspaceFileContents(_ relativePath: String) throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func currentCompiledTaskModel() throws -> NSManagedObjectModel {
        let momdURL = try taskModelBundleURL()
        guard let model = NSManagedObjectModel(contentsOf: momdURL) else {
            throw NSError(domain: "HabitCoreDataSchemaRegressionTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to load current TaskModelV3 compiled model"
            ])
        }
        return model
    }

    private func compiledTaskModelVersion(named fileName: String) throws -> NSManagedObjectModel {
        let modelURL = try taskModelBundleURL().appendingPathComponent(fileName)
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(domain: "HabitCoreDataSchemaRegressionTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to load compiled model version \(fileName)"
            ])
        }
        return model
    }

    private func taskModelBundleURL() throws -> URL {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        for bundle in bundles {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") {
                return url
            }
        }
        throw NSError(domain: "HabitCoreDataSchemaRegressionTests", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Unable to locate TaskModelV3.momd in test bundles"
        ])
    }

    private func makeContainer(
        name: String,
        model: NSManagedObjectModel,
        storeType: String,
        url: URL? = nil
    ) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = storeType
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        if let url {
            description.url = url
        }
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func makeConfiguredContainer(
        name: String,
        model: NSManagedObjectModel,
        storeType: String,
        url: URL,
        configuration: String
    ) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.type = storeType
        description.configuration = configuration
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func makeCloudKitContainer(
        name: String,
        model: NSManagedObjectModel,
        url: URL
    ) throws -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: name, managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func temporaryStoreURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).sqlite")
    }

    private func removeSQLiteArtifacts(at url: URL) {
        let fileManager = FileManager.default
        let sidecars = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm")
        ]
        for fileURL in sidecars where fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func unloadPersistentStores(from container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
    }

    private func makeInvalidHabitSchemaModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let habitEntity = NSEntityDescription()
        habitEntity.name = "HabitDefinition"
        habitEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = true

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = true

        let habitType = NSAttributeDescription()
        habitType.name = "habitType"
        habitType.attributeType = .stringAttributeType
        habitType.isOptional = true

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = true

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = true

        habitEntity.properties = [id, title, habitType, createdAt, updatedAt]
        model.entities = [habitEntity]
        return model
    }
}

// MARK: - Legacy test compatibility shims

typealias Task = TaskDefinition

extension TaskDefinition {
    init(
        id: UUID = UUID(),
        projectID: UUID = ProjectConstants.inboxProjectID,
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        dueDate: Date? = nil,
        project: String? = ProjectConstants.inboxProjectName,
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            projectID: projectID,
            projectName: project,
            title: name,
            details: details,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            dueDate: dueDate,
            isComplete: isComplete,
            dateAdded: dateAdded,
            dateCompleted: dateCompleted,
            updatedAt: updatedAt
        )
    }
}

protocol LegacyTaskRepositoryShim {
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void)
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void)
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void)
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void)
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void)
}

struct LegacyTaskUpdatePayload {
    var name: String?
    var details: String?
    var projectID: UUID?
    var dueDate: Date?
    var type: TaskType?

    init(
        name: String? = nil,
        details: String? = nil,
        projectID: UUID? = nil,
        dueDate: Date? = nil,
        type: TaskType? = nil
    ) {
        self.name = name
        self.details = details
        self.projectID = projectID
        self.dueDate = dueDate
        self.type = type
    }
}

final class LocalTaskUpdateUseCase {
    private let taskRepository: LegacyTaskRepositoryShim
    private let projectRepository: ProjectRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        notificationService: NotificationServiceProtocol?
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.notificationService = notificationService
    }

    func execute(
        taskId: UUID,
        request: LegacyTaskUpdatePayload,
        completion: @escaping (Result<Task, Error>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let maybeTask):
                guard var task = maybeTask else {
                    completion(.failure(NSError(domain: "LocalTaskUpdateUseCase", code: 404)))
                    return
                }

                task.title = request.name ?? task.title
                task.details = request.details ?? task.details
                task.dueDate = request.dueDate ?? task.dueDate
                task.type = request.type ?? task.type

                let persist: (Task) -> Void = { updated in
                    self.taskRepository.updateTask(updated) { updateResult in
                        if case .success(let savedTask) = updateResult {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskUpdated"),
                                object: savedTask
                            )
                            self.notificationService?.cancelTaskReminder(taskId: savedTask.id)
                        }
                        completion(updateResult)
                    }
                }

                if let projectID = request.projectID {
                    task.projectID = projectID
                    projectRepository.fetchProject(withId: projectID) { projectResult in
                        if case .success(let project) = projectResult {
                            task.projectName = project?.name
                        }
                        persist(task)
                    }
                } else {
                    persist(task)
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

private enum LegacyTaskAdapterError: LocalizedError {
    case taskNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        }
    }
}

private final class ShimTaskReadModelAdapter: TaskReadModelRepositoryProtocol {
    private let legacyRepository: LegacyTaskRepositoryShim

    init(legacyRepository: LegacyTaskRepositoryShim) {
        self.legacyRepository = legacyRepository
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                let filtered = self.applyReadQuery(query, to: tasks)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: filtered.slice,
                    totalCount: filtered.totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                let filtered = self.applySearchQuery(query, to: tasks)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: filtered.slice,
                    totalCount: filtered.totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                var counts: [UUID: Int] = [:]
                for task in tasks where includeCompleted || task.isComplete == false {
                    counts[task.projectID, default: 0] += 1
                }
                completion(.success(counts))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                var totals: [UUID: Int] = [:]
                for task in tasks {
                    guard task.isComplete, let completedAt = task.dateCompleted else { continue }
                    guard completedAt >= startDate && completedAt <= endDate else { continue }
                    totals[task.projectID, default: 0] += task.priority.scorePoints
                }
                completion(.success(totals))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func applyReadQuery(_ query: TaskReadQuery, to tasks: [Task]) -> (slice: [Task], totalCount: Int) {
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart {
                guard let dueDate = task.dueDate, dueDate >= start else { return false }
            }
            if let end = query.dueDateEnd {
                guard let dueDate = task.dueDate, dueDate <= end else { return false }
            }
            if let updatedAfter = query.updatedAfter, task.updatedAt < updatedAfter { return false }
            return true
        }

        let sorted = sort(filtered, by: query.sortBy)
        let totalCount = sorted.count
        let start = min(max(0, query.offset), totalCount)
        let end = min(start + max(1, query.limit), totalCount)
        return (Array(sorted[start..<end]), totalCount)
    }

    private func applySearchQuery(_ query: TaskSearchQuery, to tasks: [Task]) -> (slice: [Task], totalCount: Int) {
        let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if text.isEmpty { return true }
            let inTitle = task.title.lowercased().contains(text)
            let inDetails = task.details?.lowercased().contains(text) ?? false
            return inTitle || inDetails
        }

        let totalCount = filtered.count
        let start = min(max(0, query.offset), totalCount)
        let end = min(start + max(1, query.limit), totalCount)
        return (Array(filtered[start..<end]), totalCount)
    }

    private func sort(_ tasks: [Task], by sort: TaskReadSort) -> [Task] {
        switch sort {
        case .dueDateAscending:
            return tasks.sorted {
                ($0.dueDate ?? Date.distantFuture, $0.updatedAt) < ($1.dueDate ?? Date.distantFuture, $1.updatedAt)
            }
        case .dueDateDescending:
            return tasks.sorted {
                ($0.dueDate ?? Date.distantPast, $0.updatedAt) > ($1.dueDate ?? Date.distantPast, $1.updatedAt)
            }
        case .updatedAtDescending:
            return tasks.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
}

private final class ShimTaskDefinitionRepositoryAdapter: TaskDefinitionRepositoryProtocol {
    private let legacyRepository: LegacyTaskRepositoryShim

    init(legacyRepository: LegacyTaskRepositoryShim) {
        self.legacyRepository = legacyRepository
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        legacyRepository.fetchAllTasks(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                completion(.success(Self.applyQuery(query, to: tasks)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        legacyRepository.fetchTask(withId: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.createTask(task, completion: completion)
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        create(request.toTaskDefinition(projectName: request.projectName), completion: completion)
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.updateTask(task, completion: completion)
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.fetchTask(withId: request.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let maybeTask):
                guard var task = maybeTask else {
                    completion(.failure(LegacyTaskAdapterError.taskNotFound(request.id)))
                    return
                }

                if let title = request.title { task.title = title }
                if let details = request.details { task.details = details }
                if let projectID = request.projectID { task.projectID = projectID }
                if request.clearLifeArea {
                    task.lifeAreaID = nil
                } else if let lifeAreaID = request.lifeAreaID {
                    task.lifeAreaID = lifeAreaID
                }
                if request.clearSection {
                    task.sectionID = nil
                } else if let sectionID = request.sectionID {
                    task.sectionID = sectionID
                }
                if request.clearDueDate {
                    task.dueDate = nil
                } else if let dueDate = request.dueDate {
                    task.dueDate = dueDate
                }

                if request.clearParentTaskLink {
                    task.parentTaskID = nil
                } else if let parentTaskID = request.parentTaskID {
                    task.parentTaskID = parentTaskID
                }

                if let tagIDs = request.tagIDs { task.tagIDs = tagIDs }
                if let dependencies = request.dependencies { task.dependencies = dependencies }
                if let priority = request.priority { task.priority = priority }
                if let type = request.type { task.type = type }
                if let energy = request.energy { task.energy = energy }
                if let category = request.category { task.category = category }
                if let context = request.context { task.context = context }

                if let isComplete = request.isComplete {
                    task.isComplete = isComplete
                    if isComplete == false {
                        task.dateCompleted = nil
                    }
                }

                if let dateCompleted = request.dateCompleted {
                    task.dateCompleted = dateCompleted
                }

                if request.clearReminderTime {
                    task.alertReminderTime = nil
                } else if let alertReminderTime = request.alertReminderTime {
                    task.alertReminderTime = alertReminderTime
                }
                if request.clearEstimatedDuration {
                    task.estimatedDuration = nil
                } else if let estimatedDuration = request.estimatedDuration {
                    task.estimatedDuration = estimatedDuration
                }
                if let actualDuration = request.actualDuration { task.actualDuration = actualDuration }
                if request.clearRepeatPattern {
                    task.repeatPattern = nil
                } else if let repeatPattern = request.repeatPattern {
                    task.repeatPattern = repeatPattern
                }
                task.updatedAt = request.updatedAt

                self.update(task, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAll { result in
            completion(result.map { tasks in
                tasks.filter { $0.parentTaskID == parentTaskID }
            })
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        legacyRepository.deleteTask(withId: id, completion: completion)
    }

    private static func applyQuery(_ query: TaskDefinitionQuery?, to tasks: [TaskDefinition]) -> [TaskDefinition] {
        guard let query else { return tasks }

        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if let sectionID = query.sectionID, task.sectionID != sectionID { return false }
            if let parentTaskID = query.parentTaskID, task.parentTaskID != parentTaskID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart {
                guard let dueDate = task.dueDate, dueDate >= start else { return false }
            }
            if let end = query.dueDateEnd {
                guard let dueDate = task.dueDate, dueDate <= end else { return false }
            }
            if let updatedAfter = query.updatedAfter, task.updatedAt < updatedAfter { return false }
            if let searchText = query.searchText?.trimmingCharacters(in: .whitespacesAndNewlines), searchText.isEmpty == false {
                let needle = searchText.lowercased()
                let inTitle = task.title.lowercased().contains(needle)
                let inDetails = task.details?.lowercased().contains(needle) ?? false
                if !inTitle && !inDetails { return false }
            }
            return true
        }

        let offset = max(0, query.offset ?? 0)
        let limit = max(1, query.limit ?? filtered.count)
        let start = min(offset, filtered.count)
        let end = min(start + limit, filtered.count)
        return Array(filtered[start..<end])
    }
}

private final class LegacyNoopLifeAreaRepository: LifeAreaRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) { completion(.success([])) }
    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopSectionRepository: SectionRepositoryProtocol {
    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) { completion(.success([])) }
    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTagRepository: TagRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) { completion(.success([])) }
    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) { completion(.success(tag)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) { completion(.success([])) }
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) { completion(.success([])) }
    func replaceDependencies(taskID: UUID, dependencies: [TaskDependencyLinkDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopHabitRepository: HabitRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) { completion(.success([])) }
    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    func fetchAgendaHabits(for date: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) { completion(.success([])) }
    func fetchHistory(habitIDs: [UUID], endingOn date: Date, dayCount: Int, completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void) { completion(.success([])) }
    func fetchSignals(start: Date, end: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) { completion(.success([])) }
    func fetchHabitLibrary(includeArchived: Bool, completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void) { completion(.success([])) }
}

private final class LegacyNoopScheduleRepository: ScheduleRepositoryProtocol {
    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) { completion(.success(template)) }
    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func replaceRules(templateID: UUID, rules: [ScheduleRuleDefinition], completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success(rules)) }
    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) { completion(.success([])) }
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) { completion(.success(exception)) }
}

private final class LegacyNoopSchedulingEngine: SchedulingEngineProtocol {
    func generateOccurrences(windowStart: Date, windowEnd: Date, sourceFilter: ScheduleSourceType?, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func resolveOccurrence(id: UUID, resolution: OccurrenceResolutionType, actor: OccurrenceActor, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func applyScheduleException(templateID: UUID, occurrenceKey: String, action: ScheduleExceptionAction, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopOccurrenceRepository: OccurrenceRepositoryProtocol {
    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTombstoneRepository: TombstoneRepositoryProtocol {
    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopReminderRepository: ReminderRepositoryProtocol {
    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) { completion(.success([])) }
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) { completion(.success(reminder)) }
    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) { completion(.success(trigger)) }
    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) { completion(.success([])) }
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
}

private final class LegacyNoopWeeklyPlanRepository: WeeklyPlanRepositoryProtocol {
    func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) { completion(.success(nil)) }
    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) { completion(.success(nil)) }
    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void) { completion(.success([])) }
    func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void) { completion(.success(plan)) }
}

private final class LegacyNoopWeeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol {
    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) { completion(.success([])) }
    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void) { completion(.success(outcome)) }
    func replaceOutcomes(weeklyPlanID: UUID, outcomes: [WeeklyOutcome], completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) { completion(.success(outcomes)) }
    func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopWeeklyReviewRepository: WeeklyReviewRepositoryProtocol {
    func fetchReview(weeklyPlanID: UUID, completion: @escaping (Result<WeeklyReview?, Error>) -> Void) { completion(.success(nil)) }
    func saveReview(_ review: WeeklyReview, completion: @escaping (Result<WeeklyReview, Error>) -> Void) { completion(.success(review)) }
}

private final class LegacyNoopWeeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        completion(.failure(NSError(domain: "LegacyNoopWeeklyReviewMutationRepository", code: 1)))
    }
}

private final class LegacyNoopWeeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol {
    func fetchDraft(weekStartDate: Date, completion: @escaping (Result<WeeklyReviewDraft?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveDraft(_ draft: WeeklyReviewDraft, completion: @escaping (Result<WeeklyReviewDraft, Error>) -> Void) {
        completion(.success(draft))
    }

    func clearDraft(weekStartDate: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success(decisions))
    }
}

private final class LegacyNoopReflectionNoteRepository: ReflectionNoteRepositoryProtocol {
    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping (Result<[ReflectionNote], Error>) -> Void) { completion(.success([])) }
    func saveNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void) { completion(.success(note)) }
    func deleteNote(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopGamificationRepository: GamificationRepositoryProtocol {
    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) { completion(.success([])) }
}

private final class LegacyNoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class LegacyNoopExternalSyncRepository: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

extension GetHomeFilteredTasksUseCase {
    convenience init(taskRepository: LegacyTaskRepositoryShim) {
        let readModel = (taskRepository as? TaskReadModelRepositoryProtocol)
            ?? ShimTaskReadModelAdapter(legacyRepository: taskRepository)
        self.init(readModelRepository: readModel)
    }
}

extension UseCaseCoordinator {
    convenience init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.init(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            gamificationRepository: LegacyNoopGamificationRepository(),
            cacheService: cacheService,
            notificationService: notificationService
        )
    }

    convenience init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        gamificationRepository: GamificationRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        let readModel = (taskRepository as? TaskReadModelRepositoryProtocol)
            ?? ShimTaskReadModelAdapter(legacyRepository: taskRepository)
        let taskDefinitionRepository = ShimTaskDefinitionRepositoryAdapter(legacyRepository: taskRepository)

        let v2Dependencies = V2Dependencies(
            projectRepository: projectRepository,
            lifeAreaRepository: LegacyNoopLifeAreaRepository(),
            sectionRepository: LegacyNoopSectionRepository(),
            tagRepository: LegacyNoopTagRepository(),
            taskDefinitionRepository: taskDefinitionRepository,
            taskTagLinkRepository: LegacyNoopTaskTagLinkRepository(),
            taskDependencyRepository: LegacyNoopTaskDependencyRepository(),
            habitRepository: LegacyNoopHabitRepository(),
            habitRuntimeReadRepository: LegacyNoopHabitRuntimeReadRepository(),
            scheduleRepository: LegacyNoopScheduleRepository(),
            scheduleEngine: LegacyNoopSchedulingEngine(),
            occurrenceRepository: LegacyNoopOccurrenceRepository(),
            tombstoneRepository: LegacyNoopTombstoneRepository(),
            reminderRepository: LegacyNoopReminderRepository(),
            weeklyPlanRepository: LegacyNoopWeeklyPlanRepository(),
            weeklyOutcomeRepository: LegacyNoopWeeklyOutcomeRepository(),
            weeklyReviewRepository: LegacyNoopWeeklyReviewRepository(),
            weeklyReviewMutationRepository: LegacyNoopWeeklyReviewMutationRepository(),
            weeklyReviewDraftStore: LegacyNoopWeeklyReviewDraftStore(),
            dailyReflectionStore: UserDefaultsDailyReflectionStore(
                defaults: UserDefaults(suiteName: "UseCaseCoordinatorTests.\(UUID().uuidString)") ?? .standard
            ),
            reflectionNoteRepository: LegacyNoopReflectionNoteRepository(),
            gamificationRepository: gamificationRepository,
            assistantActionRepository: LegacyNoopAssistantActionRepository(),
            externalSyncRepository: LegacyNoopExternalSyncRepository(),
            remindersProvider: nil
        )

        self.init(
            taskReadModelRepository: readModel,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: v2Dependencies
        )
    }
}

class To_Do_ListTests: XCTestCase {

    func testUpdateTaskUseCaseUpdatesProjectIDAndNameWhenProjectIDProvided() {
        let inbox = Project.createInbox()
        let workProject = Project(id: UUID(), name: "Work")
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox, workProject])
        let useCase = LocalTaskUpdateUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "project update")
        useCase.execute(
            taskId: initialTask.id,
            request: LegacyTaskUpdatePayload(projectID: workProject.id)
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.projectID, workProject.id)
                XCTAssertEqual(updated.projectName, workProject.name)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePreservesExplicitTypeWhenDueDateAlsoChanges() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .evening,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let futureDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = LocalTaskUpdateUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "type precedence update")
        useCase.execute(
            taskId: initialTask.id,
            request: LegacyTaskUpdatePayload(
                dueDate: futureDate,
                type: .morning
            )
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.type, .morning, "Explicit type should win over due-date auto-type")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePostsTaskUpdatedNotification() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Old Name",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = LocalTaskUpdateUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let notificationExpectation = expectation(description: "TaskUpdated notification")
        let token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }

        useCase.execute(
            taskId: initialTask.id,
            request: LegacyTaskUpdatePayload(name: "New Name")
        ) { _ in }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(taskRepository.currentTask.title, "New Name")
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformanceExample() {
        self.measure {
            _ = UUID().uuidString
        }
    }
}

final class ArchitectureBoundaryTests: XCTestCase {
    private static let legacySingletonRegex = try! NSRegularExpression(
        pattern: "(^|[^A-Za-z0-9_])DependencyContainer\\.shared\\b"
    )

    private static let legacyScreenRegex = try! NSRegularExpression(
        pattern: "\\bNAddTaskScreen\\b"
    )

    func testViewLayerDoesNotUseSingletonDependencyContainers() throws {
        let directories = [
            "To Do List/View",
            "To Do List/Views",
            "To Do List/ViewControllers"
        ]
        let forbiddenPatterns = [
            "PresentationDependencyContainer.shared",
            "EnhancedDependencyContainer.shared"
        ]

        for directory in directories {
            let files = try listSwiftFiles(in: directory)
            for fileURL in files {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for pattern in forbiddenPatterns {
                    XCTAssertFalse(
                        content.contains(pattern),
                        "View-layer file must not reference singleton container `\(pattern)`: \(fileURL.path)"
                    )
                }
            }
        }
    }

    func testTargetedViewsDoNotAccessEnhancedDependencyContainerSingleton() throws {
        let files = [
            "To Do List/Views/Cards/ChartCard.swift",
            "To Do List/Views/Cards/RadarChartCard.swift",
            "To Do List/Views/ProjectSelectionSheet.swift",
            "To Do List/View/AddTaskForedropView.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared"),
                "View file must not access EnhancedDependencyContainer.shared directly: \(relativePath)"
            )
        }
    }

    func testTargetedControllersDoNotFallbackToEnhancedCoordinatorSingleton() throws {
        let files = [
            "To Do List/ViewControllers/HomeViewController.swift",
            "To Do List/ViewControllers/NewProjectViewController.swift",
            "To Do List/ViewControllers/LGSearchViewController.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared.useCaseCoordinator"),
                "Controller must not fallback to global coordinator singleton: \(relativePath)"
            )
        }
    }

    func testMainStoryboardDoesNotContainLegacyAddTaskScene() throws {
        let storyboard = try loadWorkspaceFile("To Do List/Storyboards/Base.lproj/Main.storyboard")
        XCTAssertFalse(storyboard.contains("storyboardIdentifier=\"addTask\""))
        XCTAssertFalse(storyboard.contains("addTaskLegacy_unreachable"))
        XCTAssertFalse(storyboard.contains("customClass=\"NAddTaskScreen\""))
    }

    func testProjectBuildGraphExcludesLegacyAddTaskRuntimeSources() throws {
        let projectFile = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")
        XCTAssertFalse(projectFile.contains("/* NAddTaskScreen.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* DependencyContainer.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* AddTaskLegacyStubs.swift in Sources */"))
    }

    func testProjectBuildGraphExcludesHandwrittenCoreDataPropertiesFromSources() throws {
        let projectFile = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")
        XCTAssertFalse(projectFile.contains("/* TaskDefinitionEntity+CoreDataProperties.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* ProjectEntity+CoreDataProperties.swift in Sources */"))
    }

    func testPrimaryRuntimeFilesDoNotReferenceLegacyDependencyContainerSingleton() throws {
        let runtimeFiles = [
            "To Do List/AppDelegate.swift",
            "To Do List/SceneDelegate.swift",
            "To Do List/Presentation/DI/PresentationDependencyContainer.swift",
            "To Do List/State/DI/EnhancedDependencyContainer.swift",
            "To Do List/UseCases/Coordinator/UseCaseCoordinator.swift"
        ]

        for relativePath in runtimeFiles {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                Self.matches(Self.legacySingletonRegex, in: content),
                "Primary runtime file must not reference legacy DependencyContainer singleton: \(relativePath)"
            )
            XCTAssertFalse(
                Self.matches(Self.legacyScreenRegex, in: content),
                "Primary runtime file must not reference legacy NAddTaskScreen route: \(relativePath)"
            )
        }
    }

    func testLegacySingletonRegexDoesNotFalseMatchV2Singletons() {
        XCTAssertTrue(Self.matches(Self.legacySingletonRegex, in: "DependencyContainer.shared.inject(into: vc)"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "PresentationDependencyContainer.shared.configureFromStateLayer()"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "EnhancedDependencyContainer.shared.configure(with: container)"))
        XCTAssertTrue(Self.matches(Self.legacyScreenRegex, in: "NAddTaskScreen()"))
    }

    func testLegacyGuardrailValidationScriptExistsAndIsExecutable() {
        let scriptURL = workspaceRootURL().appendingPathComponent("scripts/validate_legacy_runtime_guardrails.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    func testCoreDataCodegenGuardrailValidationScriptExistsAndIsExecutable() {
        let scriptURL = workspaceRootURL().appendingPathComponent("scripts/validate_coredata_codegen_guardrails.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    func testProjectAndRescheduleUseCasesDoNotPostNotificationCenterDirectly() throws {
        let files = [
            "To Do List/UseCases/Project/ManageProjectsUseCase.swift",
            "To Do List/UseCases/Task/RescheduleTaskDefinitionUseCase.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "Use case must emit via TaskNotificationDispatcher: \(relativePath)"
            )
        }
    }

    func testChartAndProjectSelectionViewsDoNotPublishDirectShowProjectManagementNotifications() throws {
        let files = [
            "To Do List/Views/Cards/ChartCardsScrollView.swift",
            "To Do List/Views/ProjectSelectionSheet.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("ShowProjectManagement"),
                "View should use injected callback, not broadcast notification: \(relativePath)"
            )
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "View should not post direct notifications for project management routing: \(relativePath)"
            )
        }
    }

    func testViewsDirectoryDoesNotDeclarePresentationViewModelTypes() throws {
        let forbiddenDeclarations = [
            "class ChartCardViewModel",
            "class RadarChartCardViewModel",
            "class ProjectSelectionViewModel"
        ]

        let files = try listSwiftFiles(in: "To Do List/Views")
        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for forbidden in forbiddenDeclarations {
                XCTAssertFalse(
                    content.contains(forbidden),
                    "View files must not declare presentation view models: \(fileURL.path)"
                )
            }
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let workspaceRoot = workspaceRootURL()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }

    private func listSwiftFiles(in relativeDirectory: String) throws -> [URL] {
        let root = workspaceRootURL().appendingPathComponent(relativeDirectory)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            let values = try item.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(item)
            }
        }
        return files
    }

    private func workspaceRootURL() -> URL {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        return testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func matches(_ regex: NSRegularExpression, in content: String) -> Bool {
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.firstMatch(in: content, range: range) != nil
    }
}

final class LaunchResilienceTests: XCTestCase {
    func testMakeLaunchRootModeReturnsHomeWhenStateReady() {
        let delegate = AppDelegate()
        let container = NSPersistentCloudKitContainer(
            name: "TaskModelV3",
            managedObjectModel: NSManagedObjectModel()
        )

        let mode = delegate.makeLaunchRootMode(state: .ready(container))
        XCTAssertEqual(mode, .home)
    }

    func testMakeLaunchRootModeReturnsFailureMessageWhenStateFailed() {
        let delegate = AppDelegate()
        let expectedMessage = "bootstrap failed"
        let mode = delegate.makeLaunchRootMode(state: .failed(expectedMessage))

        guard case let .bootstrapFailure(message) = mode else {
            XCTFail("Expected bootstrapFailure mode")
            return
        }
        XCTAssertEqual(message, expectedMessage)
    }

    func testTryInjectDoesNotCrashWhenContainerMayBeUnconfigured() {
        let dependencyContainer = PresentationDependencyContainer.shared
        let injected = dependencyContainer.tryInject(into: UIViewController())
        XCTAssertEqual(injected, dependencyContainer.isConfiguredForRuntime)
    }
}

final class GamificationRemoteChangeClassifierTests: XCTestCase {
    func testClassifiesCloudKitImportTransactions() {
        XCTAssertTrue(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "com.apple.coredata.cloudkit.import",
                contextName: "NSCloudKitMirroringDelegate.import"
            )
        )
    }

    func testRejectsNonImportOrNonCloudKitTransactions() {
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "tasker.gamification.local",
                contextName: "home.update"
            )
        )
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "com.apple.coredata.cloudkit.export",
                contextName: "NSCloudKitMirroringDelegate.export"
            )
        )
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: nil,
                contextName: nil
            )
        )
    }
}

final class TaskDefinitionLinkHydrationTests: XCTestCase {
    func testFetchHydratesTagAndDependencyLinksFromLinkTables() throws {
        let container = try makeInMemoryV2Container()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let tagLinkRepository = CoreDataTaskTagLinkRepository(container: container)
        let dependencyRepository = CoreDataTaskDependencyRepository(container: container)

        let taskID = UUID()
        let projectID = UUID()
        let compatibilityTag = UUID()
        let compatibilityDependency = UUID()
        let linkedTag = UUID()
        let linkedDependency = UUID()

        _ = try awaitResult { completion in
            taskRepository.create(
                request: CreateTaskDefinitionRequest(
                    id: taskID,
                    title: "Hydration Candidate",
                    details: "Initial compatibility values",
                    projectID: projectID,
                    projectName: "Inbox",
                    dueDate: nil,
                    tagIDs: [compatibilityTag],
                    dependencies: [
                        TaskDependencyLinkDefinition(
                            taskID: taskID,
                            dependsOnTaskID: compatibilityDependency,
                            kind: .related
                        )
                    ],
                    createdAt: Date()
                ),
                completion: completion
            )
        }

        _ = try awaitResult { completion in
            tagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: [linkedTag], completion: completion)
        }
        _ = try awaitResult { completion in
            dependencyRepository.replaceDependencies(
                taskID: taskID,
                dependencies: [
                    TaskDependencyLinkDefinition(
                        taskID: taskID,
                        dependsOnTaskID: linkedDependency,
                        kind: .blocks
                    )
                ],
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let task = try XCTUnwrap(fetched)

        XCTAssertEqual(task.tagIDs, [linkedTag], "Read-side tags must hydrate from TaskTagLink rows")
        XCTAssertEqual(task.dependencies.count, 1)
        XCTAssertEqual(task.dependencies.first?.dependsOnTaskID, linkedDependency)
        XCTAssertEqual(task.dependencies.first?.kind, .blocks)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskDefinitionLinkHydrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class DeterministicFetchTests: XCTestCase {
    func testTaskDefinitionFetchByIDUsesStableSelectionOrderWithDuplicateRows() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                taskID: taskID,
                projectID: projectID,
                title: "Canonical Alpha",
                createdAt: now
            )
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                taskID: taskID,
                projectID: projectID,
                title: "Duplicate Beta",
                createdAt: now.addingTimeInterval(1)
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let first = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let second = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }

        XCTAssertEqual(first?.title, "Canonical Alpha")
        XCTAssertEqual(second?.title, "Canonical Alpha")
    }

    func testTaskDefinitionFetchAllDoesNotCrashWithoutLegacyCompatibilityAttributes() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                taskID: taskID,
                projectID: projectID,
                title: "No Legacy Compatibility Keys",
                createdAt: now
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let fetched = try awaitResult { completion in
            repository.fetchAll(query: nil, completion: completion)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, taskID)
        XCTAssertEqual(fetched.first?.tagIDs, [])
        XCTAssertEqual(fetched.first?.dependencies, [])
    }

    func testTaskDefinitionSchemaContractIncludesLifeAreaIDAndExcludesLegacyTagsAttribute() throws {
        let container = try makeInMemoryV2Container()
        guard let taskDefinition = container.managedObjectModel.entitiesByName["TaskDefinition"] else {
            XCTFail("TaskDefinition entity missing from model")
            return
        }

        XCTAssertNotNil(taskDefinition.attributesByName["taskID"])
        XCTAssertNotNil(taskDefinition.attributesByName["projectID"])
        XCTAssertNotNil(taskDefinition.attributesByName["lifeAreaID"])
        XCTAssertNil(taskDefinition.attributesByName["tags"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["tagLinks"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["dependencies"])
    }

    func testTaskDefinitionEntityExposesLifeAreaIDManagedAccessor() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var taskObject: TaskDefinitionEntity?
        context.performAndWait {
            taskObject = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context) as? TaskDefinitionEntity
        }

        guard let taskObject else {
            XCTFail("Unable to create TaskDefinitionEntity from model")
            return
        }

        let getter = NSSelectorFromString("lifeAreaID")
        let setter = NSSelectorFromString("setLifeAreaID:")
        XCTAssertTrue(taskObject.responds(to: getter), "TaskDefinitionEntity must expose lifeAreaID getter")
        XCTAssertTrue(taskObject.responds(to: setter), "TaskDefinitionEntity must expose lifeAreaID setter")

        let expected = UUID()
        taskObject.setValue(expected, forKey: "lifeAreaID")
        XCTAssertEqual(taskObject.value(forKey: "lifeAreaID") as? UUID, expected)
    }

    func testTaskDefinitionModelAttributeSelectorParity() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var taskObject: TaskDefinitionEntity?
        context.performAndWait {
            taskObject = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context) as? TaskDefinitionEntity
        }

        guard let taskObject else {
            XCTFail("Unable to create TaskDefinitionEntity from model")
            return
        }

        assertManagedAttributeSelectorsPresent(
            entityName: "TaskDefinition",
            object: taskObject,
            model: container.managedObjectModel
        )
    }

    func testProjectModelAttributeSelectorParity() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var projectObject: ProjectEntity?
        context.performAndWait {
            projectObject = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context) as? ProjectEntity
        }

        guard let projectObject else {
            XCTFail("Unable to create ProjectEntity from model")
            return
        }

        assertManagedAttributeSelectorsPresent(
            entityName: "Project",
            object: projectObject,
            model: container.managedObjectModel
        )
    }

    func testExternalContainerFetchUsesDeterministicFirstRowOrdering() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let context = container.viewContext
        let provider = "apple_reminders"
        let projectID = UUID()

        var seedError: Error?
        context.performAndWait {
            let first = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            first.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, forKey: "id")
            first.setValue(provider, forKey: "provider")
            first.setValue(projectID, forKey: "projectID")
            first.setValue("first-container", forKey: "externalContainerID")
            first.setValue(true, forKey: "syncEnabled")
            first.setValue(Date(), forKey: "createdAt")

            let second = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            second.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, forKey: "id")
            second.setValue(provider, forKey: "provider")
            second.setValue(projectID, forKey: "projectID")
            second.setValue("second-container", forKey: "externalContainerID")
            second.setValue(true, forKey: "syncEnabled")
            second.setValue(Date(), forKey: "createdAt")

            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let firstRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }
        let secondRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }

        XCTAssertEqual(firstRead?.externalContainerID, "first-container")
        XCTAssertEqual(secondRead?.externalContainerID, "first-container")
    }

    private func seedTaskDefinitionRow(
        in context: NSManagedObjectContext,
        rowID: UUID,
        taskID: UUID,
        projectID: UUID,
        title: String,
        createdAt: Date
    ) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(rowID, forKey: "id")
        object.setValue(taskID, forKey: "taskID")
        object.setValue(projectID, forKey: "projectID")
        object.setValue(title, forKey: "title")
        object.setValue(nil, forKey: "notes")
        object.setValue(Int32(TaskPriority.low.rawValue), forKey: "priority")
        object.setValue(Int32(TaskType.morning.rawValue), forKey: "taskType")
        object.setValue(false, forKey: "isComplete")
        object.setValue(createdAt, forKey: "dateAdded")
        object.setValue(false, forKey: "isEveningTask")
        object.setValue("pending", forKey: "status")
        object.setValue(nil, forKey: "lifeAreaID")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(createdAt, forKey: "updatedAt")
        object.setValue(Int32(1), forKey: "version")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "DeterministicFetchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func assertManagedAttributeSelectorsPresent(
        entityName: String,
        object: NSManagedObject,
        model: NSManagedObjectModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let entity = model.entitiesByName[entityName] else {
            XCTFail("Missing entity in managed object model: \(entityName)", file: file, line: line)
            return
        }

        for attributeName in entity.attributesByName.keys.sorted() {
            let getter = NSSelectorFromString(attributeName)
            XCTAssertTrue(
                object.responds(to: getter),
                "Missing getter selector \(attributeName) on \(entityName) managed object",
                file: file,
                line: line
            )

            let setter = NSSelectorFromString("set\(attributeName.prefix(1).uppercased())\(attributeName.dropFirst()):")
            XCTAssertTrue(
                object.responds(to: setter),
                "Missing setter selector \(setter.description) for \(attributeName) on \(entityName) managed object",
                file: file,
                line: line
            )
        }
    }
}

final class OccurrenceKeyCodecTests: XCTestCase {
    func testCanonicalRoundTrip() {
        let templateID = UUID()
        let sourceID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_705_000_000)
        let encoded = OccurrenceKeyCodec.encode(
            scheduleTemplateID: templateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
        let parsed = OccurrenceKeyCodec.parse(encoded)
        XCTAssertEqual(parsed?.scheduleTemplateID, templateID)
        XCTAssertEqual(parsed?.sourceID, sourceID)
        XCTAssertEqual(parsed?.scheduledAt.timeIntervalSince1970 ?? 0, scheduledAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(parsed?.isCanonical, true)
    }

    func testLegacyKeyParsesAndCanonicalizesWithFallbackSource() {
        let templateID = UUID()
        let sourceID = UUID()
        let legacy = "\(templateID.uuidString)_2026-01-02T09:30"
        let canonical = OccurrenceKeyCodec.canonicalize(
            legacy,
            fallbackTemplateID: templateID,
            fallbackSourceID: sourceID
        )
        XCTAssertNotNil(canonical)
        XCTAssertTrue(canonical?.contains(sourceID.uuidString) ?? false)
    }

    func testMalformedKeyRejected() {
        XCTAssertNil(OccurrenceKeyCodec.parse("not-a-valid-key"))
        XCTAssertNil(
            OccurrenceKeyCodec.canonicalize(
                "bad-key",
                fallbackTemplateID: UUID(),
                fallbackSourceID: UUID()
            )
        )
    }
}

final class FeatureFlagKillSwitchTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true
    private var originalRemindersBackgroundRefreshEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        originalRemindersBackgroundRefreshEnabled = V2FeatureFlags.remindersBackgroundRefreshEnabled
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        V2FeatureFlags.remindersBackgroundRefreshEnabled = originalRemindersBackgroundRefreshEnabled
        super.tearDown()
    }

    func testReconcileExternalRemindersFailsClosedWhenSyncFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = false

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: NoopExternalSyncRepository()
        )

        let expectation = expectation(description: "reconcile-disabled")
        useCase.execute { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantApplyFailsClosedWhenApplyFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantApplyEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-apply-disabled")
        useCase.applyConfirmedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantUndoFailsClosedWhenUndoFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantUndoEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-undo-disabled")
        useCase.undoAppliedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testBackgroundRefreshFlagCanFailClosed() throws {
        V2FeatureFlags.remindersBackgroundRefreshEnabled = false
        XCTAssertFalse(V2FeatureFlags.remindersBackgroundRefreshEnabled)

        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("V2FeatureFlags.remindersBackgroundRefreshEnabled"),
            "AppDelegate must gate reminders refresh with remindersBackgroundRefreshEnabled"
        )
    }

    func testPersistentStoreDescriptionsEnableAutomaticMigrationOptions() throws {
        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("cloudDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)"),
            "Cloud store description must enable automatic migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("cloudDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)"),
            "Cloud store description must enable inferred mapping migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)"),
            "Local store description must enable automatic migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)"),
            "Local store description must enable inferred mapping migration"
        )
    }

    func testGamificationStartupReconciliationFailureIsHandledBeforeFollowups() throws {
        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("gamification_startup_reconciliation_failed"),
            "Startup path must log reconciliation failures explicitly"
        )
        XCTAssertTrue(
            appDelegateSource.contains("gamification_startup_streak_update_failed"),
            "Startup path must log follow-up streak update failures"
        )
        let writeSnapshotRange = appDelegateSource.range(of: "engine.writeWidgetSnapshot()")
        let updateStreakRange = appDelegateSource.range(of: "engine.updateStreak { streakResult in")
        XCTAssertNotNil(writeSnapshotRange, "Startup path must write widget snapshot after reconciliation")
        XCTAssertNotNil(updateStreakRange, "Startup path must update streak after successful reconciliation")
        if let writeSnapshotRange, let updateStreakRange {
            XCTAssertLessThan(
                writeSnapshotRange.lowerBound,
                updateStreakRange.lowerBound,
                "Startup path must sequence writeWidgetSnapshot before updateStreak"
            )
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

final class TaskListWidgetSourceContractTests: XCTestCase {
    func testSceneDelegateRestrictsTaskScopesToDocumentedRoutes() throws {
        let source = try loadWorkspaceFile("To Do List/SceneDelegate.swift")
        XCTAssertTrue(
            source.contains("let allowedScopes: Set<String> = [\"today\", \"upcoming\", \"overdue\"]"),
            "SceneDelegate must restrict task scopes to today/upcoming/overdue."
        )
        XCTAssertFalse(
            source.contains("queryItems"),
            "SceneDelegate should not parse URL query mutations for widget routing."
        )
    }

    func testWidgetBundleDoesNotUseActionQueryDeepLinks() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        XCTAssertFalse(
            source.contains("?action="),
            "Widget intents must not rely on URL query mutation actions."
        )
    }

    func testSceneDelegateRegistersHabitDeepLinkRoutes() throws {
        let source = try loadWorkspaceFile("To Do List/SceneDelegate.swift")
        XCTAssertTrue(source.contains("if host == \"habits\""))
        XCTAssertTrue(source.contains("if host == \"habit\""))
        XCTAssertTrue(source.contains("taskerOpenHabitBoardDeepLink"))
        XCTAssertTrue(source.contains("taskerOpenHabitLibraryDeepLink"))
        XCTAssertTrue(source.contains("taskerOpenHabitDetailDeepLink"))
    }

    func testSceneDelegateRegistersWeeklyDeepLinkRoutesAndFallbackNotice() throws {
        let source = try loadWorkspaceFile("To Do List/SceneDelegate.swift")
        XCTAssertTrue(source.contains("if host == \"weekly\""))
        XCTAssertTrue(source.contains("taskerOpenWeeklyPlannerDeepLink"))
        XCTAssertTrue(source.contains("taskerOpenWeeklyReviewDeepLink"))
        XCTAssertTrue(source.contains("That weekly destination is unavailable. Opened Home instead."))
    }

    func testWeekTaskPlannerWidgetRoutesToWeeklyPlannerDeepLink() throws {
        let routesSource = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        XCTAssertTrue(routesSource.contains("static var weeklyPlanner: URL { URL(string: \"tasker://weekly/planner\")! }"))

        let widgetSource = try loadWorkspaceFile("TaskerWidgets/TaskWidgetHomeViews.swift")
        XCTAssertTrue(widgetSource.contains(".widgetURL(TaskWidgetRoutes.weeklyPlanner)"))
    }

    func testWeeklyPlanningScreensRenderLoadingAndRetryContracts() throws {
        let plannerSource = try loadWorkspaceFile("To Do List/View/WeeklyPlannerView.swift")
        XCTAssertTrue(plannerSource.contains("WeeklyBlockingStateCard("))
        XCTAssertTrue(plannerSource.contains("primaryActionTitle: \"Retry\""))

        let reviewSource = try loadWorkspaceFile("To Do List/View/WeeklyReviewView.swift")
        XCTAssertTrue(reviewSource.contains("WeeklyReviewBlockingStateCard("))
        XCTAssertTrue(reviewSource.contains("primaryActionTitle: \"Retry\""))

        let cardSource = try loadWorkspaceFile("To Do List/View/HomeWeeklySummaryCard.swift")
        XCTAssertTrue(cardSource.contains("isLoading"))
        XCTAssertTrue(cardSource.contains("errorMessage"))
        XCTAssertTrue(cardSource.contains("Retry"))
    }

    func testWidgetBundleRegistersFullTaskListCatalogKinds() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        let expectedKinds = [
            "TopTaskNowWidget", "TodayCounterNextWidget", "OverdueRescueWidget", "QuickWin15mWidget",
            "MorningKickoffWidget", "EveningWrapWidget", "WaitingOnWidget", "InboxTriageWidget",
            "DueSoonRadarWidget", "EnergyMatchWidget", "ProjectSpotlightWidget", "CalendarTaskBridgeWidget",
            "TodayTop3Widget", "NowLaneWidget", "OverdueBoardWidget", "Upcoming48hWidget",
            "MorningEveningPlanWidget", "QuickViewSwitcherWidget", "ProjectSprintWidget",
            "PriorityMatrixLiteWidget", "ContextWidget", "FocusSessionQueueWidget",
            "RecoveryWidget", "DoneReflectionWidget",
            "TodayPlannerBoardWidget", "WeekTaskPlannerWidget", "ProjectCockpitWidget",
            "BacklogHealthWidget", "KanbanLiteWidget", "DeadlineHeatmapWidget",
            "ExecutionDashboardWidget", "DeepWorkAgendaWidget", "AssistantPlanPreviewWidget",
            "LifeAreasBoardWidget",
            "InlineNextTaskWidget", "InlineDueSoonWidget",
            "CircularTodayProgressWidget", "CircularQuickAddWidget",
            "RectangularTop2TasksWidget", "RectangularOverdueAlertWidget",
            "RectangularFocusNowWidget", "RectangularWaitingOnWidget",
            "DeskTodayBoardWidget", "CountdownPanelWidget", "FocusDockWidget",
            "NightlyResetWidget", "MorningBriefPanelWidget", "ProjectPulseWidget"
        ]

        for kind in expectedKinds {
            XCTAssertTrue(
                source.contains("kind: \"\(kind)\""),
                "Widget bundle must include kind \(kind)."
            )
        }
    }

    func testWidgetBundleHasNonEmptyDisplayMetadata() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        XCTAssertFalse(source.contains("displayName: \"\""))
        XCTAssertFalse(source.contains("description: \"\""))
    }

    func testRemoteKillSwitchMapsTaskWidgetFlags() throws {
        let source = try loadWorkspaceFile("To Do List/Services/GamificationRemoteKillSwitchService.swift")
        XCTAssertTrue(source.contains("feature_task_list_widgets_enabled"))
        XCTAssertTrue(source.contains("feature_task_list_widgets_interactive_enabled"))
        XCTAssertTrue(source.contains("V2FeatureFlags.taskListWidgetsEnabled"))
        XCTAssertTrue(source.contains("V2FeatureFlags.interactiveTaskWidgetsEnabled"))
    }

    func testWidgetTargetCompilesAgainstDesignSystemSources() throws {
        let project = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")

        XCTAssertTrue(project.contains("TaskerTokens.swift in Sources"))
        XCTAssertTrue(project.contains("TaskerTheme.swift in Sources"))
        XCTAssertTrue(project.contains("TaskerTheme+SwiftUI.swift in Sources"))
        XCTAssertTrue(project.contains("SwiftUI+TokenAdapters.swift in Sources"))
        XCTAssertTrue(project.contains("TaskerAnimations.swift in Sources"))
    }

    func testWidgetBrandBridgesToTaskerThemeRoles() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/WidgetBrand.swift")

        XCTAssertTrue(source.contains("TaskerTheme.Colors"))
        XCTAssertTrue(source.contains("Color.tasker("))
        XCTAssertFalse(source.contains("dynamic(light:"))
        XCTAssertFalse(source.contains("Color(hex:"))
    }

    func testWidgetFoundationDefinesWeightedContextAndAccessibilityPrimitives() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskWidgetFoundation.swift")

        XCTAssertTrue(source.contains("isStandByLike"))
        XCTAssertTrue(source.contains("isBackgroundRemoved"))
        XCTAssertTrue(source.contains("leadRatio"))
        XCTAssertTrue(source.contains("TaskWidgetPanelStyle"))
        XCTAssertTrue(source.contains("case flush"))
        XCTAssertTrue(source.contains("case softSection"))
        XCTAssertTrue(source.contains("case contained"))
        XCTAssertTrue(source.contains("compactWidthThreshold"))
        XCTAssertTrue(source.contains("taskWidgetAccentable(if:"))
        XCTAssertTrue(source.contains("accessibilityHidden(true)"))
    }

    func testInteractiveWidgetAffordancesRespectFeatureFlagAtRenderTime() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskWidgetHomeViews.swift")

        XCTAssertTrue(
            source.contains("if #available(iOSApplicationExtension 17.0, *), TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled"),
            "Interactive widget actions must be hidden when the kill switch is disabled."
        )
        XCTAssertTrue(
            source.contains("TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled ? \"Open\" : \"Review\""),
            "Fallback CTA copy should stay truthful when interactive task actions are disabled."
        )
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

final class TaskListWidgetSnapshotSchemaTests: XCTestCase {
    func testSnapshotV1PayloadDecodesWithBackwardCompatibleDefaults() throws {
        let json = """
        {
          "updatedAt": "2026-02-28T00:00:00Z",
          "todayTopTasks": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Legacy Task",
              "priorityCode": "P2",
              "isOverdue": false,
              "energy": "medium",
              "context": "anywhere",
              "isComplete": false,
              "hasDependencies": false
            }
          ],
          "upcomingTasks": [],
          "overdueTasks": [],
          "quickWins": [],
          "projectSlices": [],
          "doneTodayCount": 1,
          "focusNow": [],
          "waitingOn": [],
          "energyBuckets": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(TaskListWidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.todayTopTasks.count, 1)
        XCTAssertEqual(snapshot.openTodayCount, 1)
        XCTAssertTrue(snapshot.openTaskPool.isEmpty)
        XCTAssertTrue(snapshot.completedTodayTasks.isEmpty)
        XCTAssertEqual(snapshot.snapshotHealth.source, "full_query")
    }

    func testSnapshotV2RoundTripPreservesNewFields() throws {
        let now = Date()
        let task = TaskListWidgetTask(
            id: UUID(),
            title: "Round Trip",
            priorityCode: "P1",
            dueDate: now,
            isOverdue: false,
            estimatedDurationMinutes: 20,
            energy: "high",
            context: "computer",
            isComplete: false,
            hasDependencies: false
        )
        let snapshot = TaskListWidgetSnapshot(
            schemaVersion: TaskListWidgetSnapshot.currentSchemaVersion,
            updatedAt: now,
            todayTopTasks: [task],
            upcomingTasks: [],
            overdueTasks: [],
            quickWins: [],
            projectSlices: [],
            doneTodayCount: 2,
            focusNow: [task],
            waitingOn: [],
            energyBuckets: [TaskListWidgetEnergyBucket(energy: "high", count: 1)],
            openTodayCount: 3,
            openTaskPool: [task],
            completedTodayTasks: [],
            snapshotHealth: TaskListWidgetSnapshotHealth(
                source: "unit_test",
                generatedAt: now,
                isStale: false,
                hasCorruptionFallback: true
            )
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TaskListWidgetSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.schemaVersion, TaskListWidgetSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.openTodayCount, 3)
        XCTAssertEqual(decoded.openTaskPool.count, 1)
        XCTAssertEqual(decoded.snapshotHealth.source, "unit_test")
        XCTAssertTrue(decoded.snapshotHealth.hasCorruptionFallback)
    }
}

private final class NoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }
}

private final class NoopTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            title: request.title,
            details: request.details,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            scheduledStartAt: request.scheduledStartAt,
            scheduledEndAt: request.scheduledEndAt,
            isAllDay: request.isAllDay,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            estimatedDuration: request.estimatedDuration,
            repeatPattern: request.repeatPattern,
            planningBucket: request.planningBucket,
            weeklyOutcomeID: request.weeklyOutcomeID,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )))
    }
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "NoopTaskDefinitionRepository", code: 1)))
    }
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopExternalSyncRepository: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class MockTaskRepository: LegacyTaskRepositoryShim, TaskReadModelRepositoryProtocol {
    private var storedTask: Task
    private let lock = NSLock()

    var currentTask: Task { readStoredTask() }
    private(set) var fetchAllTasksCallCount = 0
    private(set) var readModelFetchCallCount = 0
    private(set) var readModelSearchCallCount = 0

    init(seed: Task) {
        self.storedTask = seed
    }

    private func readStoredTask() -> Task {
        lock.lock()
        defer { lock.unlock() }
        return storedTask
    }

    private func replaceStoredTask(with task: Task) {
        lock.lock()
        storedTask = task
        lock.unlock()
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasksCallCount += 1
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        readModelFetchCallCount += 1
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart, let dueDate = task.dueDate, dueDate < start { return false }
            if let end = query.dueDateEnd, let dueDate = task.dueDate, dueDate > end { return false }
            return true
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskDefinitionSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        readModelSearchCallCount += 1
        let normalized = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if normalized.isEmpty { return true }
            let nameMatch = task.title.lowercased().contains(normalized)
            let detailMatch = task.details?.lowercased().contains(normalized) ?? false
            return nameMatch || detailMatch
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskDefinitionSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        if includeCompleted || task.isComplete == false {
            completion(.success([task.projectID: 1]))
        } else {
            completion(.success([:]))
        }
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        guard
            task.isComplete,
            let completedAt = task.dateCompleted,
            completedAt >= startDate,
            completedAt <= endDate
        else {
            completion(.success([:]))
            return
        }
        completion(.success([task.projectID: task.priority.scorePoints]))
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.isComplete ? [task] : []))
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.type == type ? [task] : []))
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        let task = readStoredTask()
        DispatchQueue.main.async {
            completion(.success(task.id == id ? task : nil))
        }
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        DispatchQueue.main.async {
            completion(.success(task))
        }
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = true
        task.dateCompleted = Date()
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = false
        task.dateCompleted = nil
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.dueDate = date
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    private let projectsByID: [UUID: Project]

    init(projects: [Project]) {
        self.projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projectsByID[id]))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        let match = projectsByID.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        completion(.success(match))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        if var project = projectsByID[id] {
            project.name = newName
            completion(.success(project))
        } else {
            completion(.failure(NSError(domain: "MockProjectRepository", code: 404)))
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }
}

private final class CapturingHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    var agendaSummaries: [HabitOccurrenceSummary]
    var historyWindows: [HabitHistoryWindow]
    var signalSummaries: [HabitOccurrenceSummary]
    var libraryRows: [HabitLibraryRow]
    private(set) var fetchAgendaCallCount = 0
    private(set) var fetchSignalsCallCount = 0
    private(set) var fetchLibraryCallCount = 0

    init(
        agendaSummaries: [HabitOccurrenceSummary] = [],
        historyWindows: [HabitHistoryWindow] = [],
        signalSummaries: [HabitOccurrenceSummary] = [],
        libraryRows: [HabitLibraryRow] = []
    ) {
        self.agendaSummaries = agendaSummaries
        self.historyWindows = historyWindows
        self.signalSummaries = signalSummaries
        self.libraryRows = libraryRows
    }

    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        fetchAgendaCallCount += 1
        completion(.success(agendaSummaries))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        completion(.success(historyWindows))
    }

    func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        fetchSignalsCallCount += 1
        completion(.success(signalSummaries))
    }

    func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchLibraryCallCount += 1
        completion(.success(libraryRows))
    }
}

final class OccurrenceIdentityTests: XCTestCase {
    func testGeneratedOccurrenceKeyContainsTemplateScheduledDateAndSourceID() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01T00:00:00Z
        let start = now
        let end = Date(timeIntervalSince1970: 1_704_153_599) // 2024-01-01T23:59:59Z

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: start,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let generated = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: end,
                sourceFilter: nil,
                completion: completion
            )
        }

        XCTAssertEqual(generated.count, 1)
        let keyParts = generated[0].occurrenceKey.split(separator: "|").map(String.init)
        XCTAssertEqual(keyParts.count, 3)
        XCTAssertEqual(keyParts[0], templateID.uuidString)
        XCTAssertEqual(keyParts[2], sourceID.uuidString)

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: end,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Deterministic keying should prevent duplicate generation")
    }

    func testResolveDoesNotMutateOccurrenceKey() throws {
        let now = Date()
        let occurrence = OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "template|2026-01-01T09:00:00Z|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: now,
            dueAt: now,
            state: .pending,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: now,
            updatedAt: now
        )

        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [occurrence]
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        _ = try awaitResult { completion in
            engine.resolveOccurrence(
                id: occurrence.id,
                resolution: .completed,
                actor: .user,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(
                start: now.addingTimeInterval(-60),
                end: now.addingTimeInterval(60),
                completion: completion
            )
        }

        XCTAssertEqual(fetched.first?.occurrenceKey, occurrence.occurrenceKey)
    }
}

final class OccurrenceMaintenanceTests: XCTestCase {
    func testMaintenanceMarksStalePendingAsMissedAndPurgesResolvedIntoTombstones() throws {
        let now = Date()
        let stalePending = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -31, to: now) ?? now,
            state: .pending
        )
        let resolvedOld = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -91, to: now) ?? now,
            state: .completed
        )
        let recentCompleted = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
            state: .completed
        )

        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [stalePending, resolvedOld, recentCompleted]
        let tombstoneRepository = InMemoryTombstoneRepository()

        let useCase = MaintainOccurrencesUseCase(
            occurrenceRepository: occurrenceRepository,
            tombstoneRepository: tombstoneRepository
        )

        _ = try awaitResult { completion in
            useCase.execute(completion: completion)
        }

        let missedResolution = occurrenceRepository.resolutions.first {
            $0.occurrenceID == stalePending.id && $0.resolutionType == .missed
        }
        XCTAssertNotNil(missedResolution)

        XCTAssertTrue(occurrenceRepository.deletedOccurrenceIDs.contains(resolvedOld.id))
        XCTAssertFalse(occurrenceRepository.occurrences.contains(where: { $0.id == resolvedOld.id }))
        XCTAssertTrue(occurrenceRepository.occurrences.contains(where: { $0.id == recentCompleted.id }))
        XCTAssertTrue(tombstoneRepository.tombstones.contains(where: { $0.entityID == resolvedOld.id }))
    }

    private func makeOccurrence(scheduledAt: Date, state: OccurrenceState) -> OccurrenceDefinition {
        OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "\(UUID().uuidString)|\(scheduledAt.timeIntervalSince1970)|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: state,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: scheduledAt,
            updatedAt: scheduledAt
        )
    }
}

final class TombstoneRetentionTests: XCTestCase {
    func testExpiredTombstonesArePurged() throws {
        let now = Date()
        let expired = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now.addingTimeInterval(-10_000),
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(-100)
        )
        let retained = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now,
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(10_000)
        )

        let repository = InMemoryTombstoneRepository()
        repository.tombstones = [expired, retained]
        let useCase = PurgeExpiredTombstonesUseCase(tombstoneRepository: repository)

        _ = try awaitResult { completion in
            useCase.execute(referenceDate: now, completion: completion)
        }

        XCTAssertTrue(repository.deletedIDs.contains(expired.id))
        XCTAssertFalse(repository.deletedIDs.contains(retained.id))
        XCTAssertTrue(repository.tombstones.contains(where: { $0.id == retained.id }))
    }
}

final class V2RepositoryInvariantTests: XCTestCase {
    func testTaskTagLinkUniquenessRejectsDuplicateTaskTagPairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagA, tagB, tagA],
                completion: completion
            )
        }

        let savedTagIDs = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(savedTagIDs), Set([tagA, tagB]))
        XCTAssertEqual(savedTagIDs.count, 2)
    }

    func testExternalMapUpsertsStayDeterministicAcrossCompositeKeys() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)

        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "reminder-1"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)
        XCTAssertEqual(secondContainerMap.externalContainerID, "container-b")

        let firstItemMap = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let secondItemMap = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-1",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        XCTAssertEqual(firstItemMap.id, secondItemMap.id)

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "V2RepositoryInvariantTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class TaskTagLinkUniquenessTests: XCTestCase {
    func testDuplicateTaskTagLinksCollapseToUniquePairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagB, tagA, tagB, tagA],
                completion: completion
            )
        }

        let stored = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(stored), Set([tagA, tagB]))
        XCTAssertEqual(stored.count, 2)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskTagLinkUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ExternalMapUniquenessTests: XCTestCase {
    func testCompositeKeyUpsertsResolveToSingleCanonicalMap() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "external-map-\(UUID().uuidString)"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)

        _ = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }
        _ = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-42",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ExternalMapUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ScheduleExceptionRebuildTests: XCTestCase {
    func testSkipExceptionDeletesTargetOccurrenceWithoutMassSkippingFutureRows() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let windowEnd = Calendar.current.date(byAdding: .day, value: 2, to: dayStart) ?? dayStart

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: dayStart,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let initial = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertGreaterThanOrEqual(initial.count, 2, "Expected at least two occurrences in the generation window")
        let sortedInitial = initial.sorted { $0.scheduledAt < $1.scheduledAt }
        let target = try XCTUnwrap(sortedInitial.first)
        let unaffected = try XCTUnwrap(sortedInitial.dropFirst().first)

        _ = try awaitResult { completion in
            engine.applyScheduleException(
                templateID: templateID,
                occurrenceKey: target.occurrenceKey,
                action: .skip,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(start: dayStart, end: windowEnd, completion: completion)
        }

        let targetRows = fetched.filter { $0.occurrenceKey == target.occurrenceKey }
        XCTAssertTrue(targetRows.isEmpty, "Skipped occurrence should be removed and not recreated")

        let unaffectedRows = fetched.filter { $0.occurrenceKey == unaffected.occurrenceKey }
        XCTAssertEqual(unaffectedRows.count, 1, "Rebuild should preserve unaffected future occurrence identity")
        XCTAssertEqual(unaffectedRows.first?.state, .pending, "Rebuild must not mass-skip future unresolved occurrences")

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Exception rebuild should not recreate skipped occurrence with same key")
    }
}

final class ConcurrencyRaceTests: XCTestCase {
    func testConcurrentTagCreatesConvergeToSingleNormalizedRow() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTagRepository(container: container)
        let candidateNames = ["Work", "work", " WORK ", "WoRk"]
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            let name = candidateNames[index % candidateNames.count]
            repository.create(TagDefinition(id: UUID(), name: name)) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let tags = try awaitResult { completion in
            repository.fetchAll(completion: completion)
        }
        let normalizedMatches = tags.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "work"
        }
        XCTAssertEqual(normalizedMatches.count, 1)
    }

    func testConcurrentExternalMapUpsertsConvergeToSingleMapIdentity() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let localEntityID = UUID()
        let externalItemID = "race-item-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            if index.isMultiple(of: 2) {
                repository.upsertItemMappingByLocalKey(
                    provider: provider,
                    localEntityType: "task",
                    localEntityID: localEntityID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: nil,
                            lastSeenExternalModAt: nil,
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            } else {
                repository.upsertItemMappingByExternalKey(
                    provider: provider,
                    externalItemID: externalItemID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: "persist-\(index)",
                            lastSeenExternalModAt: Date(),
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    func testConcurrentXPEventSavesRespectIdempotencyUnderRace() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let idempotencyKey = "xp-race-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<20 {
            group.enter()
            let event = XPEventDefinition(
                id: UUID(),
                occurrenceID: nil,
                taskID: nil,
                delta: 10 + index,
                reason: "race-test",
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
            repository.saveXPEvent(event) { result in
                if case .failure(let error) = result {
                    if case GamificationRepositoryWriteError.idempotentReplay = error {
                        group.leave()
                        return
                    }
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let storedEvents = try awaitResult { completion in
            repository.fetchXPEvents(completion: completion)
        }
        let matches = storedEvents.filter { $0.idempotencyKey == idempotencyKey }
        XCTAssertEqual(matches.count, 1, "Race save should keep one canonical XP event per idempotency key")
    }

    func testSaveXPEventReturnsIdempotentReplayErrorForDuplicateKey() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let idempotencyKey = "xp-dup-\(UUID().uuidString)"

        let first = XPEventDefinition(
            id: UUID(),
            occurrenceID: nil,
            taskID: nil,
            delta: 12,
            reason: "duplicate-test",
            idempotencyKey: idempotencyKey,
            createdAt: Date()
        )
        let second = XPEventDefinition(
            id: UUID(),
            occurrenceID: nil,
            taskID: nil,
            delta: 18,
            reason: "duplicate-test",
            idempotencyKey: idempotencyKey,
            createdAt: Date()
        )

        try awaitResult { completion in
            repository.saveXPEvent(first, completion: completion)
        }

        let duplicateExpectation = expectation(description: "duplicate save result")
        var duplicateResult: Result<Void, Error>?
        repository.saveXPEvent(second) { result in
            duplicateResult = result
            duplicateExpectation.fulfill()
        }
        wait(for: [duplicateExpectation], timeout: 2.0)

        switch duplicateResult {
        case .success?:
            XCTFail("Expected duplicate save to return idempotent replay error")
        case .failure(let error)?:
            guard case GamificationRepositoryWriteError.idempotentReplay(let key) = error else {
                return XCTFail("Expected idempotent replay error, got \(error)")
            }
            XCTAssertEqual(key, idempotencyKey)
        case nil:
            XCTFail("Duplicate save did not complete")
        }

        let storedEvents = try awaitResult { completion in
            repository.fetchXPEvents(completion: completion)
        }
        XCTAssertEqual(storedEvents.filter { $0.idempotencyKey == idempotencyKey }.count, 1)
    }

    func testGamificationReadContextReturnsLatestAggregateImmediatelyAfterWrite() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let dateKey = XPCalculationEngine.periodKey()

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 12,
                    eventCount: 1,
                    updatedAt: Date()
                ),
                completion: completion
            )
        }

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 39,
                    eventCount: 2,
                    updatedAt: Date().addingTimeInterval(1)
                ),
                completion: completion
            )
        }

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.totalXP, 39)
        XCTAssertEqual(aggregate?.eventCount, 2)
    }

    func testSaveDailyAggregateUpdatesWhenOnlyUpdatedAtChanges() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let dateKey = XPCalculationEngine.periodKey()
        let initialUpdatedAt = Date()
        let newerUpdatedAt = initialUpdatedAt.addingTimeInterval(30)

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 25,
                    eventCount: 3,
                    updatedAt: initialUpdatedAt
                ),
                completion: completion
            )
        }

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 25,
                    eventCount: 3,
                    updatedAt: newerUpdatedAt
                ),
                completion: completion
            )
        }

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.updatedAt, newerUpdatedAt)
    }

    func testGamificationModelDefinesUniquenessConstraintsForXPEventAndDailyAggregate() throws {
        let container = try makeInMemoryV2Container()
        let model = container.managedObjectModel

        guard let xpEventEntity = model.entitiesByName["XPEvent"] else {
            return XCTFail("Expected XPEvent entity in model")
        }
        guard let dailyAggregateEntity = model.entitiesByName["DailyXPAggregate"] else {
            return XCTFail("Expected DailyXPAggregate entity in model")
        }

        let xpEventConstraints = normalizedUniquenessConstraints(for: xpEventEntity)
        let dailyAggregateConstraints = normalizedUniquenessConstraints(for: dailyAggregateEntity)

        XCTAssertTrue(
            xpEventConstraints.contains(["idempotencyKey"]),
            "XPEvent must enforce uniqueness on idempotencyKey"
        )
        XCTAssertTrue(
            dailyAggregateConstraints.contains(["dateKey"]),
            "DailyXPAggregate must enforce uniqueness on dateKey"
        )
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ConcurrencyRaceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func normalizedUniquenessConstraints(for entity: NSEntityDescription) -> Set<Set<String>> {
        Set(entity.uniquenessConstraints.map { rawConstraint in
            Set(rawConstraint.compactMap { $0 as? String })
        })
    }
}

final class FocusSessionUseCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPersistedFocusSessionKeys()
    }

    override func tearDown() {
        clearPersistedFocusSessionKeys()
        super.tearDown()
    }

    func testStartSessionFailsWhenUnfinishedSessionAlreadyExists() {
        let repository = FocusSessionRepositorySpy()
        repository.focusSessions = [
            FocusSessionDefinition(
                id: UUID(),
                taskID: UUID(),
                startedAt: Date().addingTimeInterval(-300),
                endedAt: nil,
                durationSeconds: 0,
                targetDurationSeconds: 25 * 60,
                wasCompleted: false,
                xpAwarded: 0
            )
        ]
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let expectation = expectation(description: "start-session-fails-already-active")
        useCase.startSession(taskID: nil, targetDurationSeconds: 25 * 60) { result in
            switch result {
            case .success:
                XCTFail("Expected startSession to fail when an unfinished session exists")
            case .failure(let error):
                guard let focusError = error as? FocusSessionError else {
                    return XCTFail("Expected FocusSessionError.alreadyActive but got \(error)")
                }
                if case .alreadyActive = focusError {
                    // expected
                } else {
                    XCTFail("Expected alreadyActive, got \(focusError)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.createFocusSessionCallCount, 0)
    }

    func testStartSessionCreatesSessionWhenNoUnfinishedSessionExists() throws {
        let repository = FocusSessionRepositorySpy()
        repository.focusSessions = [
            FocusSessionDefinition(
                id: UUID(),
                taskID: UUID(),
                startedAt: Date().addingTimeInterval(-1_800),
                endedAt: Date().addingTimeInterval(-1_200),
                durationSeconds: 600,
                targetDurationSeconds: 25 * 60,
                wasCompleted: false,
                xpAwarded: 10
            )
        ]
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let createdSession = try awaitResult { completion in
            useCase.startSession(taskID: nil, targetDurationSeconds: 20 * 60, completion: completion)
        }

        XCTAssertEqual(repository.createFocusSessionCallCount, 1)
        XCTAssertEqual(repository.createdSessions.first?.id, createdSession.id)
        XCTAssertEqual(repository.createdSessions.first?.targetDurationSeconds, 20 * 60)
    }

    private func clearPersistedFocusSessionKeys() {
        UserDefaults.standard.removeObject(forKey: "focusSessionActiveID")
        UserDefaults.standard.removeObject(forKey: "focusSessionStartedAt")
        UserDefaults.standard.removeObject(forKey: "focusSessionTaskID")
        UserDefaults.standard.removeObject(forKey: "focusSessionTargetSeconds")
    }
}

private final class FocusSessionRepositorySpy: GamificationRepositoryProtocol {
    var focusSessions: [FocusSessionDefinition] = []
    private(set) var createFocusSessionCallCount = 0
    private(set) var createdSessions: [FocusSessionDefinition] = []

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        createFocusSessionCallCount += 1
        createdSessions.append(session)
        focusSessions.append(session)
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = focusSessions.firstIndex(where: { $0.id == session.id }) {
            focusSessions[index] = session
        } else {
            focusSessions.append(session)
        }
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        let filtered = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        completion(.success(filtered))
    }
}

final class HomeViewModelFocusSessionThreadingTests: XCTestCase {
    func testStartFocusSessionCompletionIsDeliveredOnMainQueue() {
        let suiteName = "HomeViewModelFocusSessionThreadingTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let inbox = Project.createInbox()
        let seedTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Focus threading",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let taskRepository = MockTaskRepository(seed: seedTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            gamificationRepository: BackgroundFocusSessionRepository()
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        let completionExpectation = expectation(description: "focus session completion")
        var completionOnMainThread = false
        viewModel.startFocusSession(taskID: nil, targetDurationSeconds: 60) { result in
            completionOnMainThread = Thread.isMainThread
            if case .failure(let error) = result {
                XCTFail("Expected successful start session, got \(error)")
            }
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertTrue(completionOnMainThread)
    }
}

private final class BackgroundFocusSessionRepository: GamificationRepositoryProtocol {
    private let callbackQueue = DispatchQueue(label: "BackgroundFocusSessionRepository.callback")

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        callbackQueue.async {
            completion(.success(()))
        }
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        callbackQueue.async {
            completion(.success([]))
        }
    }
}

final class GamificationEngineMutationOrderingTests: XCTestCase {
    func testRecordEventEmitsLedgerMutationWithUpdatedStreak() throws {
        let repository = InMemoryGamificationEngineRepository()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        repository.profile = GamificationSnapshot(
            xpTotal: 0,
            level: 1,
            currentStreak: 0,
            bestStreak: 0,
            lastActiveDate: yesterday,
            updatedAt: Date(),
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 100,
            returnStreak: 0,
            bestReturnStreak: 0
        )

        let engine = GamificationEngine(repository: repository)
        let taskID = UUID()
        var observedMutation: GamificationLedgerMutation?
        let mutationExpectation = expectation(description: "ledger mutation")
        let completionExpectation = expectation(description: "record completion")
        var capturedResult: Result<XPEventResult, Error>?
        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: taskID,
                completedAt: Date(),
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(capturedResult).get()
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(observedMutation?.streakDays, 1)
        XCTAssertEqual(observedMutation?.didChange, true)
    }

    func testRecordEventRecoversWhenDailyAggregateWriteFailsAfterEventSave() throws {
        let repository = InMemoryGamificationEngineRepository()
        repository.failNextDailyAggregateSave = true
        let engine = GamificationEngine(repository: repository)

        let completedAt = Date()
        let dateKey = XPCalculationEngine.periodKey(for: completedAt)
        var observedMutation: GamificationLedgerMutation?
        var capturedResult: Result<XPEventResult, Error>?
        let mutationExpectation = expectation(description: "recovery mutation")
        let completionExpectation = expectation(description: "record completion")

        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: completedAt,
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 3.0)

        let result = try XCTUnwrap(capturedResult).get()
        XCTAssertGreaterThan(result.awardedXP, 0)
        XCTAssertTrue(observedMutation?.didChange ?? false)

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.totalXP, result.dailyXPSoFar)
        XCTAssertEqual(aggregate?.eventCount, 1)
    }

    func testFullReconciliationSkipsNoOpWritesWhenLedgerAlreadyCanonical() {
        let repository = InMemoryGamificationEngineRepository()
        let now = Date()
        let dateKey = XPCalculationEngine.periodKey(for: now)
        repository.seed(events: [
            XPEventDefinition(
                id: UUID(),
                taskID: UUID(),
                delta: 18,
                reason: "task_completion",
                idempotencyKey: "reconcile.noop.1",
                createdAt: now,
                category: .complete,
                source: .manual,
                qualityWeight: 1.0,
                periodKey: dateKey
            )
        ])

        let engine = GamificationEngine(repository: repository)

        let firstPass = expectation(description: "first reconciliation")
        engine.fullReconciliation { result in
            if case .failure(let error) = result {
                XCTFail("Expected first reconciliation to succeed, got error: \(error)")
            }
            firstPass.fulfill()
        }
        wait(for: [firstPass], timeout: 2.0)

        repository.resetWriteCounters()

        let secondPass = expectation(description: "second reconciliation")
        engine.fullReconciliation { result in
            if case .failure(let error) = result {
                XCTFail("Expected second reconciliation to succeed, got error: \(error)")
            }
            secondPass.fulfill()
        }
        wait(for: [secondPass], timeout: 2.0)

        XCTAssertEqual(repository.saveProfileCount, 0, "Second reconciliation should skip unchanged profile write")
        XCTAssertEqual(repository.saveDailyAggregateCount, 0, "Second reconciliation should skip unchanged daily aggregate writes")
    }

    func testRecordEventTreatsIdempotentReplaySaveErrorAsSuccessWithoutMutation() {
        let repository = InMemoryGamificationEngineRepository()
        let now = Date()
        let dateKey = XPCalculationEngine.periodKey(for: now)
        let seededProfile = GamificationSnapshot(
            xpTotal: 220,
            level: 4,
            currentStreak: 5,
            bestStreak: 8,
            lastActiveDate: now,
            updatedAt: now,
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 300,
            returnStreak: 0,
            bestReturnStreak: 0
        )
        repository.seed(
            profile: seededProfile,
            dailyAggregates: [
                dateKey: DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 40,
                    eventCount: 2,
                    updatedAt: now
                )
            ]
        )
        repository.hasXPEventOverride = false
        repository.failNextSaveXPEventError = GamificationRepositoryWriteError.idempotentReplay(idempotencyKey: "forced.replay")

        let engine = GamificationEngine(repository: repository)
        let completionExpectation = expectation(description: "record completion")
        let mutationExpectation = expectation(description: "ledger mutation")
        var capturedResult: Result<XPEventResult, Error>?
        var observedMutation: GamificationLedgerMutation?

        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: now,
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 2.0)
        let result = try? XCTUnwrap(capturedResult).get()

        XCTAssertEqual(result?.awardedXP, 0)
        XCTAssertEqual(result?.totalXP, seededProfile.xpTotal)
        XCTAssertEqual(result?.dailyXPSoFar, 40)
        XCTAssertEqual(observedMutation?.didChange, false)
        XCTAssertEqual(repository.saveProfileCount, 0)
        XCTAssertEqual(repository.saveDailyAggregateCount, 0)
    }

    func testRecordEventHandlesConcurrentAchievementUnlockCallbacks() throws {
        let repository = InMemoryGamificationEngineRepository()
        repository.concurrentUnlockCallbacks = true
        repository.profile = GamificationSnapshot(
            xpTotal: 95,
            level: 1,
            currentStreak: 0,
            bestStreak: 0,
            lastActiveDate: Date(),
            updatedAt: Date(),
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 100,
            returnStreak: 0,
            bestReturnStreak: 0
        )
        let engine = GamificationEngine(repository: repository)
        let completionExpectation = expectation(description: "record completion")
        var capturedResult: Result<XPEventResult, Error>?

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: Date(),
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(capturedResult).get()
        let unlocked = Set(result.unlockedAchievements.map(\.achievementKey))
        XCTAssertTrue(unlocked.contains("first_step"))
        XCTAssertTrue(unlocked.contains("xp_100"))
    }
}

private final class InMemoryGamificationEngineRepository: GamificationRepositoryProtocol {
    private let lock = NSLock()
    var profile: GamificationSnapshot?
    private var events: [XPEventDefinition] = []
    private var dailyAggregates: [String: DailyXPAggregateDefinition] = [:]
    private var unlocks: [AchievementUnlockDefinition] = []
    private var focusSessions: [FocusSessionDefinition] = []
    private(set) var saveProfileCount = 0
    private(set) var saveDailyAggregateCount = 0
    var failNextDailyAggregateSave = false
    var failNextSaveXPEventError: Error?
    var hasXPEventOverride: Bool?
    var concurrentUnlockCallbacks = false

    func seed(
        profile: GamificationSnapshot? = nil,
        events: [XPEventDefinition] = [],
        dailyAggregates: [String: DailyXPAggregateDefinition] = [:]
    ) {
        lock.lock()
        self.profile = profile
        self.events = events
        self.dailyAggregates = dailyAggregates
        lock.unlock()
    }

    func resetWriteCounters() {
        lock.lock()
        saveProfileCount = 0
        saveDailyAggregateCount = 0
        lock.unlock()
    }

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        lock.lock()
        let snapshot = profile
        lock.unlock()
        completion(.success(snapshot))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        self.profile = profile
        saveProfileCount += 1
        lock.unlock()
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        let current = events
        lock.unlock()
        completion(.success(current))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        let filtered = events.filter { $0.createdAt >= startDate && $0.createdAt < endDate }
        lock.unlock()
        completion(.success(filtered))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if let injectedError = failNextSaveXPEventError {
            failNextSaveXPEventError = nil
            lock.unlock()
            completion(.failure(injectedError))
            return
        }
        if events.contains(where: { $0.idempotencyKey == event.idempotencyKey }) == false {
            events.append(event)
        }
        lock.unlock()
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        lock.lock()
        if let override = hasXPEventOverride {
            lock.unlock()
            completion(.success(override))
            return
        }
        let exists = events.contains { $0.idempotencyKey == idempotencyKey }
        lock.unlock()
        completion(.success(exists))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        lock.lock()
        let current = unlocks
        lock.unlock()
        completion(.success(current))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        let write = {
            self.lock.lock()
            if self.unlocks.contains(where: { $0.achievementKey == unlock.achievementKey }) == false {
                self.unlocks.append(unlock)
            }
            self.lock.unlock()
            completion(.success(()))
        }
        if concurrentUnlockCallbacks {
            DispatchQueue.global(qos: .userInitiated).async(execute: write)
            return
        }
        write()
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        lock.lock()
        let aggregate = dailyAggregates[dateKey]
        lock.unlock()
        completion(.success(aggregate))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if failNextDailyAggregateSave {
            failNextDailyAggregateSave = false
            lock.unlock()
            completion(.failure(NSError(
                domain: "InMemoryGamificationEngineRepository",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Injected saveDailyAggregate failure"]
            )))
            return
        }
        dailyAggregates[aggregate.dateKey] = aggregate
        saveDailyAggregateCount += 1
        lock.unlock()
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        lock.lock()
        let values = dailyAggregates.values
            .filter { $0.dateKey >= startDateKey && $0.dateKey <= endDateKey }
            .sorted { $0.dateKey < $1.dateKey }
        lock.unlock()
        completion(.success(values))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        focusSessions.append(session)
        lock.unlock()
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if let index = focusSessions.firstIndex(where: { $0.id == session.id }) {
            focusSessions[index] = session
        } else {
            focusSessions.append(session)
        }
        lock.unlock()
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        lock.lock()
        let current = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        lock.unlock()
        completion(.success(current))
    }
}

final class TaskDefinitionCreationMetadataTests: XCTestCase {
    func testCreateTaskDefinitionPersistsMetadataAndLinks() throws {
        let taskRepository = MetadataCapturingTaskDefinitionRepository()
        let tagRepository = MetadataCapturingTaskTagLinkRepository()
        let dependencyRepository = MetadataCapturingTaskDependencyRepository()
        let useCase = CreateTaskDefinitionUseCase(
            repository: taskRepository,
            taskTagLinkRepository: tagRepository,
            taskDependencyRepository: dependencyRepository
        )

        let dependencyA = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks)
        let dependencyB = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .related)
        let request = CreateTaskDefinitionRequest(
            id: UUID(),
            title: "Plan release #work",
            details: "Finalize and ship",
            projectID: UUID(),
            projectName: "Work",
            lifeAreaID: UUID(),
            sectionID: UUID(),
            dueDate: Date(),
            parentTaskID: UUID(),
            tagIDs: [UUID(), UUID()],
            dependencies: [dependencyA, dependencyB],
            priority: .high,
            type: .morning,
            energy: .high,
            category: .general,
            context: .anywhere,
            isEveningTask: false,
            alertReminderTime: Date(),
            createdAt: Date()
        )

        let createdTask = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }

        XCTAssertEqual(taskRepository.lastCreateRequest?.id, request.id)
        XCTAssertEqual(taskRepository.lastCreateRequest?.lifeAreaID, request.lifeAreaID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.sectionID, request.sectionID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.parentTaskID, request.parentTaskID)
        XCTAssertEqual(createdTask.projectID, request.projectID)
        XCTAssertEqual(createdTask.projectName, request.projectName)

        XCTAssertEqual(tagRepository.lastTaskID, request.id)
        XCTAssertEqual(Set(tagRepository.lastTagIDs ?? []), Set(request.tagIDs))

        XCTAssertEqual(dependencyRepository.lastTaskID, request.id)
        XCTAssertEqual(dependencyRepository.lastDependencies?.count, 2)
        XCTAssertEqual(Set(dependencyRepository.lastDependencies?.map(\.kind) ?? []), Set([.blocks, .related]))
    }
}

private final class InMemoryScheduleRepository: ScheduleRepositoryProtocol {
    var templates: [ScheduleTemplateDefinition] = []
    var rulesByTemplateID: [UUID: [ScheduleRuleDefinition]] = [:]
    var exceptionsByTemplateID: [UUID: [ScheduleExceptionDefinition]] = [:]
    var deleteTemplateErrorsByID: [UUID: Error] = [:]

    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        completion(.success(templates))
    }

    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success(rulesByTemplateID[templateID] ?? []))
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        templates.removeAll { $0.id == template.id }
        templates.append(template)
        completion(.success(template))
    }

    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        if let error = deleteTemplateErrorsByID[id] {
            completion(.failure(error))
            return
        }
        templates.removeAll { $0.id == id }
        rulesByTemplateID.removeValue(forKey: id)
        exceptionsByTemplateID.removeValue(forKey: id)
        completion(.success(()))
    }

    func replaceRules(
        templateID: UUID,
        rules: [ScheduleRuleDefinition],
        completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void
    ) {
        rulesByTemplateID[templateID] = rules
        completion(.success(rules))
    }

    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        completion(.success(exceptionsByTemplateID[templateID] ?? []))
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        var current = exceptionsByTemplateID[exception.scheduleTemplateID] ?? []
        current.append(exception)
        exceptionsByTemplateID[exception.scheduleTemplateID] = current
        completion(.success(exception))
    }
}

private final class MetadataCapturingTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    var lastCreateRequest: CreateTaskDefinitionRequest?
    var byID: [UUID: TaskDefinition] = [:]

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        lastCreateRequest = request
        let task = request.toTaskDefinition(projectName: request.projectName)
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "MetadataCapturingTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.title = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if request.clearDueDate {
            current.dueDate = nil
        } else if let dueDate = request.dueDate {
            current.dueDate = dueDate
        }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    var lastTaskID: UUID?
    var lastTagIDs: [UUID]?

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastTagIDs ?? []) : []))
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        lastTaskID = taskID
        lastTagIDs = tagIDs
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    var lastTaskID: UUID?
    var lastDependencies: [TaskDependencyLinkDefinition]?

    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastDependencies ?? []) : []))
    }

    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastTaskID = taskID
        lastDependencies = dependencies
        completion(.success(()))
    }
}

private final class InMemoryOccurrenceRepository: OccurrenceRepositoryProtocol {
    var occurrences: [OccurrenceDefinition] = []
    var resolutions: [OccurrenceResolutionDefinition] = []
    var deletedOccurrenceIDs: [UUID] = []

    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success(occurrences.filter {
            let effectiveDate = $0.dueAt ?? $0.scheduledAt
            return effectiveDate >= start && effectiveDate <= end
        }))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        for occurrence in occurrences {
            if let index = self.occurrences.firstIndex(where: { $0.id == occurrence.id }) {
                self.occurrences[index] = occurrence
            } else {
                self.occurrences.append(occurrence)
            }
        }
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        resolutions.append(resolution)
        if let index = occurrences.firstIndex(where: { $0.id == resolution.occurrenceID }) {
            switch resolution.resolutionType {
            case .completed:
                occurrences[index].state = .completed
            case .skipped, .deferred:
                occurrences[index].state = .skipped
            case .missed:
                occurrences[index].state = .missed
            case .lapsed:
                occurrences[index].state = .failed
            }
            occurrences[index].updatedAt = resolution.resolvedAt
        }
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedOccurrenceIDs.append(contentsOf: ids)
        occurrences.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

private final class InMemoryTombstoneRepository: TombstoneRepositoryProtocol {
    var tombstones: [TombstoneDefinition] = []
    var deletedIDs: [UUID] = []

    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        tombstones.append(tombstone)
        completion(.success(()))
    }

    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        completion(.success(tombstones.filter { $0.purgeAfter <= date }))
    }

    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedIDs.append(contentsOf: ids)
        tombstones.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

final class ReconcileExternalRemindersConflictTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testEqualTimestampConflictDeterministicallyPullsWhenRemoteClockWinsNodeTie() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_705_000_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-a"
        let externalID = "ext-a"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Title",
                dueDate: fixedDate,
                isComplete: false,
                dateAdded: fixedDate,
                createdAt: fixedDate,
                updatedAt: fixedDate
            )
        ])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: fixedDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: fixedDate,
                externalPayloadData: nil,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: fixedDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Title",
                notes: "remote",
                dueDate: fixedDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: fixedDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "aaa-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 0)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)

        let updatedTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(updatedTask?.title, "Remote Title")
        XCTAssertEqual(updatedTask?.details, "remote")
    }

    func testNewerTombstoneSuppressesBothPullAndPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_100_000)
        let tombstone = SyncClock(
            physicalMillis: Int64(baseDate.timeIntervalSince1970 * 1_000) + 10_000,
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-b"
        let externalID = "ext-b"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Tombstoned",
                dueDate: nil,
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Tombstoned",
                notes: nil,
                dueDate: nil,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 0)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)
    }

    func testNewerLocalUpdateResurrectsAfterOlderTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_200_000)
        let newDate = oldDate.addingTimeInterval(3_600)
        let tombstone = SyncClock(
            physicalMillis: Int64(oldDate.timeIntervalSince1970 * 1_000),
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-c"
        let externalID = "ext-c"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Locally Resurrected",
                dueDate: newDate,
                isComplete: false,
                dateAdded: oldDate,
                createdAt: oldDate,
                updatedAt: newDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone
        state.lastWriteClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Old Remote Value",
                notes: nil,
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: oldDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 1)
        XCTAssertEqual(provider.upsertedSnapshots.count, 1)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let updatedState = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNil(updatedState.tombstoneClock, "Successful resurrection must clear obsolete tombstone clock")
    }

    func testMappedMissingRemoteWithDeletedLocalCreatesTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_260_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-missing-remote"
        let externalID = "ext-missing-remote"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]

        let envelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Previously Synced",
                notes: "legacy",
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: []
            ),
            passthroughData: Data("legacy-passthrough".utf8)
        )

        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: try JSONEncoder().encode(envelope),
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = []

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(summary.pulledFromExternal, 0)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let state = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNotNil(state.tombstoneClock, "Missing remote + missing local must persist a tombstone decision")
    }
}

final class ReminderPayloadRoundTripTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testLegacyPayloadDecodePreservesRawBytesAsPassthrough() {
        let legacyPayload = Data(#"{"title":"Legacy Reminder","notes":"n","unsupported":{"alpha":1}}"#.utf8)
        let mergeEngine = ReminderMergeEngine()
        let decoded = mergeEngine.decodeEnvelope(data: legacyPayload)

        XCTAssertEqual(decoded?.known.title, "Legacy Reminder")
        XCTAssertEqual(decoded?.passthroughData, legacyPayload)
    }

    func testUnsupportedPayloadBytesArePreservedAcrossPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_300_000)
        let passthrough = Data("opaque-payload".utf8)
        let originalEnvelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Old",
                notes: "old-note",
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: "https://example.com",
                alarmDates: []
            ),
            passthroughData: passthrough
        )
        let originalPayload = try JSONEncoder().encode(originalEnvelope)

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-roundtrip"
        let externalID = "ext-roundtrip"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local New Title",
                details: "Local New Notes",
                dueDate: baseDate.addingTimeInterval(86_400),
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(120)
            )
        ])

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: originalPayload,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Older Remote Title",
                notes: nil,
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }
        XCTAssertEqual(summary.pushedToExternal, 1)

        let pushedPayload = try XCTUnwrap(provider.upsertedSnapshots.first?.payloadData)
        let pushedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: pushedPayload)
        XCTAssertEqual(pushedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(pushedEnvelope.known.title, "Local New Title")

        let savedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let savedPayload = try XCTUnwrap(savedMap?.externalPayloadData)
        let savedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: savedPayload)
        XCTAssertEqual(savedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(savedEnvelope.known.title, "Local New Title")
    }
}

final class SyncClockDeterminismTests: XCTestCase {
    func testLogicalCounterBreaksPhysicalTimestampTie() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 1, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 2, nodeID: "node-a")
        XCTAssertTrue(rhs > lhs)
    }

    func testNodeIDBreaksFullClockTieDeterministically() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-b")
        XCTAssertTrue(lhs < rhs)
        XCTAssertTrue(rhs > lhs)
    }
}

final class AssistantPipelineTransactionalTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantApplyEnabled = true
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testPartialApplyFailureRollsBackAndPersistsVerifiedRollbackOutcome() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Apply",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        taskRepository.failUpdateOnCall = 2
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "Step 1", dueDate: nil),
                .updateTask(taskID: taskID, title: "Step 2", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        let applyExpectation = expectation(description: "apply-fails")
        useCase.applyConfirmedRun(id: runID) { result in
            if case .failure = result {
                applyExpectation.fulfill()
            } else {
                XCTFail("Expected apply to fail")
            }
        }
        waitForExpectations(timeout: 2.0)

        let persistedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(persistedRun?.status, .failed)
        XCTAssertEqual(persistedRun?.rollbackStatus, .verified)
        XCTAssertNotNil(persistedRun?.rollbackVerifiedAt)
        XCTAssertNotNil(persistedRun?.executionTraceData)
        XCTAssertEqual(persistedRun?.lastErrorCode, "assistant_apply_failed")

        let finalTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(finalTask?.title, "Before Apply", "Rollback must restore pre-apply state")
    }

    func testSuccessfulApplyGeneratesDeterministicUndoPlan() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Undo",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "After Undo", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        _ = try awaitResult { completion in
            useCase.applyConfirmedRun(id: runID, completion: completion)
        }

        let appliedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(appliedRun?.status, .applied)
        let appliedData = try XCTUnwrap(appliedRun?.proposalData)
        let appliedEnvelope = try JSONDecoder().decode(AssistantCommandEnvelope.self, from: appliedData)
        XCTAssertEqual(appliedEnvelope.undoCommands?.count, 1)

        _ = try awaitResult { completion in
            useCase.undoAppliedRun(id: runID, completion: completion)
        }

        let undoneRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(undoneRun?.status, .confirmed)

        let taskAfterUndo = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(taskAfterUndo?.title, "Before Undo")
    }
}

final class AssistantUndoWindowTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testUndoWindowExpirationIsDeterministic() throws {
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [.createTask(projectID: UUID(), title: "Expired")],
            undoCommands: [.deleteTask(taskID: UUID())]
        )
        let staleRun = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .applied,
            confirmedAt: Date().addingTimeInterval(-4_000),
            appliedAt: Date().addingTimeInterval(-4_000),
            createdAt: Date().addingTimeInterval(-4_000)
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(staleRun, completion: completion)
        }

        let expectation = expectation(description: "undo-expired")
        useCase.undoAppliedRun(id: runID) { result in
            switch result {
            case .failure(let error as NSError):
                XCTAssertEqual(error.code, 410)
                expectation.fulfill()
            default:
                XCTFail("Expected undo window expiration failure")
            }
        }
        waitForExpectations(timeout: 2.0)
    }
}

final class ReadModelQueryPathTests: XCTestCase {
    func testHomeAndSearchUseCasesPreferReadModelQueriesOverFetchAll() {
        let inbox = Project.createInbox()
        let task = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "ReadModel Task",
            details: "searchable",
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let repository = MockTaskRepository(seed: task)

        let homeUseCase = GetHomeFilteredTasksUseCase(readModelRepository: repository)
        let homeExpectation = expectation(description: "home-read-model")
        homeUseCase.execute(state: HomeFilterState.default, scope: HomeListScope.today) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected home failure: \(error)")
            }
            homeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelFetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)

        let getTasksUseCase = GetTasksUseCase(readModelRepository: repository)
        let searchExpectation = expectation(description: "search-read-model")
        getTasksUseCase.searchTasks(query: "ReadModel", in: .all) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected search failure: \(error)")
            }
            searchExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelSearchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)
    }
}

final class V2PerformanceGateTests: XCTestCase {
    private struct PerfSnapshot: Decodable {
        struct Percentiles: Decodable {
            let p95_ms: Double
            let p99_ms: Double
        }
        struct Metrics: Decodable {
            let home: Percentiles
            let project: Percentiles
            let search: Percentiles
        }
        let metrics: Metrics
    }

    func testPerfSeedHarnessProducesBalancedProfileSnapshot() throws {
#if !os(macOS)
        throw XCTSkip("Shell command perf harness is only supported on macOS host tests")
#endif
        let root = workspaceRootURLForTests()
        let outputURL = root.appendingPathComponent("build/benchmarks/v2_readmodel.test.json")
        let status = try runProcess(
            executable: "/usr/bin/swift",
            arguments: [
                "scripts/perf_seed_v3.swift",
                "--tasks", "2000",
                "--occurrences", "20000",
                "--iterations", "60",
                "--output", outputURL.path
            ],
            in: root
        )
        XCTAssertEqual(status, 0, "Benchmark harness command failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let data = try Data(contentsOf: outputURL)
        let snapshot = try JSONDecoder().decode(PerfSnapshot.self, from: data)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p95_ms, 300)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p99_ms, 600)
    }
}

final class FlowctlToolingTests: XCTestCase {
    func testFlowctlInstallAndVerifyScriptsSucceed() throws {
#if !os(macOS)
        throw XCTSkip("flowctl shell checks are only supported on macOS host tests")
#endif
        let root = workspaceRootURLForTests()
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/install_flowctl.sh", in: root), 0)
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/verify_flowctl.sh", in: root), 0)
        let flowctlPath = root.appendingPathComponent(".flow/bin/flowctl").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: flowctlPath))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: flowctlPath))
    }
}

final class ProcessExecutionTests: XCTestCase {
    func testRunProcessPreservesArgumentsContainingSpaces() throws {
#if !os(macOS)
        throw XCTSkip("Process execution checks are only supported on macOS host tests")
#endif
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tasker process helper \(UUID().uuidString)", isDirectory: true)
        let outputURL = tempDirectory.appendingPathComponent("output file.txt")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let status = try runProcess(
            executable: "/usr/bin/touch",
            arguments: [outputURL.path],
            in: workspaceRootURLForTests()
        )

        XCTAssertEqual(status, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

final class AssistantPipelineImplementationTests: XCTestCase {
    func testPipelineImplementationContainsNoSemaphoreWaits() throws {
        let root = workspaceRootURLForTests()
        let sourceURL = root.appendingPathComponent("To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("DispatchSemaphore"))
        XCTAssertFalse(source.contains(".wait(timeout:"))
    }
}

private final class InMemoryAssistantActionRepository: AssistantActionRepositoryProtocol {
    private var byID: [UUID: AssistantActionRunDefinition] = [:]

    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }
}

private final class InMemoryTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private(set) var byID: [UUID: TaskDefinition]
    private(set) var updateCallCount = 0
    var failUpdateOnCall: Int?

    init(seed: [TaskDefinition]) {
        byID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        let filtered = Array(byID.values).filter { task in
            guard let query else { return true }
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let parentTaskID = query.parentTaskID, task.parentTaskID != parentTaskID { return false }
            if let start = query.dueDateStart, let due = task.dueDate, due < start { return false }
            if let end = query.dueDateEnd, let due = task.dueDate, due > end { return false }
            if let searchText = query.searchText?.lowercased(), searchText.isEmpty == false {
                let nameMatch = task.title.lowercased().contains(searchText)
                let detailMatch = task.details?.lowercased().contains(searchText) ?? false
                if !nameMatch && !detailMatch { return false }
            }
            return true
        }
        completion(.success(filtered))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let task = TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            title: request.title,
            details: request.details,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        updateCallCount += 1
        if failUpdateOnCall == updateCallCount {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Injected update failure"])))
            return
        }
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.title = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if request.clearDueDate {
            current.dueDate = nil
        } else if let dueDate = request.dueDate {
            current.dueDate = dueDate
        }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        current.updatedAt = Date()
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values.filter { $0.parentTaskID == parentTaskID })))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class InMemoryExternalSyncRepository: ExternalSyncRepositoryProtocol {
    var containerMappings: [ExternalContainerMapDefinition] = []
    var itemMappings: [ExternalItemMapDefinition] = []

    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        completion(.success(containerMappings))
    }

    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = containerMappings.firstIndex(where: { $0.id == mapping.id }) {
            containerMappings[index] = mapping
        } else if let index = containerMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.projectID == mapping.projectID
        }) {
            containerMappings[index] = mapping
        } else {
            containerMappings.append(mapping)
        }
        completion(.success(()))
    }

    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    ) {
        completion(.success(containerMappings.first { $0.provider == provider && $0.projectID == projectID }))
    }

    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    ) {
        let existing = containerMappings.first { $0.provider == provider && $0.projectID == projectID }
        let mutated = mutate(existing)
        saveContainerMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        completion(.success(itemMappings))
    }

    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = itemMappings.firstIndex(where: { $0.id == mapping.id }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider &&
            $0.localEntityType == mapping.localEntityType &&
            $0.localEntityID == mapping.localEntityID
        }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.externalItemID == mapping.externalItemID
        }) {
            itemMappings[index] = mapping
        } else {
            itemMappings.append(mapping)
        }
        completion(.success(()))
    }

    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        completion(.success(itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }))
    }

    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) {
        completion(.success(itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }))
    }
}

private final class InMemoryAppleRemindersProvider: AppleRemindersProviderProtocol {
    var requestAccessGranted = true
    var lists: [AppleReminderListSnapshot] = []
    var remindersByListID: [String: [AppleReminderItemSnapshot]] = [:]
    var upsertedSnapshots: [AppleReminderItemSnapshot] = []

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(requestAccessGranted))
    }

    func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success(lists))
    }

    func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success(remindersByListID[listID] ?? []))
    }

    func upsertReminder(
        listID: String,
        snapshot: AppleReminderItemSnapshot,
        completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void
    ) {
        upsertedSnapshots.append(snapshot)
        var persisted = snapshot
        persisted.lastModifiedAt = snapshot.lastModifiedAt ?? Date()
        var existing = remindersByListID[listID] ?? []
        if let index = existing.firstIndex(where: { $0.itemID == snapshot.itemID }) {
            existing[index] = persisted
        } else {
            existing.append(persisted)
        }
        remindersByListID[listID] = existing
        completion(.success(persisted))
    }

    func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        for key in remindersByListID.keys {
            remindersByListID[key]?.removeAll(where: { $0.itemID == itemID })
        }
        completion(.success(()))
    }
}

final class LifeAreaIdentityRepairTests: XCTestCase {
    func testLifeAreaRepairMergesDuplicateGeneralAndRepointsProjectTaskHabit() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let canonicalID = UUID()
        let duplicateID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: canonicalID,
                name: "General",
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
            _ = makeLifeArea(
                in: context,
                id: duplicateID,
                name: " general ",
                color: "#4A6FA5",
                icon: "square.grid.2x2",
                isArchived: true,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeProject(in: context, lifeAreaID: duplicateID)
            _ = makeTaskDefinition(in: context, lifeAreaID: duplicateID)
            _ = makeHabitDefinition(in: context, lifeAreaID: duplicateID)
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertEqual(report.duplicateGroups, 1)
        XCTAssertEqual(report.merged, 1)
        XCTAssertEqual(report.repointedProjects, 1)
        XCTAssertEqual(report.repointedTasks, 1)
        XCTAssertEqual(report.repointedHabits, 1)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let general = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "general"
        }
        XCTAssertEqual(general.count, 1)
        XCTAssertEqual(general.first?.value(forKey: "id") as? UUID, canonicalID)
        XCTAssertEqual(general.first?.value(forKey: "color") as? String, "#4A6FA5")
        XCTAssertEqual(general.first?.value(forKey: "icon") as? String, "square.grid.2x2")

        let projects = try fetchObjects(entityName: "Project", in: context)
        XCTAssertEqual(projects.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
        let tasks = try fetchObjects(entityName: "TaskDefinition", in: context)
        XCTAssertEqual(tasks.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
        let habits = try fetchObjects(entityName: "HabitDefinition", in: context)
        XCTAssertEqual(habits.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
    }

    func testLifeAreaRepairMergesDuplicateCustomNamesCaseInsensitive() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let firstID = UUID()
        let secondID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: firstID,
                name: "Work",
                color: "#111111",
                icon: "briefcase",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_500)
            )
            _ = makeLifeArea(
                in: context,
                id: secondID,
                name: " work ",
                color: "#222222",
                icon: "desktopcomputer",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeProject(in: context, lifeAreaID: secondID)
            _ = makeTaskDefinition(in: context, lifeAreaID: secondID)
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertEqual(report.duplicateGroups, 1)
        XCTAssertEqual(report.merged, 1)
        XCTAssertEqual(report.canonicalIDsByNormalizedName["work"], secondID)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let workAreas = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "work"
        }
        XCTAssertEqual(workAreas.count, 1)
        XCTAssertEqual(workAreas.first?.value(forKey: "id") as? UUID, secondID)
    }

    func testLifeAreaRepairFillsMissingNameAndMaintainsSingleGeneral() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let canonicalGeneralID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: canonicalGeneralID,
                name: "General",
                color: "#123456",
                icon: "square.grid.2x2",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
            _ = makeLifeArea(
                in: context,
                id: UUID(),
                name: nil,
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeLifeArea(
                in: context,
                id: UUID(),
                name: "   ",
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 3_000)
            )
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertGreaterThanOrEqual(report.normalized, 2)
        XCTAssertEqual(report.merged, 2)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let generalAreas = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "general"
        }
        XCTAssertEqual(generalAreas.count, 1)
        XCTAssertEqual(generalAreas.first?.value(forKey: "id") as? UUID, canonicalGeneralID)
        XCTAssertEqual(generalAreas.first?.value(forKey: "name") as? String, "General")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "LifeAreaIdentityRepairTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    @discardableResult
    private func makeLifeArea(
        in context: NSManagedObjectContext,
        id: UUID,
        name: String?,
        color: String?,
        icon: String?,
        isArchived: Bool,
        createdAt: Date
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(name, forKey: "name")
        object.setValue(color, forKey: "color")
        object.setValue(icon, forKey: "icon")
        object.setValue(Int32(0), forKey: "sortOrder")
        object.setValue(isArchived, forKey: "isArchived")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(createdAt, forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeProject(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Test Project", forKey: "name")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeTaskDefinition(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Repair Task", forKey: "title")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeHabitDefinition(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Repair Habit", forKey: "title")
        object.setValue("daily", forKey: "habitType")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    private func fetchObjects(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.returnsObjectsAsFaults = false
        return try context.fetch(request)
    }
}

final class ManageLifeAreasUseCaseValidationTests: XCTestCase {
    func testManageLifeAreasCreateRejectsDuplicateNormalizedName() {
        let existing = LifeArea(name: "General", color: nil, icon: nil)
        let repository = CapturingLifeAreaRepository(storedAreas: [existing])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "reject duplicate life area")
        useCase.create(name: "  gEnErAl ", color: "#123456", icon: "circle") { result in
            switch result {
            case .success:
                XCTFail("Expected duplicate life area create to fail")
            case .failure(let error):
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "ManageLifeAreasUseCase")
                XCTAssertEqual(nsError.code, 409)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.createCallCount, 0)
    }
}

private final class CapturingAddTaskRepository: TaskDefinitionRepositoryProtocol {
    var lastCreateRequest: CreateTaskDefinitionRequest?
    var onCreateRequest: ((CreateTaskDefinitionRequest) -> Void)?

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        lastCreateRequest = request
        onCreateRequest?(request)
        completion(.success(request.toTaskDefinition(projectName: request.projectName)))
    }
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "CapturingAddTaskRepository", code: 1)))
    }
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private func makeAddTaskScheduleViewModel(
    now: Date = Date(timeIntervalSince1970: 1_777_000_000),
    repository: TaskDefinitionRepositoryProtocol = CapturingAddTaskRepository(),
    projects: [Project] = [Project.createInbox()],
    taskIconResolver: TaskIconResolver = DefaultTaskIconResolver.shared
) -> AddTaskViewModel {
    AddTaskViewModel(
        taskReadModelRepository: nil,
        manageProjectsUseCase: ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: projects)
        ),
        createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(
            repository: repository,
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        ),
        rescheduleTaskDefinitionUseCase: nil,
        manageLifeAreasUseCase: nil,
        manageSectionsUseCase: nil,
        manageTagsUseCase: nil,
        taskIconResolver: taskIconResolver,
        nowProvider: { now }
    )
}

private final class StubTaskIconResolver: TaskIconResolver {
    var nextResolution = TaskIconResolution(
        selectedSymbolName: "checklist",
        autoSuggestedSymbolName: "checklist",
        rankedSuggestions: [
            TaskIconOption(
                symbolName: "checklist",
                displayName: "Checklist",
                searchTerms: [],
                aliases: [],
                categories: []
            )
        ],
        confidence: 0.9,
        didUseFallback: false,
        fallbackReason: .semantic
    )
    var optionBySymbol: [String: TaskIconOption] = [
        "checklist": TaskIconOption(symbolName: "checklist", displayName: "Checklist", searchTerms: [], aliases: [], categories: []),
        "stethoscope": TaskIconOption(symbolName: "stethoscope", displayName: "Stethoscope", searchTerms: [], aliases: [], categories: []),
        "phone.fill": TaskIconOption(symbolName: "phone.fill", displayName: "Phone Fill", searchTerms: [], aliases: [], categories: []),
        "briefcase.fill": TaskIconOption(symbolName: "briefcase.fill", displayName: "Briefcase Fill", searchTerms: [], aliases: [], categories: [])
    ]
    private(set) var resolveCallCount = 0

    func warmIfNeeded() {}

    func resolve(
        title: String,
        projectName: String?,
        projectIconSymbolName: String?,
        lifeAreaName: String?,
        category: TaskCategory,
        currentSymbolName: String?,
        selectionSource: TaskIconSelectionSource
    ) -> TaskIconResolution {
        resolveCallCount += 1
        return nextResolution
    }

    func search(query: String, preferredSymbols: [String], limit: Int) -> [TaskIconOption] {
        let preferred = preferredSymbols.compactMap { optionBySymbol[$0] }
        return Array(preferred.prefix(limit))
    }

    func option(for symbolName: String) -> TaskIconOption? {
        optionBySymbol[symbolName]
    }
}

final class AddTaskViewModelLifeAreaDedupeTests: XCTestCase {
    func testAddTaskScheduleDefaultsToTwentyMinutesFromNowAndFifteenMinuteDuration() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 10, second: 45))!
        let viewModel = makeAddTaskScheduleViewModel(now: now)
        let expectedStart = AddTaskViewModel.defaultScheduledStart(now: now)

        XCTAssertEqual(viewModel.scheduledStartAt, expectedStart)
        XCTAssertEqual(viewModel.dueDate, expectedStart)
        XCTAssertEqual(viewModel.estimatedDuration, 15 * 60)
        XCTAssertEqual(viewModel.scheduledEndAt, expectedStart.addingTimeInterval(15 * 60))
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }

    func testChangingDurationUpdatesDerivedScheduledEnd() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 0, second: 15))!
        let viewModel = makeAddTaskScheduleViewModel(now: now)

        viewModel.setEstimatedDuration(90 * 60)

        XCTAssertEqual(viewModel.scheduledEndAt, viewModel.scheduledStartAt?.addingTimeInterval(90 * 60))
    }

    func testChangingDatePreservesStartTime() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 10, second: 45))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let viewModel = makeAddTaskScheduleViewModel(now: now)
        let originalTime = calendar.dateComponents([.hour, .minute], from: viewModel.scheduledStartAt!)

        viewModel.setScheduledDate(tomorrow)

        let updated = viewModel.scheduledStartAt!
        XCTAssertTrue(calendar.isDate(updated, inSameDayAs: tomorrow))
        XCTAssertEqual(calendar.component(.hour, from: updated), originalTime.hour)
        XCTAssertEqual(calendar.component(.minute, from: updated), originalTime.minute)
    }

    func testChangingTimePreservesDate() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 10, second: 45))!
        let newTime = calendar.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 14, minute: 35, second: 30))!
        let viewModel = makeAddTaskScheduleViewModel(now: now)
        let originalDate = viewModel.scheduledStartAt!

        viewModel.setScheduledStartTime(newTime)

        let updated = viewModel.scheduledStartAt!
        XCTAssertTrue(calendar.isDate(updated, inSameDayAs: originalDate))
        XCTAssertEqual(calendar.component(.hour, from: updated), 14)
        XCTAssertEqual(calendar.component(.minute, from: updated), 35)
        XCTAssertEqual(calendar.component(.second, from: updated), 0)
    }

    func testCreateTaskIncludesTimedScheduleFields() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 10, second: 45))!
        let repository = CapturingAddTaskRepository()
        let viewModel = makeAddTaskScheduleViewModel(now: now, repository: repository)
        viewModel.taskName = "Watch a movie"
        viewModel.setEstimatedDuration(90 * 60)

        let expectation = expectation(description: "task created")
        repository.onCreateRequest = { _ in expectation.fulfill() }
        viewModel.createTask()
        waitForExpectations(timeout: 1.0)

        let request = repository.lastCreateRequest
        XCTAssertEqual(request?.dueDate, viewModel.scheduledStartAt)
        XCTAssertEqual(request?.scheduledStartAt, viewModel.scheduledStartAt)
        XCTAssertEqual(request?.scheduledEndAt, viewModel.scheduledEndAt)
        XCTAssertEqual(request?.estimatedDuration, 90 * 60)
        XCTAssertEqual(request?.isAllDay, false)
    }

    func testClearingScheduleCreatesUnscheduledTask() {
        let repository = CapturingAddTaskRepository()
        let viewModel = makeAddTaskScheduleViewModel(repository: repository)
        viewModel.taskName = "Inbox idea"
        viewModel.clearSchedule()

        let expectation = expectation(description: "task created")
        repository.onCreateRequest = { _ in expectation.fulfill() }
        viewModel.createTask()
        waitForExpectations(timeout: 1.0)

        XCTAssertNil(repository.lastCreateRequest?.dueDate)
        XCTAssertNil(repository.lastCreateRequest?.scheduledStartAt)
        XCTAssertNil(repository.lastCreateRequest?.scheduledEndAt)
        XCTAssertEqual(repository.lastCreateRequest?.isAllDay, false)
        XCTAssertEqual(repository.lastCreateRequest?.estimatedDuration, 15 * 60)
    }

    func testLoadLifeAreasDedupesSameNameChipsAndKeepsStableSelection() {
        let duplicateGeneralA = LifeArea(id: UUID(), name: "General", color: nil, icon: "square.grid.2x2")
        let duplicateGeneralB = LifeArea(id: UUID(), name: " general ", color: "#111111", icon: "circle")
        let health = LifeArea(id: UUID(), name: "Health", color: "#00AA00", icon: "heart")

        let deferredRepository = DeferredLifeAreaRepository(storedAreas: [duplicateGeneralA, duplicateGeneralB, health])
        let lifeAreasUseCase = ManageLifeAreasUseCase(repository: deferredRepository)

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: lifeAreasUseCase,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil
        )

        viewModel.selectedLifeAreaID = duplicateGeneralB.id

        let expectation = expectation(description: "life areas loaded")
        deferredRepository.completePendingFetch()
        func assertWhenLoaded(attemptsRemaining: Int = 20) {
            if viewModel.lifeAreas.count == 2 {
                XCTAssertNil(viewModel.selectedLifeAreaID)
                let normalizedNames = Set(viewModel.lifeAreas.map { LifeAreaIdentityRepair.normalizedNameKey($0.name) })
                XCTAssertEqual(normalizedNames, Set(["general", "health"]))
                expectation.fulfill()
                return
            }

            guard attemptsRemaining > 0 else {
                XCTFail("Timed out waiting for deduped life areas to load")
                expectation.fulfill()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                assertWhenLoaded(attemptsRemaining: attemptsRemaining - 1)
            }
        }

        DispatchQueue.main.async {
            assertWhenLoaded()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testAddTaskViewModelStartsInAnyAreaStateAfterLifeAreasLoad() {
        let health = LifeArea(id: UUID(), name: "Health", color: "#00AA00", icon: "heart")
        let repository = CapturingLifeAreaRepository(storedAreas: [health])
        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: ManageProjectsUseCase(
                projectRepository: MockProjectRepository(projects: [Project.createInbox()])
            ),
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(
                repository: NoopTaskDefinitionRepository(),
                taskTagLinkRepository: nil,
                taskDependencyRepository: nil
            ),
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: repository),
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil
        )

        let expectation = expectation(description: "life areas loaded")
        DispatchQueue.main.async {
            XCTAssertEqual(viewModel.lifeAreas.map(\.name), ["Health"])
            XCTAssertNil(viewModel.selectedLifeAreaID)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

final class AddTaskViewModelTagCreationTests: XCTestCase {
    func testCreateTagAddsChipAndSelectsTag() throws {
        let tagRepository = InMemoryTagRepositoryForAddTaskTests()
        let manageTagsUseCase = ManageTagsUseCase(repository: tagRepository)

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: manageTagsUseCase
        )

        let createExpectation = expectation(description: "tag created")
        viewModel.createTag(name: "Errands") { success in
            XCTAssertTrue(success)
            createExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(viewModel.tags.count, 1)
        guard let createdTag = viewModel.tags.first else {
            XCTFail("Expected created tag in view model")
            return
        }
        XCTAssertEqual(createdTag.name, "Errands")
        XCTAssertTrue(viewModel.selectedTagIDs.contains(createdTag.id))

        let reloadedViewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: manageTagsUseCase
        )
        let reloadExpectation = expectation(description: "reloaded tags fetched")
        DispatchQueue.main.async {
            XCTAssertTrue(reloadedViewModel.tags.contains(where: { $0.id == createdTag.id }))
            reloadExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
}

@MainActor
final class AddTaskViewModelAISuggestionPerformanceTests: XCTestCase {
    override func tearDown() {
        V2FeatureFlags.assistantCopilotEnabled = true
        UserDefaults.standard.removeObject(forKey: "currentModelName")
        UserDefaults.standard.removeObject(forKey: "installedModels")
        super.tearDown()
    }

    func testDeferredRefineKeepsInstantSuggestionWhenRuntimeIsCold() {
        V2FeatureFlags.assistantCopilotEnabled = true

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        var refineInvocationCount = 0
        let aiSuggestionService = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, _, _, _, _ in
                refineInvocationCount += 1
                return """
                {"priority":"high","energy":"high","type":"morning","context":"computer","rationale":"refined","confidence":0.9}
                """
            }
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil,
            gamificationEngine: nil,
            aiSuggestionService: aiSuggestionService,
            isAISuggestionRefinementReady: { false }
        )

        let expectation = expectation(description: "heuristic suggestion surfaced")
        viewModel.taskName = "call pharmacy before lunch"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            XCTAssertEqual(refineInvocationCount, 0)
            XCTAssertNotNil(viewModel.aiSuggestion)
            XCTAssertNil(viewModel.aiSuggestion?.modelName)
            XCTAssertFalse(viewModel.aiSuggestionIsRefined)
            XCTAssertFalse(viewModel.isGeneratingSuggestion)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.5)
    }

    func testRapidTypingCancelsStaleRefineBeforePublishing() {
        V2FeatureFlags.assistantCopilotEnabled = true
        configureInstalledModels([ModelConfiguration.qwen_3_0_6b_4bit.name])

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let aiSuggestionService = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, thread, _, _, _ in
                let prompt = thread.messages.first?.content ?? ""
                if prompt.contains("draft weekly plan for team sync") {
                    try? await _Concurrency.Task.sleep(nanoseconds: 600_000_000)
                    return """
                    {"priority":"high","energy":"high","type":"morning","context":"computer","rationale":"stale-first","confidence":0.9}
                    """
                }

                try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
                return """
                {"priority":"low","energy":"medium","type":"evening","context":"anywhere","rationale":"latest-second","confidence":0.7}
                """
            }
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil,
            gamificationEngine: nil,
            aiSuggestionService: aiSuggestionService,
            isAISuggestionRefinementReady: { true }
        )

        let expectation = expectation(description: "latest refined suggestion wins")
        viewModel.taskName = "draft weekly plan for team sync"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            viewModel.taskName = "call dentist after standup"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            XCTAssertEqual(viewModel.taskName, "call dentist after standup")
            XCTAssertEqual(viewModel.aiSuggestion?.rationale, "latest-second")
            XCTAssertEqual(viewModel.aiSuggestion?.type, .evening)
            XCTAssertTrue(viewModel.aiSuggestionIsRefined)
            XCTAssertFalse(viewModel.isGeneratingSuggestion)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.5)
    }

    private func configureInstalledModels(_ models: [String]) {
        let data = try? JSONEncoder().encode(models)
        UserDefaults.standard.set(data, forKey: "installedModels")
        UserDefaults.standard.removeObject(forKey: "currentModelName")
    }
}

final class DefaultTaskIconResolverTests: XCTestCase {
    func testSearchUsesBundledSymbolManifest() {
        let results = DefaultTaskIconResolver.shared.search(
            query: "stethoscope",
            preferredSymbols: [],
            limit: 8
        )

        XCTAssertTrue(results.contains(where: { $0.symbolName == "stethoscope" }))
    }

    func testResolveSelectsSemanticSymbolForStrongTitle() {
        let resolution = DefaultTaskIconResolver.shared.resolve(
            title: "phone call vendor",
            projectName: nil,
            projectIconSymbolName: nil,
            lifeAreaName: nil,
            category: .general,
            currentSymbolName: nil,
            selectionSource: .auto
        )

        XCTAssertEqual(resolution.selectedSymbolName, "phone.fill")
        XCTAssertEqual(resolution.fallbackReason, .semantic)
        XCTAssertFalse(resolution.didUseFallback)
    }

    func testResolveUsesCategoryFallbackForGenericTitle() {
        let resolution = DefaultTaskIconResolver.shared.resolve(
            title: "misc admin",
            projectName: nil,
            projectIconSymbolName: nil,
            lifeAreaName: nil,
            category: .shopping,
            currentSymbolName: nil,
            selectionSource: .auto
        )

        XCTAssertEqual(resolution.selectedSymbolName, "cart.fill")
        XCTAssertEqual(resolution.fallbackReason, .category)
        XCTAssertTrue(resolution.didUseFallback)
    }
}

@MainActor
final class AddTaskViewModelTaskIconTests: XCTestCase {
    override func tearDown() {
        V2FeatureFlags.autoTaskIconsEnabled = true
        super.tearDown()
    }

    func testAutoResolvedIconIsPersistedInCreateRequest() {
        V2FeatureFlags.autoTaskIconsEnabled = true
        let repository = CapturingAddTaskRepository()
        let resolver = StubTaskIconResolver()
        resolver.nextResolution = TaskIconResolution(
            selectedSymbolName: "phone.fill",
            autoSuggestedSymbolName: "phone.fill",
            rankedSuggestions: [
                TaskIconOption(symbolName: "phone.fill", displayName: "Phone Fill", searchTerms: [], aliases: [], categories: [])
            ],
            confidence: 0.95,
            didUseFallback: false,
            fallbackReason: .semantic
        )
        let viewModel = makeAddTaskScheduleViewModel(repository: repository, taskIconResolver: resolver)

        viewModel.taskName = "call pharmacy"

        let iconResolved = expectation(description: "icon resolved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(viewModel.displayedTaskIconSymbolName, "phone.fill")
            viewModel.createTask()
            iconResolved.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.lastCreateRequest?.iconSymbolName, "phone.fill")
    }

    func testManualIconOverrideSurvivesFurtherTyping() {
        V2FeatureFlags.autoTaskIconsEnabled = true
        let resolver = StubTaskIconResolver()
        resolver.nextResolution = TaskIconResolution(
            selectedSymbolName: "phone.fill",
            autoSuggestedSymbolName: "phone.fill",
            rankedSuggestions: [
                TaskIconOption(symbolName: "phone.fill", displayName: "Phone Fill", searchTerms: [], aliases: [], categories: []),
                TaskIconOption(symbolName: "stethoscope", displayName: "Stethoscope", searchTerms: [], aliases: [], categories: [])
            ],
            confidence: 0.95,
            didUseFallback: false,
            fallbackReason: .semantic
        )
        let viewModel = makeAddTaskScheduleViewModel(taskIconResolver: resolver)

        viewModel.taskName = "call pharmacy"

        let expectation = expectation(description: "manual override retained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.applyManualTaskIconSelection(symbolName: "stethoscope")
            resolver.nextResolution = TaskIconResolution(
                selectedSymbolName: "briefcase.fill",
                autoSuggestedSymbolName: "briefcase.fill",
                rankedSuggestions: [
                    TaskIconOption(symbolName: "briefcase.fill", displayName: "Briefcase Fill", searchTerms: [], aliases: [], categories: [])
                ],
                confidence: 0.95,
                didUseFallback: false,
                fallbackReason: .semantic
            )
            viewModel.taskName = "draft roadmap"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                XCTAssertEqual(viewModel.displayedTaskIconSymbolName, "stethoscope")
                XCTAssertEqual(viewModel.autoSuggestedTaskIconSymbolName, "briefcase.fill")
                XCTAssertEqual(viewModel.taskIconSelectionSource, .manual)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testResetTaskIconToAutoRestoresSuggestedSymbol() {
        V2FeatureFlags.autoTaskIconsEnabled = true
        let resolver = StubTaskIconResolver()
        resolver.nextResolution = TaskIconResolution(
            selectedSymbolName: "phone.fill",
            autoSuggestedSymbolName: "phone.fill",
            rankedSuggestions: [
                TaskIconOption(symbolName: "phone.fill", displayName: "Phone Fill", searchTerms: [], aliases: [], categories: [])
            ],
            confidence: 0.95,
            didUseFallback: false,
            fallbackReason: .semantic
        )
        let viewModel = makeAddTaskScheduleViewModel(taskIconResolver: resolver)
        viewModel.taskName = "call pharmacy"

        let expectation = expectation(description: "reset returns to auto")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.applyManualTaskIconSelection(symbolName: "stethoscope")
            resolver.nextResolution = TaskIconResolution(
                selectedSymbolName: "briefcase.fill",
                autoSuggestedSymbolName: "briefcase.fill",
                rankedSuggestions: [
                    TaskIconOption(symbolName: "briefcase.fill", displayName: "Briefcase Fill", searchTerms: [], aliases: [], categories: [])
                ],
                confidence: 0.95,
                didUseFallback: false,
                fallbackReason: .semantic
            )
            viewModel.resetTaskIconToAuto()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                XCTAssertEqual(viewModel.displayedTaskIconSymbolName, "briefcase.fill")
                XCTAssertEqual(viewModel.taskIconSelectionSource, .auto)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDisabledAutoIconsDoNotPersistFallbackIcon() {
        V2FeatureFlags.autoTaskIconsEnabled = false
        let repository = CapturingAddTaskRepository()
        let viewModel = makeAddTaskScheduleViewModel(repository: repository)

        viewModel.taskName = "call vendor"
        viewModel.createTask()

        XCTAssertNil(repository.lastCreateRequest?.iconSymbolName)
    }
}

final class HomeViewModelTaskIconTimelineTests: XCTestCase {
    func testTimelinePrefersPersistedTaskIconOverProjectIcon() {
        let suiteName = "HomeViewModelTaskIconTimelineTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let inbox = Project.createInbox()
        let workProject = Project(
            id: UUID(),
            name: "Ops",
            color: .blue,
            icon: .work
        )
        let task = TaskDefinition(
            id: UUID(),
            projectID: workProject.id,
            iconSymbolName: "phone.fill",
            title: "Call vendor",
            category: .work
        )
        let coordinator = UseCaseCoordinator(
            taskRepository: MockTaskRepository(seed: task),
            projectRepository: MockProjectRepository(projects: [inbox, workProject])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        let projectsLoaded = expectation(description: "projects loaded")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(viewModel.timelineSystemImageName(for: task), "phone.fill")
            projectsLoaded.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

final class RecurringTaskSeriesMaterializationTests: XCTestCase {
    func testCreateDailyRecurringTaskMaterializesConcreteSeriesWithSharedSeriesID() throws {
        let repository = InMemoryTaskDefinitionRepositoryStub()
        let tagLinkRepository = CapturingTaskTagLinkRepositoryForRecurrenceTests()
        let useCase = CreateTaskDefinitionUseCase(
            repository: repository,
            taskTagLinkRepository: tagLinkRepository,
            taskDependencyRepository: nil
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let tagID = UUID()
        let request = CreateTaskDefinitionRequest(
            title: "Daily workout",
            details: "Stay consistent",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: startDate,
            tagIDs: [tagID],
            repeatPattern: .daily
        )

        let created = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }

        guard let seriesID = created.recurrenceSeriesID else {
            XCTFail("Expected recurrence series ID on recurring root task")
            return
        }

        let seriesTasks = repository.byID.values
            .filter { $0.recurrenceSeriesID == seriesID }
            .sorted {
                guard let left = $0.dueDate, let right = $1.dueDate else { return $0.id.uuidString < $1.id.uuidString }
                return left < right
            }

        XCTAssertGreaterThan(seriesTasks.count, 1, "Expected concrete future tasks for daily recurring series")
        XCTAssertEqual(seriesTasks.first?.id, created.id)
        XCTAssertTrue(seriesTasks.dropFirst().allSatisfy { $0.repeatPattern == nil })
        XCTAssertTrue(seriesTasks.allSatisfy { Set($0.tagIDs) == Set([tagID]) })

        let calendar = Calendar.current
        let uniqueDays = Set(seriesTasks.compactMap { $0.dueDate }.map { calendar.startOfDay(for: $0) })
        XCTAssertEqual(uniqueDays.count, seriesTasks.count, "Expected one task per day in series")
    }

    func testMaintainRecurringSeriesIsDedupedAcrossRuns() throws {
        let repository = InMemoryTaskDefinitionRepositoryStub()
        let tagLinkRepository = CapturingTaskTagLinkRepositoryForRecurrenceTests()
        let useCase = CreateTaskDefinitionUseCase(
            repository: repository,
            taskTagLinkRepository: tagLinkRepository,
            taskDependencyRepository: nil
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let request = CreateTaskDefinitionRequest(
            title: "Weekday focus",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: startDate,
            repeatPattern: .weekdays
        )

        let created = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }
        let initialSeriesCount = repository.byID.values.count

        let firstTopUpCount = try awaitResult { completion in
            useCase.maintainRecurringSeries(daysAhead: 45, completion: completion)
        }
        let secondTopUpCount = try awaitResult { completion in
            useCase.maintainRecurringSeries(daysAhead: 45, completion: completion)
        }

        XCTAssertEqual(firstTopUpCount, 0)
        XCTAssertEqual(secondTopUpCount, 0)
        XCTAssertEqual(repository.byID.values.count, initialSeriesCount)

        let seriesTasks = repository.byID.values.filter { $0.recurrenceSeriesID == created.recurrenceSeriesID }
        XCTAssertGreaterThan(seriesTasks.count, 1)
    }
}

final class DeleteTaskDefinitionUseCaseSeriesScopeTests: XCTestCase {
    func testDeleteSingleScopeDeletesOnlyTargetTask() throws {
        let seriesID = UUID()
        let first = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 1")
        let second = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 2")
        let third = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 3")
        let unrelated = TaskDefinition(recurrenceSeriesID: UUID(), title: "Unrelated")
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [first, second, third, unrelated])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository, tombstoneRepository: nil)

        let _: Void = try awaitResult { completion in
            useCase.execute(taskID: second.id, scope: TaskDeleteScope.single, completion: completion)
        }

        let remaining = Set(repository.byID.keys)
        XCTAssertFalse(remaining.contains(second.id))
        XCTAssertTrue(remaining.contains(first.id))
        XCTAssertTrue(remaining.contains(third.id))
        XCTAssertTrue(remaining.contains(unrelated.id))
    }

    func testDeleteSeriesScopeDeletesAllTasksInSeriesOnly() throws {
        let seriesID = UUID()
        let first = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 1")
        let second = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 2")
        let third = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 3")
        let unrelated = TaskDefinition(recurrenceSeriesID: UUID(), title: "Unrelated")
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [first, second, third, unrelated])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository, tombstoneRepository: nil)

        let _: Void = try awaitResult { completion in
            useCase.execute(taskID: second.id, scope: TaskDeleteScope.series, completion: completion)
        }

        let remaining = Set(repository.byID.keys)
        XCTAssertFalse(remaining.contains(first.id))
        XCTAssertFalse(remaining.contains(second.id))
        XCTAssertFalse(remaining.contains(third.id))
        XCTAssertTrue(remaining.contains(unrelated.id))
    }
}

private final class InMemoryTagRepositoryForAddTaskTests: TagRepositoryProtocol {
    private(set) var tags: [TagDefinition] = []

    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        completion(.success(tags))
    }

    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        tags.removeAll(where: { $0.id == tag.id })
        tags.append(tag)
        completion(.success(tag))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        tags.removeAll(where: { $0.id == id })
        completion(.success(()))
    }
}

private final class CapturingTaskTagLinkRepositoryForRecurrenceTests: TaskTagLinkRepositoryProtocol {
    private var linksByTaskID: [UUID: Set<UUID>] = [:]

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        completion(.success(Array(linksByTaskID[taskID] ?? []).sorted { $0.uuidString < $1.uuidString }))
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        linksByTaskID[taskID] = Set(tagIDs)
        completion(.success(()))
    }
}

private final class CapturingLifeAreaRepository: LifeAreaRepositoryProtocol {
    private(set) var storedAreas: [LifeArea]
    private(set) var createCallCount = 0

    init(storedAreas: [LifeArea]) {
        self.storedAreas = storedAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(storedAreas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        createCallCount += 1
        storedAreas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class DeferredLifeAreaRepository: LifeAreaRepositoryProtocol {
    private let storedAreas: [LifeArea]
    private var pendingFetchCompletion: ((Result<[LifeArea], Error>) -> Void)?

    init(storedAreas: [LifeArea]) {
        self.storedAreas = storedAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        pendingFetchCompletion = completion
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func completePendingFetch() {
        pendingFetchCompletion?(.success(storedAreas))
        pendingFetchCompletion = nil
    }
}

final class HabitRuntimeRemediationTests: XCTestCase {
    func testCreateHabitKeepsLapseOnlyTemplateActiveAndGeneratesOccurrences() throws {
        let anchorDate = Date(timeIntervalSince1970: 1_704_132_000) // 2024-01-01 18:00:00 UTC
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)

        let habit = try awaitResult { completion in
            stack.createHabitUseCase.execute(
                request: CreateHabitRequest(
                    title: "No smoking",
                    lifeAreaID: stack.lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "nosign", categoryKey: "recovery"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        XCTAssertEqual(habit.trackingMode, .lapseOnly)
        XCTAssertEqual(stack.scheduleRepository.templates.count, 1)
        XCTAssertEqual(stack.scheduleRepository.templates.first?.isActive, true)

        let templateID = try XCTUnwrap(stack.scheduleRepository.templates.first?.id)
        XCTAssertEqual(stack.scheduleRepository.rulesByTemplateID[templateID]?.count, 1)
        XCTAssertTrue(
            stack.occurrenceRepository.occurrences.contains(where: {
                $0.sourceID == habit.id && Calendar.current.isDate($0.dueAt ?? $0.scheduledAt, inSameDayAs: anchorDate)
            })
        )
    }

    func testMaintainHabitRuntimeAutoCompletesPreviousLapseOnlyDay() throws {
        let anchorDate = Date(timeIntervalSince1970: 1_704_132_000) // 2024-01-01 18:00:00 UTC
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)

        let habit = try awaitResult { completion in
            stack.createHabitUseCase.execute(
                request: CreateHabitRequest(
                    title: "No alcohol",
                    lifeAreaID: stack.lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "drop", categoryKey: "recovery"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate
        _ = try awaitResult { completion in
            stack.maintainHabitRuntimeUseCase.execute(anchorDate: nextDay, completion: completion)
        }

        let previousDayOccurrence = try XCTUnwrap(
            stack.occurrenceRepository.occurrences.first(where: {
                $0.sourceID == habit.id && Calendar.current.isDate($0.dueAt ?? $0.scheduledAt, inSameDayAs: anchorDate)
            })
        )
        XCTAssertEqual(previousDayOccurrence.state, .completed)
        XCTAssertEqual(stack.habitRepository.habitsByID[habit.id]?.streakCurrent, 1)
    }

    func testMaintainHabitRuntimeCompletesAllPendingLapseOnlyDaysAfterLongInactivity() throws {
        let anchorDate = Date(timeIntervalSince1970: 1_704_132_000)
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)

        let habit = try awaitResult { completion in
            stack.createHabitUseCase.execute(
                request: CreateHabitRequest(
                    title: "No alcohol",
                    lifeAreaID: stack.lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "drop", categoryKey: "recovery"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        let eightDaysLater = Calendar.current.date(byAdding: .day, value: 8, to: anchorDate) ?? anchorDate
        _ = try awaitResult { completion in
            stack.maintainHabitRuntimeUseCase.execute(anchorDate: eightDaysLater, completion: completion)
        }

        let calendar = Calendar.current
        let createdDayStart = calendar.startOfDay(for: anchorDate)
        let targetDayStart = calendar.startOfDay(for: eightDaysLater)
        let preTodayOccurrences = stack.occurrenceRepository.occurrences.filter {
            $0.sourceID == habit.id &&
            ($0.dueAt ?? $0.scheduledAt) < targetDayStart
        }
        let repairedOccurrences = preTodayOccurrences.filter { occurrence in
            (occurrence.dueAt ?? occurrence.scheduledAt) >= createdDayStart
        }
        let currentRunDayCount = Set(repairedOccurrences.map { occurrence in
            let occurrenceDate = occurrence.dueAt ?? occurrence.scheduledAt
            return calendar.startOfDay(for: occurrenceDate)
        }).count

        XCTAssertFalse(repairedOccurrences.isEmpty)
        XCTAssertTrue(repairedOccurrences.allSatisfy { $0.state == .completed })
        XCTAssertEqual(currentRunDayCount, 8)
        XCTAssertEqual(stack.habitRepository.habitsByID[habit.id]?.streakCurrent, currentRunDayCount)
    }

    func testResolveHabitOccurrenceMaterializesMissingLapseOnlyDayAsFailed() throws {
        let anchorDate = Date(timeIntervalSince1970: 1_704_132_000) // 2024-01-01 18:00:00 UTC
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)

        let habit = try awaitResult { completion in
            stack.createHabitUseCase.execute(
                request: CreateHabitRequest(
                    title: "No vaping",
                    lifeAreaID: stack.lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "lungs", categoryKey: "recovery"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        let targetDate = Calendar.current.date(byAdding: .day, value: 2, to: anchorDate) ?? anchorDate
        stack.occurrenceRepository.occurrences.removeAll {
            $0.sourceID == habit.id && Calendar.current.isDate($0.dueAt ?? $0.scheduledAt, inSameDayAs: targetDate)
        }

        _ = try awaitResult { completion in
            stack.resolveHabitOccurrenceUseCase.execute(
                habitID: habit.id,
                action: .lapsed,
                on: targetDate,
                completion: completion
            )
        }

        let sameDayOccurrences = stack.occurrenceRepository.occurrences.filter {
            $0.sourceID == habit.id && Calendar.current.isDate($0.dueAt ?? $0.scheduledAt, inSameDayAs: targetDate)
        }
        XCTAssertEqual(sameDayOccurrences.count, 1)
        XCTAssertEqual(sameDayOccurrences.first?.state, .failed)
        XCTAssertEqual(sameDayOccurrences.first?.generationWindow, "ad_hoc_habit_lapse")
        XCTAssertEqual(stack.habitRepository.habitsByID[habit.id]?.streakCurrent, 0)
    }

    func testUpdateHabitNormalizesPositiveHabitToDailyCheckInTracking() throws {
        let anchorDate = Date(timeIntervalSince1970: 1_704_132_000)
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)

        let created = try awaitResult { completion in
            stack.createHabitUseCase.execute(
                request: CreateHabitRequest(
                    title: "Quit sugar",
                    lifeAreaID: stack.lifeAreaID,
                    kind: .negative,
                    trackingMode: .lapseOnly,
                    icon: HabitIconMetadata(symbolName: "fork.knife", categoryKey: "nutrition"),
                    cadence: .daily(hour: 18, minute: 0),
                    createdAt: anchorDate
                ),
                completion: completion
            )
        }

        let updateUseCase = UpdateHabitUseCase(
            habitRepository: stack.habitRepository,
            scheduleRepository: stack.scheduleRepository,
            scheduleEngine: CoreSchedulingEngine(
                scheduleRepository: stack.scheduleRepository,
                occurrenceRepository: stack.occurrenceRepository
            ),
            projectRepository: MockProjectRepository(projects: []),
            lifeAreaRepository: CapturingLifeAreaRepository(
                storedAreas: [LifeArea(id: stack.lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
            ),
            maintainHabitRuntimeUseCase: stack.maintainHabitRuntimeUseCase
        )

        let updated = try awaitResult { completion in
            updateUseCase.execute(
                request: UpdateHabitRequest(
                    id: created.id,
                    kind: .positive,
                    trackingMode: .lapseOnly,
                    updatedAt: anchorDate.addingTimeInterval(60)
                ),
                completion: completion
            )
        }

        XCTAssertEqual(updated.kind, HabitKind.positive)
        XCTAssertEqual(updated.trackingMode, HabitTrackingMode.dailyCheckIn)
        XCTAssertEqual(stack.habitRepository.habitsByID[created.id]?.trackingMode, HabitTrackingMode.dailyCheckIn)
    }

    func testRecomputeHabitStreaksRebuildsBestFromOccurrences() throws {
        let habitID = UUID()
        let lifeAreaID = UUID()
        let day1 = Date(timeIntervalSince1970: 1_704_067_200)
        let day2 = day1.addingTimeInterval(86_400)
        let day3 = day2.addingTimeInterval(86_400)

        let habitRepository = InMemoryHabitRepository(seed: [
            HabitDefinitionRecord(
                id: habitID,
                lifeAreaID: lifeAreaID,
                title: "Hydrate",
                habitType: "check_in",
                kindRaw: HabitKind.positive.rawValue,
                trackingModeRaw: HabitTrackingMode.dailyCheckIn.rawValue,
                streakCurrent: 99,
                streakBest: 99,
                createdAt: day1,
                updatedAt: day3
            )
        ])
        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [
            makeHabitOccurrence(habitID: habitID, scheduledAt: day1, state: .completed),
            makeHabitOccurrence(habitID: habitID, scheduledAt: day2, state: .completed),
            makeHabitOccurrence(habitID: habitID, scheduledAt: day3, state: .failed)
        ]

        let useCase = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )

        _ = try awaitResult { completion in
            useCase.execute(habitIDs: [habitID], referenceDate: day3, completion: completion)
        }

        XCTAssertEqual(habitRepository.habitsByID[habitID]?.streakCurrent, 0)
        XCTAssertEqual(habitRepository.habitsByID[habitID]?.streakBest, 2)
        XCTAssertNotEqual(habitRepository.habitsByID[habitID]?.failureMask14Raw, 0)
    }

    func testCalculateDailyAnalyticsFetchesHabitSignalsWhenOmitted() throws {
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let summary = HabitOccurrenceSummary(
            habitID: UUID(),
            occurrenceID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "hydration"),
            dueAt: date,
            state: .completed,
            currentStreak: 3,
            bestStreak: 6,
            riskState: .stable,
            last14Days: []
        )
        let habitReadRepository = CapturingHabitRuntimeReadRepository(signalSummaries: [summary])
        let useCase = CalculateAnalyticsUseCase(
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(),
            habitRuntimeReadRepository: habitReadRepository
        )

        let analytics = try awaitResult { (completion: @escaping (Result<DailyAnalytics, Error>) -> Void) in
            useCase.calculateDailyAnalytics(for: date) { result in
                completion(result.mapError { $0 })
            }
        }

        XCTAssertEqual(habitReadRepository.fetchSignalsCallCount, 1)
        XCTAssertEqual(analytics.habitAnalytics.dueHabits, 1)
        XCTAssertEqual(analytics.habitAnalytics.completedPositiveHabits, 1)
    }

    func testComputeEvaHomeInsightsFetchesHabitSignalsInternally() {
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let summary = HabitOccurrenceSummary(
            habitID: UUID(),
            occurrenceID: UUID(),
            title: "Meditate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Mind",
            icon: HabitIconMetadata(symbolName: "brain.head.profile", categoryKey: "mind"),
            dueAt: date,
            state: .pending,
            currentStreak: 4,
            bestStreak: 9,
            riskState: .stable,
            last14Days: []
        )
        let habitReadRepository = CapturingHabitRuntimeReadRepository(signalSummaries: [summary])
        let task = TaskDefinition(
            id: UUID(),
            projectID: UUID(),
            projectName: "Inbox",
            title: "Write summary",
            dueDate: date,
            isComplete: false,
            dateAdded: date,
            createdAt: date,
            updatedAt: date
        )
        let useCase = ComputeEvaHomeInsightsUseCase(habitRuntimeReadRepository: habitReadRepository)

        let expectation = expectation(description: "eva")
        var captured: EvaHomeInsights?
        useCase.execute(openTasks: [task], focusTasks: [task], anchorDate: date, now: date) { result in
            captured = try? result.get()
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(habitReadRepository.fetchSignalsCallCount, 1)
        XCTAssertTrue(captured?.focus.summaryLine?.contains("Habits: 1 due") ?? false)
    }

    func testLLMContextProjectionBuildTodayJSONFetchesHabitsByDefault() async {
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let summary = HabitOccurrenceSummary(
            habitID: UUID(),
            occurrenceID: UUID(),
            title: "Journal",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Mind",
            icon: HabitIconMetadata(symbolName: "book.closed", categoryKey: "mind"),
            dueAt: date,
            state: .pending,
            currentStreak: 2,
            bestStreak: 8,
            riskState: .stable,
            last14Days: []
        )
        let habitReadRepository = CapturingHabitRuntimeReadRepository(signalSummaries: [summary])
        let service = LLMContextProjectionService(
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(),
            projectRepository: MockProjectRepository(projects: []),
            lifeAreaRepository: nil,
            tagRepository: nil,
            habitRuntimeReadRepository: habitReadRepository
        )

        let json = await service.buildTodayJSON()

        XCTAssertEqual(habitReadRepository.fetchSignalsCallCount, 1)
        XCTAssertTrue(json.contains("Journal"))
    }

    @MainActor
    func testAddHabitViewModelRejectsMalformedReminderWindow() {
        let anchorDate = Date(timeIntervalSince1970: 1_704_067_200)
        let stack = makeHabitRuntimeStack(anchorDate: anchorDate)
        let viewModel = AddHabitViewModel(
            createHabitUseCase: stack.createHabitUseCase,
            manageLifeAreasUseCase: ManageLifeAreasUseCase(
                repository: CapturingLifeAreaRepository(
                    storedAreas: [LifeArea(id: stack.lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
                )
            ),
            manageProjectsUseCase: ManageProjectsUseCase(
                projectRepository: MockProjectRepository(projects: [])
            )
        )

        viewModel.habitName = "Hydrate"
        viewModel.selectedLifeAreaID = stack.lifeAreaID
        viewModel.reminderWindowStart = "25:99"

        XCTAssertEqual(viewModel.reminderWindowValidationError, "Reminder start must use HH:mm.")
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testBuildHomeAgendaOrdersOverdueThenTodayAcrossTasksAndHabits() {
        let date = Date(timeIntervalSince1970: 1_704_240_000) // 2024-01-03 00:00:00 UTC
        let overdueTask = TaskDefinition(
            id: UUID(),
            projectID: UUID(),
            projectName: "Inbox",
            title: "Overdue task",
            dueDate: date.addingTimeInterval(-86_400),
            isComplete: false,
            dateAdded: date,
            createdAt: date,
            updatedAt: date
        )
        let dueTask = TaskDefinition(
            id: UUID(),
            projectID: UUID(),
            projectName: "Inbox",
            title: "Due task",
            dueDate: date.addingTimeInterval(36_000),
            isComplete: false,
            dateAdded: date,
            createdAt: date,
            updatedAt: date
        )
        let dueHabit = HomeHabitRow(
            habitID: UUID(),
            title: "Walk",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            iconSymbolName: "figure.walk",
            dueAt: date.addingTimeInterval(18_000),
            state: .due
        )
        let completedHabit = HomeHabitRow(
            habitID: UUID(),
            title: "Journal",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Mind",
            iconSymbolName: "book.closed",
            dueAt: date.addingTimeInterval(21_600),
            state: .completedToday
        )

        let result = BuildHomeAgendaUseCase().execute(
            date: date,
            taskRows: [dueTask, overdueTask],
            habitRows: [completedHabit, dueHabit]
        )

        XCTAssertEqual(result.taskCount, 2)
        XCTAssertEqual(result.habitCount, 2)
        XCTAssertEqual(
            result.rows.map(\.id),
            [
                HomeTodayRow.task(overdueTask).id,
                HomeTodayRow.habit(dueHabit).id,
                HomeTodayRow.task(dueTask).id,
                HomeTodayRow.habit(completedHabit).id
            ]
        )
    }

    private func makeHabitRuntimeStack(anchorDate: Date) -> HabitRuntimeTestStack {
        let lifeAreaID = UUID()
        let lifeAreaRepository = CapturingLifeAreaRepository(
            storedAreas: [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
        )
        let projectRepository = MockProjectRepository(projects: [])
        let habitRepository = InMemoryHabitRepository()
        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        let schedulingEngine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )
        let recomputeHabitStreaksUseCase = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let syncHabitScheduleUseCase = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recomputeHabitStreaksUseCase
        )
        let maintainHabitRuntimeUseCase = MaintainHabitRuntimeUseCase(
            syncHabitScheduleUseCase: syncHabitScheduleUseCase
        )
        let gamificationRepository = InMemoryGamificationEngineRepository()
        let gamificationEngine = GamificationEngine(repository: gamificationRepository)

        return HabitRuntimeTestStack(
            lifeAreaID: lifeAreaID,
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository,
            createHabitUseCase: CreateHabitUseCase(
                habitRepository: habitRepository,
                lifeAreaRepository: lifeAreaRepository,
                projectRepository: projectRepository,
                scheduleRepository: scheduleRepository,
                maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
            ),
            maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase,
            resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                occurrenceRepository: occurrenceRepository,
                scheduleEngine: schedulingEngine,
                recomputeHabitStreaksUseCase: recomputeHabitStreaksUseCase,
                gamificationEngine: gamificationEngine
            )
        )
    }

    private func makeHabitOccurrence(
        habitID: UUID,
        scheduledAt: Date,
        state: OccurrenceState
    ) -> OccurrenceDefinition {
        OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "\(UUID().uuidString)|\(scheduledAt.timeIntervalSince1970)|\(habitID.uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .habit,
            sourceID: habitID,
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: state,
            isGenerated: true,
            generationWindow: "test",
            createdAt: scheduledAt,
            updatedAt: scheduledAt
        )
    }
}

private struct HabitRuntimeTestStack {
    let lifeAreaID: UUID
    let habitRepository: InMemoryHabitRepository
    let scheduleRepository: InMemoryScheduleRepository
    let occurrenceRepository: InMemoryOccurrenceRepository
    let createHabitUseCase: CreateHabitUseCase
    let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    let resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase
}

private func workspaceRootURLForTests() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
}

@discardableResult
private func runProcess(
    executable: String,
    arguments: [String],
    in directory: URL
) throws -> Int32 {
#if os(macOS)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
#else
    _ = executable
    _ = arguments
    _ = directory
    throw NSError(domain: "runProcess", code: 501, userInfo: [NSLocalizedDescriptionKey: "Process execution unavailable on iOS simulator test runtime"])
#endif
}

@discardableResult
private func runShellCommand(_ command: String, in directory: URL) throws -> Int32 {
#if os(macOS)
    try runProcess(
        executable: "/bin/zsh",
        arguments: ["-lc", command],
        in: directory
    )
#else
    _ = command
    _ = directory
    throw NSError(domain: "runShellCommand", code: 501, userInfo: [NSLocalizedDescriptionKey: "Shell commands unavailable on iOS simulator test runtime"])
#endif
}

private extension XCTestCase {
    func awaitResult<T>(
        timeout: TimeInterval = 2.0,
        _ execute: (@escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let expectation = expectation(description: "awaitResult")
        var captured: Result<T, Error>?
        execute { result in
            captured = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout)
        return try XCTUnwrap(captured).get()
    }
}

final class TaskDefinitionClearFlagPersistenceTests: XCTestCase {
    func testUpdateRequestClearFlagsRemovePersistedOptionalFields() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)

        let taskID = UUID()
        let lifeAreaID = UUID()
        let sectionID = UUID()
        let dueDate = Date().addingTimeInterval(86_400)
        let reminderTime = Date().addingTimeInterval(43_200)

        _ = try awaitResult { completion in
            repository.create(
                request: CreateTaskDefinitionRequest(
                    id: taskID,
                    title: "Clear me",
                    details: "Has optional metadata",
                    projectID: ProjectConstants.inboxProjectID,
                    projectName: ProjectConstants.inboxProjectName,
                    lifeAreaID: lifeAreaID,
                    sectionID: sectionID,
                    dueDate: dueDate,
                    alertReminderTime: reminderTime,
                    estimatedDuration: 45 * 60,
                    repeatPattern: .daily,
                    createdAt: Date()
                ),
                completion: completion
            )
        }

        _ = try awaitResult { completion in
            repository.update(
                request: UpdateTaskDefinitionRequest(
                    id: taskID,
                    clearLifeArea: true,
                    clearSection: true,
                    clearDueDate: true,
                    clearReminderTime: true,
                    clearEstimatedDuration: true,
                    clearRepeatPattern: true
                ),
                completion: completion
            )
        }

        let updated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let task = try XCTUnwrap(updated)

        XCTAssertNil(task.lifeAreaID)
        XCTAssertNil(task.sectionID)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.alertReminderTime)
        XCTAssertNil(task.estimatedDuration)
        XCTAssertNil(task.repeatPattern)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskDefinitionClearFlagPersistenceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

private final class CountingTaskDefinitionRepositorySpy: TaskDefinitionRepositoryProtocol {
    private let base: InMemoryTaskDefinitionRepositoryStub
    private(set) var fetchAllInvocationCount = 0

    init(seed: [TaskDefinition] = []) {
        self.base = InMemoryTaskDefinitionRepositoryStub(seed: seed)
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAllInvocationCount += 1
        base.fetchAll(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAllInvocationCount += 1
        base.fetchAll(query: query, completion: completion)
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        base.fetchTaskDefinition(id: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(task, completion: completion)
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(request: request, completion: completion)
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.update(task, completion: completion)
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.update(request: request, completion: completion)
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        base.delete(id: id, completion: completion)
    }
}

final class TaskNotificationOrchestratorTests: XCTestCase {
    func testReconcileCoalescesBurstReasonsIntoSingleFetchPass() {
        let notificationService = CapturingNotificationService()
        let repository = CountingTaskDefinitionRepositorySpy(seed: [])
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate },
            reconcileDebounceInterval: 0.05
        )

        let expectation = expectation(description: "coalesced reconcile finished")
        orchestrator.reconcile(reason: "scene_active")
        orchestrator.reconcile(reason: "scene_foreground")
        orchestrator.reconcile(reason: "scene_background")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(repository.fetchAllInvocationCount, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDailyNotificationsUseDefaultTimesAndFallbackCopy() {
        let notificationService = CapturingNotificationService()
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        let morningIDs = Set(
            notificationService.scheduled
                .filter { $0.kind == .morningPlan }
                .map(\.id)
        )
        XCTAssertEqual(
            morningIDs,
            Set(["daily.morning.20260224", "daily.morning.20260225", "daily.morning.20260226"])
        )

        let morning = notificationService.scheduled.first(where: { $0.id == "daily.morning.20260224" })
        XCTAssertEqual(morning?.title, "Morning Plan")
        XCTAssertEqual(morning?.body, "No tasks queued. Capture one meaningful win.")
        XCTAssertEqual(morning.map { calendar.component(.hour, from: $0.fireDate) }, 8)
        XCTAssertEqual(morning.map { calendar.component(.minute, from: $0.fireDate) }, 0)
        XCTAssertEqual(
            morning?.route,
            .dailySummary(kind: .morning, dateStamp: "20260224")
        )

        let nightlySummaryIDs = Set(
            notificationService.scheduled
                .map(\.id)
                .filter { $0.hasPrefix("daily.nightly.") }
        )
        XCTAssertEqual(
            nightlySummaryIDs,
            Set(["daily.nightly.20260224", "daily.nightly.20260225", "daily.nightly.20260226"])
        )

        let reflectionIDs = Set(
            notificationService.scheduled
                .map(\.id)
                .filter { $0.hasPrefix("daily.reflection.") }
        )
        XCTAssertEqual(
            reflectionIDs,
            Set([
                "daily.reflection.20260224.evening",
                "daily.reflection.20260224.followup",
                "daily.reflection.20260225.evening",
                "daily.reflection.20260225.followup",
                "daily.reflection.20260226.evening",
                "daily.reflection.20260226.followup"
            ])
        )

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(nightly?.title, "Day Retrospective")
        XCTAssertEqual(nightly?.body, "No completions today. Pick one tiny restart for tomorrow.")
        XCTAssertEqual(nightly.map { calendar.component(.hour, from: $0.fireDate) }, 21)
        XCTAssertEqual(nightly.map { calendar.component(.minute, from: $0.fireDate) }, 0)
        XCTAssertEqual(
            nightly?.route,
            .dailySummary(kind: .nightly, dateStamp: "20260224")
        )
    }

    func testNightlyRetrospectiveUsesExactLedgerXPWhenAvailable() {
        let notificationService = CapturingNotificationService()
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let completionDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 18, minute: 45)

        var completedTask = TaskDefinition(title: "Ship release notes", priority: .high, isComplete: true)
        completedTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 17, minute: 0)
        completedTask.dateCompleted = completionDate

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [completedTask])
        let store = makePreferencesStore()
        let gamificationRepository = InsightsRepositorySpy()
        gamificationRepository.weekAggregates = [
            DailyXPAggregateDefinition(dateKey: "2026-02-24", totalXP: 44, eventCount: 2)
        ]

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            gamificationRepository: gamificationRepository,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_exact_xp")

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(
            nightly?.body,
            "Completed 1/1 tasks, earned 44 XP. Biggest win: \"Ship release notes\"."
        )
    }

    func testNightlyRetrospectiveOmitsNumericXPWhenExactAggregateUnavailable() {
        let notificationService = CapturingNotificationService()
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let completionDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 19, minute: 10)

        var completedTask = TaskDefinition(title: "Close loops", priority: .low, isComplete: true)
        completedTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0)
        completedTask.dateCompleted = completionDate

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [completedTask])
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_no_exact_xp")

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(
            nightly?.body,
            "Completed 1/1 tasks. Biggest win: \"Close loops\". Open Tasker for exact XP."
        )
    }

    func testReconcileSchedulesTaskReminderDueSoonAndOverdueWithExpectedContent() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var reminderTask = TaskDefinition(title: "Write report")
        reminderTask.dueDate = nowDate.addingTimeInterval(3 * 3600)
        reminderTask.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        var dueSoonPrimary = TaskDefinition(title: "Send status update", priority: .high)
        dueSoonPrimary.dueDate = nowDate.addingTimeInterval(45 * 60)

        var dueSoonSecondary = TaskDefinition(title: "Check inbox", priority: .low)
        dueSoonSecondary.dueDate = nowDate.addingTimeInterval(90 * 60)

        var overdue = TaskDefinition(title: "Submit invoice", priority: .max)
        overdue.dueDate = nowDate.addingTimeInterval(-26 * 3600)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [reminderTask, dueSoonPrimary, dueSoonSecondary, overdue])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        let reminderID = "task.reminder.\(reminderTask.id.uuidString)"
        let reminder = notificationService.scheduled.first(where: { $0.id == reminderID })
        XCTAssertEqual(
            reminder?.title,
            "Task Reminder"
        )
        XCTAssertEqual(reminder?.route, .taskDetail(taskID: reminderTask.id))

        let dueSoonID = "task.dueSoon.\(dueSoonPrimary.id.uuidString).20260224"
        let dueSoon = notificationService.scheduled.first(where: { $0.id == dueSoonID })
        let dueSoonBody = dueSoon?.body ?? ""
        XCTAssertTrue(dueSoonBody.contains("\"Send status update\" is due in"))
        XCTAssertTrue(dueSoonBody.contains("+ 1 more due soon"))
        XCTAssertEqual(notificationService.scheduled.filter { $0.kind == .dueSoon }.count, 1)
        XCTAssertEqual(dueSoon?.route, .taskDetail(taskID: dueSoonPrimary.id))

        let overdueAMID = "task.overdue.\(overdue.id.uuidString).20260224.am"
        let overdueAM = notificationService.scheduled.first(where: { $0.id == overdueAMID })
        let overdueBody = overdueAM?.body ?? ""
        XCTAssertEqual(overdueBody, "\"Submit invoice\" is overdue by 1 day(s).")
        XCTAssertEqual(overdueAM?.route, .taskDetail(taskID: overdue.id))

        let overdueTomorrowAMID = "task.overdue.\(overdue.id.uuidString).20260225.am"
        let overdueTomorrowPMID = "task.overdue.\(overdue.id.uuidString).20260225.pm"
        XCTAssertEqual(
            notificationService.scheduled.first(where: { $0.id == overdueTomorrowAMID })?.route,
            .taskDetail(taskID: overdue.id)
        )
        XCTAssertEqual(
            notificationService.scheduled.first(where: { $0.id == overdueTomorrowPMID })?.route,
            .taskDetail(taskID: overdue.id)
        )
    }

    func testReconcileCancelsStaleManagedIdentifiersAndKeepsUnmanagedOnes() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 12, minute: 0)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let notificationService = CapturingNotificationService()
        notificationService.pending = [
            TaskerPendingNotificationRequest(id: "task.reminder.\(UUID().uuidString)", fireDate: nil, kind: .taskReminder),
            TaskerPendingNotificationRequest(id: "task.snooze.task.reminder.\(UUID().uuidString).1772000000", fireDate: nil, kind: .snoozedTask),
            TaskerPendingNotificationRequest(id: "daily.morning.20260224", fireDate: nil, kind: .morningPlan),
            TaskerPendingNotificationRequest(id: "external.alert.keep", fireDate: nil, kind: nil)
        ]

        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        XCTAssertTrue(notificationService.canceledIDs.contains(where: { $0.hasPrefix("task.reminder.") }))
        XCTAssertTrue(notificationService.canceledIDs.contains(where: { $0.hasPrefix("task.snooze.") }))
        XCTAssertTrue(notificationService.canceledIDs.contains("daily.morning.20260224"))
        XCTAssertFalse(notificationService.canceledIDs.contains("external.alert.keep"))
    }

    func testReconcileDoesNotRescheduleUnchangedPendingRequests() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var task = TaskDefinition(title: "Write report")
        task.dueDate = nowDate.addingTimeInterval(3 * 3600)
        task.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "first")
        let firstScheduleCalls = notificationService.scheduleInvocationIDs.count

        orchestrator.reconcile(reason: "second_same_state")

        XCTAssertEqual(notificationService.scheduleInvocationIDs.count, firstScheduleCalls)
        XCTAssertTrue(notificationService.canceledIDs.isEmpty)
    }

    func testReconcileReschedulesWhenPendingRequestFingerprintChanges() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var task = TaskDefinition(title: "Write report")
        task.dueDate = nowDate.addingTimeInterval(3 * 3600)
        task.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        let reminderID = "task.reminder.\(task.id.uuidString)"

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "first")
        let firstScheduleCalls = notificationService.scheduleInvocationIDs.count

        notificationService.pending = notificationService.pending.map { pending in
            guard pending.id == reminderID else { return pending }
            return TaskerPendingNotificationRequest(
                id: pending.id,
                fireDate: pending.fireDate?.addingTimeInterval(60),
                kind: pending.kind,
                title: pending.title,
                body: "\(pending.body) stale",
                categoryIdentifier: pending.categoryIdentifier,
                routePayload: pending.routePayload,
                taskID: pending.taskID
            )
        }

        orchestrator.reconcile(reason: "changed_pending")

        XCTAssertEqual(notificationService.scheduleInvocationIDs.count, firstScheduleCalls + 1)
        XCTAssertTrue(notificationService.canceledIDs.contains(reminderID))
    }

    func testDueSoonUsesConfiguredLeadMinutes() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var dueSoonTask = TaskDefinition(title: "Prepare status deck", priority: .high)
        dueSoonTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 10, minute: 0)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [dueSoonTask])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: true,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false,
                dueSoonLeadMinutes: 60
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_due_soon_lead")

        guard let dueSoon = notificationService.scheduled.first(where: { $0.kind == .dueSoon }) else {
            return XCTFail("Expected due soon notification")
        }
        XCTAssertEqual(calendar.component(.hour, from: dueSoon.fireDate), 9)
        XCTAssertEqual(calendar.component(.minute, from: dueSoon.fireDate), 0)
        XCTAssertTrue(dueSoon.body.contains("due in 60m"))
        XCTAssertEqual(dueSoon.route, .taskDetail(taskID: dueSoonTask.id))
    }

    func testQuietHoursDefersTaskReminderToQuietWindowEnd() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 50)

        var reminderTask = TaskDefinition(title: "Late reminder")
        reminderTask.alertReminderTime = makeUTCDate(year: 2026, month: 2, day: 24, hour: 22, minute: 30)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [reminderTask])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: true,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false,
                quietHoursEnabled: true,
                quietHoursStartHour: 22,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 7,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: true
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_quiet_hours_task")

        let reminderID = "task.reminder.\(reminderTask.id.uuidString)"
        guard let reminder = notificationService.scheduled.first(where: { $0.id == reminderID }) else {
            return XCTFail("Expected reminder notification")
        }
        XCTAssertEqual(calendar.component(.day, from: reminder.fireDate), 25)
        XCTAssertEqual(calendar.component(.hour, from: reminder.fireDate), 7)
        XCTAssertEqual(calendar.component(.minute, from: reminder.fireDate), 0)
    }

    func testQuietHoursCanDeferDailySummaryWhenEnabledForDailyNotifications() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: true,
                nightlyRetrospectiveEnabled: false,
                morningHour: 8,
                morningMinute: 0,
                quietHoursEnabled: true,
                quietHoursStartHour: 7,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 9,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: false,
                quietHoursAppliesToDailySummaries: true
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_quiet_hours_daily")

        guard let morning = notificationService.scheduled.first(where: { $0.kind == .morningPlan && $0.id == "daily.morning.20260224" }) else {
            return XCTFail("Expected morning plan notification")
        }
        XCTAssertEqual(calendar.component(.hour, from: morning.fireDate), 9)
        XCTAssertEqual(calendar.component(.minute, from: morning.fireDate), 0)
    }

    private func makePreferencesStore() -> TaskerNotificationPreferencesStore {
        let suiteName = "tasker.notification.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TaskerNotificationPreferencesStore(defaults: defaults)
    }
}

final class TaskerNotificationRouteTests: XCTestCase {
    func testDailySummaryRoutePayloadRoundTrip() {
        let morning: TaskerNotificationRoute = .dailySummary(kind: .morning, dateStamp: "20260225")
        XCTAssertEqual(
            TaskerNotificationRoute.from(payload: morning.payload, fallbackTaskID: nil),
            morning
        )

        let nightlyNoDate: TaskerNotificationRoute = .dailySummary(kind: .nightly, dateStamp: nil)
        XCTAssertEqual(
            TaskerNotificationRoute.from(payload: nightlyNoDate.payload, fallbackTaskID: nil),
            nightlyNoDate
        )
    }
}

final class SceneDelegateNotificationRoutingTests: XCTestCase {
    override func tearDown() {
        clearRouteBus()
        TaskerNotificationRuntime.actionHandler = nil
        super.tearDown()
    }

    func testHandleNotificationLaunchFallsBackToPendingTaskDetailRouteWhenRuntimeHandlerUnavailable() {
        let taskID = UUID()
        let sceneDelegate = SceneDelegate()

        sceneDelegate.handleNotificationLaunch(
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testHandleNotificationLaunchUsesRuntimeActionHandlerWhenAvailable() {
        let notificationService = CapturingNotificationService()
        TaskerNotificationRuntime.actionHandler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        let sceneDelegate = SceneDelegate()
        sceneDelegate.handleNotificationLaunch(
            request: makeUNNotificationRequest(
                id: "daily.nightly.20260224",
                kind: .nightlyRetrospective,
                route: .dailySummary(kind: .nightly, dateStamp: "20260224"),
                category: TaskerNotificationCategoryID.dailyNightly.rawValue
            ),
            actionIdentifier: TaskerNotificationActionID.openDone.rawValue
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .homeDone)
    }

    private func clearRouteBus() {
        while TaskerNotificationRouteBus.shared.consumePendingRoute() != nil {}
    }
}

final class DailySummaryModalUseCaseTests: XCTestCase {
    func testBuildSummaryMorningIncludesFocusRiskAndAgenda() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 0)
        let dayStart = calendar.startOfDay(for: nowDate)

        var overdueBlocked = TaskDefinition(title: "Resolve production incident", priority: .high)
        overdueBlocked.dueDate = dayStart.addingTimeInterval(-3600)
        overdueBlocked.estimatedDuration = 90 * 60
        overdueBlocked.dependencies = [
            TaskDependencyLinkDefinition(
                taskID: overdueBlocked.id,
                dependsOnTaskID: UUID(),
                kind: .blocks
            )
        ]

        var dueMorning = TaskDefinition(title: "Draft proposal", priority: .max, type: .morning)
        dueMorning.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)

        var dueEvening = TaskDefinition(title: "Send recap", priority: .low, type: .evening, isEveningTask: true)
        dueEvening.dueDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: nowDate)

        var tomorrow = TaskDefinition(title: "Plan next sprint", priority: .high)
        tomorrow.dueDate = calendar.date(byAdding: .day, value: 1, to: nowDate)

        var completed = TaskDefinition(title: "Closed meeting notes", priority: .low, isComplete: true)
        completed.dateCompleted = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: nowDate)
        completed.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)

        let allTasks = [overdueBlocked, dueMorning, dueEvening, tomorrow, completed]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )

        let summary = useCase.buildSummary(
            kind: .morning,
            date: nowDate,
            allTasks: allTasks,
            analytics: nil,
            streakCount: nil
        )

        guard case .morning(let morning) = summary else {
            return XCTFail("Expected morning summary")
        }

        XCTAssertEqual(morning.openTodayCount, 3)
        XCTAssertEqual(morning.highPriorityCount, 2)
        XCTAssertEqual(morning.overdueCount, 1)
        XCTAssertEqual(morning.blockedCount, 1)
        XCTAssertEqual(morning.longTaskCount, 1)
        XCTAssertEqual(morning.morningPlannedCount, 1)
        XCTAssertEqual(morning.eveningPlannedCount, 1)
        XCTAssertEqual(morning.focusTasks.first?.taskID, dueMorning.id)
    }

    func testBuildSummaryNightlyIncludesWinsCarryOverAndTomorrowPreview() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 0)
        let dayStart = calendar.startOfDay(for: nowDate)

        var openDueMorning = TaskDefinition(title: "Open today A", priority: .high, type: .morning)
        openDueMorning.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)

        var openDueEvening = TaskDefinition(title: "Open today B", priority: .low, type: .evening, isEveningTask: true)
        openDueEvening.dueDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: nowDate)

        var overdue = TaskDefinition(title: "Overdue cleanup", priority: .high)
        overdue.dueDate = dayStart.addingTimeInterval(-7200)

        var completedHigh = TaskDefinition(title: "Ship release", priority: .max, type: .morning, isComplete: true)
        completedHigh.dateCompleted = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: nowDate)
        completedHigh.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)

        var completedLow = TaskDefinition(title: "Tidy inbox", priority: .low, type: .evening, isComplete: true, isEveningTask: true)
        completedLow.dateCompleted = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: nowDate)
        completedLow.dueDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: nowDate)

        var tomorrow = TaskDefinition(title: "Tomorrow task", priority: .high)
        tomorrow.dueDate = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: nowDate) ?? nowDate)

        let allTasks = [openDueMorning, openDueEvening, overdue, completedHigh, completedLow, tomorrow]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )
        let analytics = DailyAnalytics(
            date: nowDate,
            totalTasks: 4,
            completedTasks: 2,
            completionRate: 0.5,
            totalScore: completedHigh.priority.scorePoints + completedLow.priority.scorePoints,
            morningTasksCompleted: 1,
            eveningTasksCompleted: 1,
            priorityBreakdown: [:]
        )

        let summary = useCase.buildSummary(
            kind: .nightly,
            date: nowDate,
            allTasks: allTasks,
            analytics: analytics,
            streakCount: 6
        )

        guard case .nightly(let nightly) = summary else {
            return XCTFail("Expected nightly summary")
        }

        XCTAssertEqual(nightly.completedCount, 2)
        XCTAssertEqual(nightly.totalCount, 4)
        XCTAssertEqual(
            nightly.xpEarned,
            completedHigh.priority.scorePoints + completedLow.priority.scorePoints
        )
        XCTAssertEqual(nightly.completionRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(nightly.streakCount, 6)
        XCTAssertEqual(nightly.biggestWins.first?.taskID, completedHigh.id)
        XCTAssertEqual(nightly.carryOverDueTodayCount, 2)
        XCTAssertEqual(nightly.carryOverOverdueCount, 1)
        XCTAssertEqual(nightly.tomorrowPreview.map(\.taskID), [tomorrow.id])
        XCTAssertEqual(nightly.morningCompletedCount, 1)
        XCTAssertEqual(nightly.eveningCompletedCount, 1)
    }

    func testBuildSummaryMorningUsesDateTasksSplitWhenProvided() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 0)

        var morningTaskA = TaskDefinition(title: "Morning A", priority: .high, type: .morning)
        morningTaskA.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)
        var morningTaskB = TaskDefinition(title: "Morning B", priority: .low, type: .morning)
        morningTaskB.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)
        var eveningTask = TaskDefinition(title: "Evening A", priority: .low, type: .evening, isEveningTask: true)
        eveningTask.dueDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: nowDate)

        let allTasks = [morningTaskA, morningTaskB, eveningTask]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )

        let dateTasks = DateTasksResult(
            date: nowDate,
            morningTasks: [morningTaskA, morningTaskB],
            eveningTasks: [eveningTask],
            overdueTasks: [],
            completedTasks: [],
            totalCount: 3
        )

        let summary = useCase.buildSummary(
            kind: .morning,
            date: nowDate,
            allTasks: allTasks,
            analytics: nil,
            streakCount: nil,
            dateTasks: dateTasks
        )

        guard case .morning(let morning) = summary else {
            return XCTFail("Expected morning summary")
        }

        XCTAssertEqual(morning.morningPlannedCount, 2)
        XCTAssertEqual(morning.eveningPlannedCount, 1)
    }

    func testBuildSummaryNightlyPrefersAnalyticsTotalCountForHeroDenominator() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 0)

        var completed = TaskDefinition(title: "Completed", priority: .high, type: .morning, isComplete: true)
        completed.dateCompleted = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)
        completed.dueDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: nowDate)

        let allTasks = [completed]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )
        let analytics = DailyAnalytics(
            date: nowDate,
            totalTasks: 5,
            completedTasks: 1,
            completionRate: 0.2,
            totalScore: completed.priority.scorePoints,
            morningTasksCompleted: 1,
            eveningTasksCompleted: 0,
            priorityBreakdown: [:]
        )

        let summary = useCase.buildSummary(
            kind: .nightly,
            date: nowDate,
            allTasks: allTasks,
            analytics: analytics,
            streakCount: 2
        )

        guard case .nightly(let nightly) = summary else {
            return XCTFail("Expected nightly summary")
        }

        XCTAssertEqual(nightly.completedCount, 1)
        XCTAssertEqual(nightly.totalCount, 5)
    }
}

final class TaskerNotificationActionHandlerTests: XCTestCase {
    func testCompleteActionMarksTaskDoneAndCancelsTaskBoundNotifications() throws {
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            title: "Complete from notification",
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: repository,
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )

        let notificationService = CapturingNotificationService()
        notificationService.pending = [
            TaskerPendingNotificationRequest(id: "task.reminder.\(taskID.uuidString)", fireDate: nil, kind: .taskReminder),
            TaskerPendingNotificationRequest(id: "task.overdue.\(taskID.uuidString).20260224.am", fireDate: nil, kind: .overdue),
            TaskerPendingNotificationRequest(id: "task.snooze.task.reminder.\(taskID.uuidString).1772000000", fireDate: nil, kind: .snoozedTask, taskID: taskID)
        ]

        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { coordinator },
            now: { Date(timeIntervalSince1970: 1_772_000_000) }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.complete.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        let updated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(updated?.isComplete, true)
        XCTAssertTrue(notificationService.canceledIDs.contains("task.reminder.\(taskID.uuidString)"))
        XCTAssertTrue(notificationService.canceledIDs.contains("task.overdue.\(taskID.uuidString).20260224.am"))
        XCTAssertTrue(notificationService.canceledIDs.contains("task.snooze.task.reminder.\(taskID.uuidString).1772000000"))
    }

    func testSnoozeActionsUseCategoryDurations() {
        let fixedNow = Date(timeIntervalSince1970: 1_772_000_000)
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil },
            now: { fixedNow }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.snooze30m.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260224",
                kind: .morningPlan,
                route: .homeToday(taskID: nil),
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let snoozed = notificationService.scheduled.first
        XCTAssertEqual(snoozed?.kind, .snoozedMorning)
        guard let fireDate = snoozed?.fireDate else {
            XCTFail("Expected snoozed fire date")
            return
        }
        XCTAssertEqual(fireDate.timeIntervalSince1970, fixedNow.addingTimeInterval(30 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testSnoozeRespectsQuietHoursWhenEnabledForTaskAlerts() {
        let fixedNow = makeUTCDate(year: 2026, month: 2, day: 24, hour: 23, minute: 0)
        let notificationService = CapturingNotificationService()
        let suiteName = "tasker.notification.action.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferencesStore = TaskerNotificationPreferencesStore(defaults: defaults)
        preferencesStore.save(
            TaskerNotificationPreferences(
                quietHoursEnabled: true,
                quietHoursStartHour: 22,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 7,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: true,
                quietHoursAppliesToDailySummaries: false
            )
        )

        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil },
            preferencesStore: preferencesStore,
            calendar: Calendar(identifier: .gregorian, timeZoneID: "UTC"),
            now: { fixedNow }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.snooze15m.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(UUID().uuidString)",
                kind: .taskReminder,
                route: .homeToday(taskID: nil),
                category: TaskerNotificationCategoryID.taskActionable.rawValue
            )
        )

        guard let snoozed = notificationService.scheduled.first else {
            return XCTFail("Expected snoozed request")
        }
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.day, from: snoozed.fireDate), 25)
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.hour, from: snoozed.fireDate), 7)
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.minute, from: snoozed.fireDate), 0)
    }

    func testOpenDoneActionRoutesToDoneQuickView() {
        clearRouteBus()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.openDone.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.nightly.20260224",
                kind: .nightlyRetrospective,
                route: .homeDone,
                category: TaskerNotificationCategoryID.dailyNightly.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        if case .some(.homeDone) = routed {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected route to be homeDone")
        }
    }

    func testDefaultTapRoutesToDailySummaryWhenPayloadContainsDailySummaryRoute() {
        clearRouteBus()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        let expectedRoute: TaskerNotificationRoute = .dailySummary(kind: .morning, dateStamp: "20260225")
        handler.handleAction(
            identifier: UNNotificationDefaultActionIdentifier,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260225",
                kind: .morningPlan,
                route: expectedRoute,
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        XCTAssertEqual(routed, expectedRoute)
    }

    func testDefaultTapRoutesTaskAlertToTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: UNNotificationDefaultActionIdentifier,
            request: makeUNNotificationRequest(
                id: "task.overdue.\(taskID.uuidString).20260224.am",
                kind: .overdue,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testOpenActionRoutesTaskAlertToTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.open.rawValue,
            request: makeUNNotificationRequest(
                id: "task.dueSoon.\(taskID.uuidString).20260224",
                kind: .dueSoon,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testCompleteActionInvokesCompletionExactlyOnce() throws {
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            title: "Complete with callback",
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: repository,
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { coordinator },
            now: { Date(timeIntervalSince1970: 1_772_000_000) }
        )

        let completionExpectation = expectation(description: "action completion")
        var completionCount = 0

        handler.handleAction(
            identifier: TaskerNotificationActionID.complete.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            ),
            completion: {
                completionCount += 1
                completionExpectation.fulfill()
            }
        )

        wait(for: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(completionCount, 1)
    }

    func testOpenTodayActionRoutesToHomeTodayNotTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.openToday.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260224",
                kind: .morningPlan,
                route: .homeToday(taskID: taskID),
                taskID: taskID,
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        if case .some(.homeToday(let routedTaskID)) = routed {
            XCTAssertEqual(routedTaskID, taskID)
        } else {
            XCTFail("Expected route to be homeToday(taskID:)")
        }
    }

    private func clearRouteBus() {
        while TaskerNotificationRouteBus.shared.consumePendingRoute() != nil {}
    }
}

private final class CapturingNotificationService: NotificationServiceProtocol {
    var scheduled: [TaskerLocalNotificationRequest] = []
    var canceledIDs: [String] = []
    var pending: [TaskerPendingNotificationRequest] = []
    var scheduleInvocationIDs: [String] = []
    var authorizationStatus: TaskerNotificationAuthorizationStatus = .authorized

    func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {}
    func cancelTaskReminder(taskId: UUID) {}
    func cancelAllReminders() {}
    func send(_ notification: CollaborationNotification) {}
    func requestPermission(completion: @escaping (Bool) -> Void) { completion(true) }
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) { completion(true) }
    func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void) { completion(authorizationStatus) }
    func registerCategories(_ categories: Set<UNNotificationCategory>) {}
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {}

    func schedule(request: TaskerLocalNotificationRequest) {
        scheduleInvocationIDs.append(request.id)
        scheduled.removeAll(where: { $0.id == request.id })
        scheduled.append(request)
        pending.removeAll(where: { $0.id == request.id })
        pending.append(
            TaskerPendingNotificationRequest(
                id: request.id,
                fireDate: request.fireDate,
                kind: request.kind,
                title: request.title,
                body: request.body,
                categoryIdentifier: request.categoryIdentifier,
                routePayload: request.route.payload,
                taskID: request.taskID
            )
        )
    }

    func cancel(ids: [String]) {
        canceledIDs.append(contentsOf: ids)
        pending.removeAll(where: { ids.contains($0.id) })
        scheduled.removeAll(where: { ids.contains($0.id) })
    }

    func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void) {
        completion(pending)
    }
}

private func makeUNNotificationRequest(
    id: String,
    kind: TaskerLocalNotificationKind,
    route: TaskerNotificationRoute,
    taskID: UUID? = nil,
    category: String = TaskerNotificationCategoryID.taskActionable.rawValue
) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "Title"
    content.body = "Body"
    content.categoryIdentifier = category
    var userInfo: [AnyHashable: Any] = [
        TaskerLocalNotificationRequest.UserInfoKey.kind: kind.rawValue,
        TaskerLocalNotificationRequest.UserInfoKey.route: route.payload
    ]
    if let taskID {
        userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] = taskID.uuidString
    }
    content.userInfo = userInfo
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
}

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date ?? Date(timeIntervalSince1970: 0)
}

private extension Calendar {
    init(identifier: Calendar.Identifier, timeZoneID: String) {
        self.init(identifier: identifier)
        self.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
    }
}

final class InsightsViewModelPerformanceLogicTests: XCTestCase {
    func testOnAppearLoadsSelectedTabOnly() {
        let repository = InsightsRepositorySpy()
        repository.dailyAggregatesByDateKey[XPCalculationEngine.periodKey()] = DailyXPAggregateDefinition(
            dateKey: XPCalculationEngine.periodKey(),
            totalXP: 42,
            eventCount: 3
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "a", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, 1)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, 1)
        XCTAssertEqual(repository.fetchDailyAggregatesCount, 0)
        XCTAssertEqual(repository.fetchAchievementUnlocksCount, 0)
    }

    func testCleanTabSwitchDoesNotRefetchLoadedTab() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 12, eventCount: 1)

        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let key = formatter.string(from: day)
            repository.weekAggregates.append(
                DailyXPAggregateDefinition(dateKey: key, totalXP: (dayOffset + 1) * 5, eventCount: dayOffset + 1)
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        viewModel.selectTab(.week)
        waitUntil {
            viewModel.refreshState(for: .week).isLoaded
        }

        let dailyAggregateFetchesBeforeReselect = repository.fetchDailyAggregateCount
        let xpRangeFetchesBeforeReselect = repository.fetchXPEventsRangeCount

        viewModel.selectTab(.today)
        waitUntil {
            viewModel.selectedTab == .today
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, dailyAggregateFetchesBeforeReselect)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, xpRangeFetchesBeforeReselect)
    }

    func testTodayRefreshAllowsTotalTasksTodayToDecreaseWhenEventsShrink() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(
            dateKey: todayKey,
            totalXP: 30,
            eventCount: 3
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "a", category: .complete),
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "b", category: .complete),
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "c", category: .complete)
        ]

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
                && viewModel.todayState.totalTasksToday == 3
        }

        repository.todayEvents = [
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "d", category: .complete)
        ]

        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 2.0) {
            viewModel.refreshState(for: .today).inFlight == false
                && viewModel.todayState.tasksCompletedToday == 1
                && viewModel.todayState.totalTasksToday == 1
        }

        XCTAssertEqual(viewModel.todayState.tasksCompletedToday, 1)
        XCTAssertEqual(viewModel.todayState.totalTasksToday, 1)
    }

    func testMutationBurstCoalescesIntoSingleRefreshPass() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 8, eventCount: 1)
        repository.todayEvents = [
            XPEventDefinition(delta: 8, reason: "task_completion", idempotencyKey: "burst", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        let beforeDailyAggregateFetches = repository.fetchDailyAggregateCount
        let beforeXPRangeFetches = repository.fetchXPEventsRangeCount

        viewModel.noteMutation(.taskCompleted)
        viewModel.noteMutation(.taskCompleted)
        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 2.0) {
            repository.fetchXPEventsRangeCount >= beforeXPRangeFetches + 1
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount - beforeDailyAggregateFetches, 1)
        XCTAssertEqual(repository.fetchXPEventsRangeCount - beforeXPRangeFetches, 1)
    }

    func testMutationDuringInFlightTriggersSingleReplay() {
        let repository = InsightsRepositorySpy()
        repository.rangeFetchDelay = 0.35
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 14, eventCount: 2)
        repository.todayEvents = [
            XPEventDefinition(delta: 14, reason: "task_completion", idempotencyKey: "inflight", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil(timeout: 1.0) {
            viewModel.refreshState(for: .today).inFlight
        }

        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 3.0) {
            viewModel.refreshState(for: .today).isLoaded
                && viewModel.refreshState(for: .today).inFlight == false
                && repository.fetchXPEventsRangeCount >= 2
        }

        XCTAssertEqual(repository.fetchXPEventsRangeCount, 2)
        XCTAssertEqual(repository.fetchDailyAggregateCount, 2)
    }

    func testWeeklyBarIdentityUsesUniqueDateKey() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 20, eventCount: 2)

        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: (offset + 1) * 3,
                eventCount: offset + 1
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.selectTab(.week)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
        }

        let ids = viewModel.weekState.weeklyBars.map(\.id)
        XCTAssertEqual(ids.count, 7)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testLedgerMutationAppliesProjectionWithoutRepositoryRefetch() {
        let repository = InsightsRepositorySpy()
        let center = NotificationCenter()
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        let todayKey = XPCalculationEngine.periodKey()

        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(
            dateKey: todayKey,
            totalXP: 20,
            eventCount: 2
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "pre", category: .complete)
        ]
        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: offset == 0 ? 20 : 0,
                eventCount: offset == 0 ? 2 : 0
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository, notificationCenter: center)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
        }

        viewModel.selectTab(.week)
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
        }

        let dailyAggregateFetches = repository.fetchDailyAggregateCount
        let xpRangeFetches = repository.fetchXPEventsRangeCount
        let weeklyAggregateFetches = repository.fetchDailyAggregatesCount

        let mutation = GamificationLedgerMutation(
            source: XPSource.manual.rawValue,
            category: .complete,
            awardedXP: 15,
            dailyXPSoFar: 35,
            totalXP: 220,
            level: 4,
            previousLevel: 3,
            streakDays: 5,
            didChange: true,
            dateKey: todayKey,
            occurredAt: Date()
        )
        center.post(
            name: .gamificationLedgerDidMutate,
            object: nil,
            userInfo: mutation.userInfo
        )

        waitUntil(timeout: 1.5) {
            viewModel.todayState.dailyXP == 35
                && viewModel.weekState.weeklyBars.contains(where: { $0.dateKey == todayKey && $0.xp == 35 })
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, dailyAggregateFetches)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, xpRangeFetches)
        XCTAssertEqual(repository.fetchDailyAggregatesCount, weeklyAggregateFetches)
    }

    func testWeekScaleModePersistsAcrossViewModelInstances() {
        let suiteName = "insights.week.scale.mode.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let repository = InsightsRepositorySpy()
        let engine = GamificationEngine(repository: repository)
        let first = InsightsViewModel(
            engine: engine,
            repository: repository,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults
        )
        XCTAssertEqual(first.weekScaleMode, .personalMax)

        first.setWeekScaleMode(.goal)

        let second = InsightsViewModel(
            engine: engine,
            repository: repository,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults
        )
        XCTAssertEqual(second.weekScaleMode, .goal)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLedgerMutationRefreshesSystemsAndLoadsUnlockedAchievements() {
        let repository = InsightsRepositorySpy()
        let center = NotificationCenter()
        let viewModel = makeInsightsViewModel(repository: repository, notificationCenter: center)

        viewModel.selectTab(.systems)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .systems).isLoaded
        }

        let unlockedKey = "streak_7"
        let baselineUnlockFetches = repository.fetchAchievementUnlocksCount
        repository.achievements = [
            AchievementUnlockDefinition(
                id: UUID(),
                achievementKey: unlockedKey,
                unlockedAt: Date(),
                sourceEventID: nil
            )
        ]
        let mutation = GamificationLedgerMutation(
            source: XPSource.manual.rawValue,
            category: .complete,
            awardedXP: 12,
            dailyXPSoFar: 12,
            totalXP: 150,
            level: 2,
            previousLevel: 1,
            streakDays: 7,
            didChange: true,
            dateKey: XPCalculationEngine.periodKey(),
            occurredAt: Date(),
            unlockedAchievementKeys: [unlockedKey],
            originatingEventID: UUID()
        )
        center.post(
            name: .gamificationLedgerDidMutate,
            object: nil,
            userInfo: mutation.userInfo
        )

        waitUntil(timeout: 1.5) {
            repository.fetchAchievementUnlocksCount > baselineUnlockFetches
                && viewModel.systemsState.unlockedAchievements.contains(unlockedKey)
        }

        XCTAssertTrue(viewModel.systemsState.unlockedAchievements.contains(unlockedKey))
    }

    func testTodayProjectionBuildsDuePressureFocusAndMixModules() {
        let repository = InsightsRepositorySpy()
        let calendar = XPCalculationEngine.mondayCalendar()
        let today = calendar.startOfDay(for: Date())
        let overdueDate = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let dueLaterToday = calendar.date(byAdding: .hour, value: 10, to: today) ?? today
        let completedAt = calendar.date(byAdding: .hour, value: 9, to: today) ?? today

        repository.dailyAggregatesByDateKey[XPCalculationEngine.periodKey(for: today)] = DailyXPAggregateDefinition(
            dateKey: XPCalculationEngine.periodKey(for: today),
            totalXP: 48,
            eventCount: 4
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 18, reason: "task_completion", idempotencyKey: "today-1", createdAt: completedAt, category: .complete),
            XPEventDefinition(delta: 12, reason: "focus", idempotencyKey: "today-2", createdAt: completedAt, category: .focus),
            XPEventDefinition(delta: 8, reason: "recover", idempotencyKey: "today-3", createdAt: completedAt, category: .recoverReschedule),
            XPEventDefinition(delta: 10, reason: "reflection", idempotencyKey: "today-4", createdAt: completedAt, category: .reflection)
        ]
        repository.focusSessions = [
            FocusSessionDefinition(startedAt: completedAt, endedAt: calendar.date(byAdding: .minute, value: 30, to: completedAt), durationSeconds: 1_800, targetDurationSeconds: 1_800, wasCompleted: true, xpAwarded: 12),
            FocusSessionDefinition(
                startedAt: calendar.date(byAdding: .hour, value: 2, to: completedAt) ?? completedAt,
                endedAt: calendar.date(byAdding: .hour, value: 2, to: completedAt)?.addingTimeInterval(1_200),
                durationSeconds: 1_200,
                targetDurationSeconds: 1_500,
                wasCompleted: false,
                xpAwarded: 0
            )
        ]

        let tasks = [
            TaskDefinition(
                title: "High leverage task",
                priority: .high,
                type: .morning,
                energy: .high,
                context: .computer,
                dueDate: dueLaterToday,
                isComplete: true,
                dateCompleted: completedAt
            ),
            TaskDefinition(
                title: "Blocked overdue task",
                priority: .max,
                type: .morning,
                energy: .medium,
                context: .office,
                dueDate: overdueDate,
                dependencies: [TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks, createdAt: Date())],
                estimatedDuration: 7_200
            )
        ]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: tasks)
        let viewModel = makeInsightsViewModel(repository: repository, taskReadModelRepository: readModel)

        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
                && !viewModel.todayState.completionMixSections.isEmpty
        }

        XCTAssertEqual(viewModel.todayState.momentumMetrics.count, 4)
        XCTAssertEqual(viewModel.todayState.duePressureMetrics.first(where: { $0.id == "overdue" })?.value, "1")
        XCTAssertEqual(viewModel.todayState.duePressureMetrics.first(where: { $0.id == "blocked" })?.value, "1")
        XCTAssertEqual(viewModel.todayState.focusMetrics.first(where: { $0.id == "focus_minutes" })?.value, "50")
        XCTAssertTrue(viewModel.todayState.recoveryMetrics.contains(where: { $0.id == "reflection" && $0.value == "Claimed" }))
    }

    func testWeekProjectionBuildsLeaderboardAndMix() {
        let repository = InsightsRepositorySpy()
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)

        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: offset < 4 ? (offset + 1) * 15 : 0,
                eventCount: offset < 4 ? offset + 1 : 0
            )
        }

        let projectA = UUID()
        let projectB = UUID()
        let completionDayOne = calendar.date(byAdding: .day, value: 1, to: weekStart) ?? weekStart
        let completionDayTwo = calendar.date(byAdding: .day, value: 2, to: weekStart) ?? weekStart
        repository.allEvents = [
            XPEventDefinition(delta: 15, reason: "task_completion", idempotencyKey: "week-1", createdAt: completionDayOne, category: .complete),
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "week-2", createdAt: completionDayTwo, category: .complete)
        ]

        let tasks = [
            TaskDefinition(
                projectID: projectA,
                projectName: "Apollo",
                title: "Apollo close",
                priority: .high,
                type: .morning,
                dueDate: completionDayOne,
                isComplete: true,
                dateCompleted: completionDayOne
            ),
            TaskDefinition(
                projectID: projectA,
                projectName: "Apollo",
                title: "Apollo follow-up",
                priority: .max,
                type: .evening,
                dueDate: completionDayTwo,
                isComplete: true,
                dateCompleted: completionDayTwo
            ),
            TaskDefinition(
                projectID: projectB,
                projectName: "Beacon",
                title: "Beacon prep",
                priority: .low,
                type: .upcoming,
                dueDate: completionDayTwo,
                isComplete: true,
                dateCompleted: completionDayTwo
            )
        ]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: tasks)
        let viewModel = makeInsightsViewModel(repository: repository, taskReadModelRepository: readModel)

        viewModel.selectTab(.week)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
                && !viewModel.weekState.projectLeaderboard.isEmpty
        }

        XCTAssertEqual(viewModel.weekState.projectLeaderboard.first?.title, "Apollo")
        XCTAssertFalse(viewModel.weekState.priorityMix.isEmpty)
        XCTAssertFalse(viewModel.weekState.taskTypeMix.isEmpty)
        XCTAssertEqual(viewModel.weekState.weeklyBars.count, 7)
    }

    func testSystemsProjectionBuildsReminderResponseAndFocusHealth() {
        let repository = InsightsRepositorySpy()
        let reminderRepository = InsightsReminderRepositorySpy()
        let now = Date()

        repository.allEvents = [
            XPEventDefinition(delta: 8, reason: "recover", idempotencyKey: "sys-1", createdAt: now, category: .recoverReschedule),
            XPEventDefinition(delta: 6, reason: "reflection", idempotencyKey: "sys-2", createdAt: now, category: .reflection),
            XPEventDefinition(delta: 4, reason: "decompose", idempotencyKey: "sys-3", createdAt: now, category: .decompose)
        ]
        repository.focusSessions = [
            FocusSessionDefinition(startedAt: now.addingTimeInterval(-86_400), endedAt: now.addingTimeInterval(-84_600), durationSeconds: 1_800, targetDurationSeconds: 1_800, wasCompleted: true, xpAwarded: 10),
            FocusSessionDefinition(startedAt: now.addingTimeInterval(-43_200), endedAt: now.addingTimeInterval(-42_000), durationSeconds: 1_200, targetDurationSeconds: 1_500, wasCompleted: false, xpAwarded: 0)
        ]

        let reminder = ReminderDefinition(
            id: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            occurrenceID: nil,
            policy: "default",
            channelMask: 1,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
        reminderRepository.reminders = [reminder]
        reminderRepository.deliveriesByReminderID[reminder.id] = [
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "acked", scheduledAt: now, sentAt: now, ackAt: now, snoozedUntil: nil, errorCode: nil, createdAt: now),
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "snoozed", scheduledAt: now, sentAt: now, ackAt: nil, snoozedUntil: now.addingTimeInterval(600), errorCode: nil, createdAt: now),
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "pending", scheduledAt: now, sentAt: nil, ackAt: nil, snoozedUntil: nil, errorCode: nil, createdAt: now)
        ]

        let viewModel = makeInsightsViewModel(
            repository: repository,
            reminderRepository: reminderRepository
        )

        viewModel.selectTab(.systems)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .systems).isLoaded
                && viewModel.systemsState.reminderResponse.totalDeliveries == 3
        }

        XCTAssertEqual(viewModel.systemsState.reminderResponse.acknowledgedDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.reminderResponse.snoozedDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.reminderResponse.pendingDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.focusHealthMetrics.first(where: { $0.id == "focus_sessions" })?.value, "2")
        XCTAssertTrue(viewModel.systemsState.recoveryHealthMetrics.contains(where: { $0.id == "reflections" && $0.value == "1" }))
    }

    private func makeInsightsViewModel(
        repository: InsightsRepositorySpy,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        reminderRepository: ReminderRepositoryProtocol? = nil,
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> InsightsViewModel {
        let engine = GamificationEngine(repository: repository)
        return InsightsViewModel(
            engine: engine,
            repository: repository,
            taskReadModelRepository: taskReadModelRepository,
            reminderRepository: reminderRepository,
            notificationCenter: notificationCenter
        )
    }

    private func makeDateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            let nextTick = Date().addingTimeInterval(0.01)
            if Thread.isMainThread {
                RunLoop.main.run(mode: .default, before: nextTick)
            } else {
                DispatchQueue.main.sync {}
                RunLoop.current.run(mode: .default, before: nextTick)
            }
        }
        XCTFail("Condition not met before timeout", file: file, line: line)
    }
}

final class CelebrationRouterBehaviorTests: XCTestCase {
    func testXPBurstCooldownSuppressesRapidRepeatBursts() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-1", secondsFromBase: 0))
        let second = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-2", secondsFromBase: 1))

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testLevelUpIsNotBlockedByXPBurstCooldown() {
        let router = DefaultCelebrationRouter()
        _ = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-1", secondsFromBase: 0))

        let levelUp = router.route(event: makeEvent(kind: .levelUp, signature: "level-2", secondsFromBase: 0.1))
        XCTAssertNotNil(levelUp)
    }

    func testDuplicateSignatureIsDedupedAcrossKinds() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .milestone, signature: "same-signature", secondsFromBase: 0))
        let duplicate = router.route(event: makeEvent(kind: .milestone, signature: "same-signature", secondsFromBase: 12))

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
    }

    func testAchievementUnlockUsesOwnCooldownWindow() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-1", secondsFromBase: 0))
        let suppressed = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-2", secondsFromBase: 0.4))
        let allowed = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-3", secondsFromBase: 1.2))

        XCTAssertNotNil(first)
        XCTAssertNil(suppressed)
        XCTAssertNotNil(allowed)
    }

    private func makeEvent(
        kind: CelebrationKind,
        signature: String,
        secondsFromBase: TimeInterval
    ) -> CelebrationEvent {
        let milestone = kind == .milestone ? XPCalculationEngine.milestones.first : nil
        return CelebrationEvent(
            kind: kind,
            awardedXP: 8,
            level: 3,
            milestone: milestone,
            achievementKey: kind == .achievementUnlock ? "streak_7" : nil,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000 + secondsFromBase),
            signature: signature
        )
    }
}

final class XPCalculationEngineExactPreviewTests: XCTestCase {
    func testCompletionXPIfCompletedNowIncludesOnTimeBonus() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let dueDate = completedAt
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.none.rawValue,
            estimatedDuration: nil,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 17)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowOmitsBonusForOverdueTask() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let dueDate = Calendar.current.date(byAdding: .day, value: -1, to: completedAt)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.none.rawValue,
            estimatedDuration: nil,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 11)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowAppliesEffortWeight() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.high.rawValue,
            estimatedDuration: 90 * 60,
            dueDate: nil,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 17)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowClampsToRemainingCapHeadroom() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: nil,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 245,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 5)
        XCTAssertTrue(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowUsesLegacyFixedRewardWhenV2Disabled() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: 120 * 60,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 10_000,
            isGamificationV2Enabled: false
        )

        XCTAssertEqual(preview.awardedXP, 10)
        XCTAssertFalse(preview.isCapped)
    }
}

final class XPExactPreviewParityTests: XCTestCase {
    func testPreviewMatchesGamificationEngineAwardForStandardCompletion() throws {
        let repository = InMemoryGamificationEngineRepository()
        let engine = GamificationEngine(repository: repository)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let dueDate = completedAt

        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.high.rawValue,
            estimatedDuration: 60 * 60,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        var recordedResult: Result<XPEventResult, Error>?
        let completionExpectation = expectation(description: "record completion")
        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                dueDate: dueDate,
                completedAt: completedAt,
                priority: max(0, Int(TaskPriority.high.rawValue) - 1),
                estimatedDuration: 60 * 60
            )
        ) { result in
            recordedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let awarded = try XCTUnwrap(recordedResult).get().awardedXP
        XCTAssertEqual(preview.awardedXP, awarded)
    }

    func testPreviewMatchesGamificationEngineAwardWhenNearDailyCap() throws {
        let repository = InMemoryGamificationEngineRepository()
        let engine = GamificationEngine(repository: repository)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let dateKey = XPCalculationEngine.periodKey(for: completedAt)
        repository.seed(
            dailyAggregates: [
                dateKey: DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 245,
                    eventCount: 10,
                    updatedAt: completedAt
                )
            ]
        )

        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: nil,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 245,
            isGamificationV2Enabled: true
        )

        var recordedResult: Result<XPEventResult, Error>?
        let completionExpectation = expectation(description: "record near-cap completion")
        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                dueDate: completedAt,
                completedAt: completedAt,
                priority: max(0, Int(TaskPriority.max.rawValue) - 1),
                estimatedDuration: nil
            )
        ) { result in
            recordedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(recordedResult).get()
        XCTAssertEqual(preview.awardedXP, result.awardedXP)
        XCTAssertTrue(preview.isCapped)
        XCTAssertEqual(result.dailyXPSoFar, 245 + preview.awardedXP)
    }
}

final class XPRewardPreviewCopyRegressionTests: XCTestCase {
    func testCompletionRewardSurfacesUseExactPreviewAPI() throws {
        let rewardSurfaceFiles = [
            "To Do List/View/TaskRowView.swift",
            "To Do List/View/TaskDetailSheetView.swift",
            "To Do List/View/AddTaskXPPreview.swift"
        ]

        for relativePath in rewardSurfaceFiles {
            let source = try loadWorkspaceFile(relativePath)
            XCTAssertTrue(
                source.contains("completionXPIfCompletedNow("),
                "\(relativePath) should use exact completion preview API."
            )
            XCTAssertFalse(
                source.contains("completionEstimate("),
                "\(relativePath) should not use range-based completion estimate API."
            )
        }
    }

    func testCompletionRewardSurfacesDoNotUseApproximateCopy() throws {
        let rewardCopyFiles = [
            "To Do List/View/TaskRowView.swift",
            "To Do List/View/TaskDetailComponents.swift",
            "To Do List/View/AddTaskXPPreview.swift"
        ]

        for relativePath in rewardCopyFiles {
            let source = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(source.contains("Est. +"), "\(relativePath) should not show estimated XP labels.")
            XCTAssertFalse(source.contains("~+"), "\(relativePath) should not show approximate compact XP labels.")
            XCTAssertFalse(source.contains("Estimated reward"), "\(relativePath) should use reward wording.")
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

private final class InsightsRepositorySpy: GamificationRepositoryProtocol {
    private let lock = NSLock()

    var profile = GamificationSnapshot(
        xpTotal: 120,
        level: 2,
        currentStreak: 3,
        bestStreak: 5,
        nextLevelXP: 150,
        returnStreak: 0,
        bestReturnStreak: 0
    )
    var dailyAggregatesByDateKey: [String: DailyXPAggregateDefinition] = [:]
    var weekAggregates: [DailyXPAggregateDefinition] = []
    var todayEvents: [XPEventDefinition] = []
    var allEvents: [XPEventDefinition] = []
    var focusSessions: [FocusSessionDefinition] = []
    var achievements: [AchievementUnlockDefinition] = []
    var rangeFetchDelay: TimeInterval = 0

    private(set) var fetchProfileCount = 0
    private(set) var fetchDailyAggregateCount = 0
    private(set) var fetchDailyAggregatesCount = 0
    private(set) var fetchXPEventsAllCount = 0
    private(set) var fetchXPEventsRangeCount = 0
    private(set) var fetchAchievementUnlocksCount = 0
    private(set) var fetchFocusSessionsCount = 0

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        lock.lock()
        fetchProfileCount += 1
        let snapshot = profile
        lock.unlock()
        completion(.success(snapshot))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        fetchXPEventsAllCount += 1
        let events = allEvents.isEmpty ? todayEvents : allEvents
        lock.unlock()
        completion(.success(events))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        fetchXPEventsRangeCount += 1
        let sourceEvents = allEvents.isEmpty ? todayEvents : allEvents
        let events = sourceEvents.filter { $0.createdAt >= startDate && $0.createdAt < endDate }
        let delay = rangeFetchDelay
        lock.unlock()

        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                completion(.success(events))
            }
            return
        }

        completion(.success(events))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        lock.lock()
        fetchAchievementUnlocksCount += 1
        let unlocks = achievements
        lock.unlock()
        completion(.success(unlocks))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        lock.lock()
        fetchDailyAggregateCount += 1
        let aggregate = dailyAggregatesByDateKey[dateKey]
        lock.unlock()
        completion(.success(aggregate))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        lock.lock()
        fetchDailyAggregatesCount += 1
        let values = weekAggregates.filter { $0.dateKey >= startDateKey && $0.dateKey <= endDateKey }
        lock.unlock()
        completion(.success(values.sorted { $0.dateKey < $1.dateKey }))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        lock.lock()
        fetchFocusSessionsCount += 1
        let sessions = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        lock.unlock()
        completion(.success(sessions))
    }
}

private final class InsightsReminderRepositorySpy: ReminderRepositoryProtocol {
    var reminders: [ReminderDefinition] = []
    var deliveriesByReminderID: [UUID: [ReminderDeliveryDefinition]] = [:]

    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) {
        completion(.success(reminders))
    }

    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) {
        completion(.success(reminder))
    }

    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) {
        completion(.success(trigger))
    }

    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) {
        completion(.success(deliveriesByReminderID[reminderID] ?? []))
    }

    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        completion(.success(delivery))
    }

    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        completion(.success(delivery))
    }
}

final class HabitRuntimeMaintenanceTests: XCTestCase {
    func testMaintainRuntimeActivatesLapseOnlyTemplateAndRollsPendingOccurrence() throws {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_710_864_000))
        let previousDay = calendar.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate

        let templateID = UUID()
        var habit = HabitDefinitionRecord(
            id: UUID(),
            lifeAreaID: UUID(),
            title: "No Smoking",
            habitType: "quit_lapse_only",
            isPaused: false,
            createdAt: previousDay,
            updatedAt: previousDay
        )
        habit.kind = .negative
        habit.trackingMode = .lapseOnly

        let habitRepository = InMemoryHabitRepository(habits: [habit])
        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habit.id,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: previousDay,
                isActive: false,
                createdAt: previousDay,
                updatedAt: previousDay
            )
        ]
        scheduleRepository.rulesByTemplateID[templateID] = [
            ScheduleRuleDefinition(
                id: UUID(),
                scheduleTemplateID: templateID,
                ruleType: "daily",
                interval: 1,
                byDayMask: nil,
                byMonthDay: nil,
                byHour: 9,
                byMinute: 0,
                rawRuleData: nil,
                createdAt: previousDay
            )
        ]

        let occurrenceID = UUID()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [
            OccurrenceDefinition(
                id: occurrenceID,
                occurrenceKey: OccurrenceKeyCodec.encode(
                    scheduleTemplateID: templateID,
                    scheduledAt: previousDay,
                    sourceID: habit.id
                ),
                scheduleTemplateID: templateID,
                sourceType: .habit,
                sourceID: habit.id,
                scheduledAt: previousDay,
                dueAt: previousDay,
                state: .pending,
                isGenerated: true,
                generationWindow: "habit_test",
                createdAt: previousDay,
                updatedAt: previousDay
            )
        ]

        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let engine = RecordingSchedulingEngine(occurrenceRepository: occurrenceRepository)
        let useCase = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: engine,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recompute
        )

        let result = try awaitResult { completion in
            useCase.execute(anchorDate: anchorDate, completion: completion)
        }

        XCTAssertEqual(result.templatesRebuilt, 1)
        XCTAssertEqual(result.rolloverUpdates, 1)
        XCTAssertEqual(engine.generateSourceFilters, [.habit])
        XCTAssertEqual(scheduleRepository.templates.first?.isActive, true)
        XCTAssertEqual(
            engine.resolvedOccurrences.map(\.resolution),
            [.completed]
        )
        XCTAssertEqual(
            occurrenceRepository.occurrences.first(where: { $0.id == occurrenceID })?.state,
            .completed
        )
    }

    func testResolveLapseOnlyMaterializesSameDayOccurrenceAndMarksFailure() throws {
        let anchorDate = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_710_950_400))
        let templateID = UUID()
        var habit = HabitDefinitionRecord(
            id: UUID(),
            lifeAreaID: UUID(),
            title: "No Alcohol",
            habitType: "quit_lapse_only",
            isPaused: false,
            createdAt: anchorDate,
            updatedAt: anchorDate
        )
        habit.kind = .negative
        habit.trackingMode = .lapseOnly

        let habitRepository = InMemoryHabitRepository(habits: [habit])
        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habit.id,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: anchorDate,
                isActive: true,
                createdAt: anchorDate,
                updatedAt: anchorDate
            )
        ]
        let occurrenceRepository = InMemoryOccurrenceRepository()
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let engine = RecordingSchedulingEngine(occurrenceRepository: occurrenceRepository)
        let gamificationRepository = InMemoryGamificationEngineRepository()
        let useCase = ResolveHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository,
            scheduleEngine: engine,
            recomputeHabitStreaksUseCase: recompute,
            gamificationEngine: GamificationEngine(repository: gamificationRepository)
        )

        _ = try awaitResult { completion in
            useCase.execute(
                habitID: habit.id,
                action: .lapsed,
                on: anchorDate,
                completion: completion
            )
        } as Void

        XCTAssertEqual(occurrenceRepository.occurrences.count, 1)
        XCTAssertEqual(occurrenceRepository.occurrences.first?.sourceID, habit.id)
        XCTAssertEqual(occurrenceRepository.occurrences.first?.state, .failed)
        XCTAssertEqual(engine.resolvedOccurrences.last?.resolution, .lapsed)

        let events = try awaitResult { completion in
            gamificationRepository.fetchXPEvents(completion: completion)
        }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.category, .habitNegativeLapse)
    }
}

final class HabitAnalyticsAndInsightsIntegrationTests: XCTestCase {
    func testCalculateDailyAnalyticsFetchesHabitSignalsByDefault() throws {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_711_036_800))
        let summary = makeHabitSummary(
            title: "Meditate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            dueAt: calendar.date(byAdding: .hour, value: 8, to: anchorDate),
            state: .completed,
            riskState: .stable
        )
        let habitReadRepository = HabitRuntimeReadRepositorySpy(signalSummaries: [summary])
        let useCase = CalculateAnalyticsUseCase(
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(tasks: []),
            habitRuntimeReadRepository: habitReadRepository
        )

        let analytics = try awaitResult { (completion: @escaping (Result<DailyAnalytics, Error>) -> Void) in
            useCase.calculateDailyAnalytics(for: anchorDate) { result in
                completion(result.mapError { $0 })
            }
        }

        XCTAssertEqual(habitReadRepository.fetchSignalsCallCount, 1)
        XCTAssertEqual(analytics.habitAnalytics.dueHabits, 1)
        XCTAssertEqual(analytics.habitAnalytics.completedPositiveHabits, 1)
        XCTAssertEqual(analytics.habitAnalytics.positiveHabitCount, 1)
        XCTAssertEqual(analytics.habitAnalytics.adherenceRate, 1.0, accuracy: 0.0001)
    }

    func testCalculateDailyAnalyticsDoesNotReuseStaleCacheWhenSuppliedSignalsChange() throws {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_711_036_800))
        let positiveSignal = TaskerHabitSignal(summary: makeHabitSummary(
            title: "Meditate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            dueAt: calendar.date(byAdding: .hour, value: 8, to: anchorDate),
            state: .completed,
            riskState: .stable
        ), referenceDate: anchorDate)
        let failedSignal = TaskerHabitSignal(summary: makeHabitSummary(
            title: "Meditate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            dueAt: calendar.date(byAdding: .hour, value: 8, to: anchorDate),
            state: .missed,
            riskState: .atRisk
        ), referenceDate: anchorDate)

        let useCase = CalculateAnalyticsUseCase(
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(tasks: [])
        )

        let firstAnalytics = try awaitResult { (completion: @escaping (Result<DailyAnalytics, Error>) -> Void) in
            useCase.calculateDailyAnalytics(for: anchorDate, habitSignals: [positiveSignal]) { result in
                completion(result.mapError { $0 })
            }
        }
        let secondAnalytics = try awaitResult { (completion: @escaping (Result<DailyAnalytics, Error>) -> Void) in
            useCase.calculateDailyAnalytics(for: anchorDate, habitSignals: [failedSignal]) { result in
                completion(result.mapError { $0 })
            }
        }

        XCTAssertEqual(firstAnalytics.habitAnalytics.completedPositiveHabits, 1)
        XCTAssertEqual(secondAnalytics.habitAnalytics.completedPositiveHabits, 0)
        XCTAssertEqual(secondAnalytics.habitAnalytics.missedHabits, 1)
    }

    func testComputeEvaHomeInsightsFetchesHabitSignalsByDefault() {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_711_123_200))
        let summary = makeHabitSummary(
            title: "No Smoking",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            dueAt: calendar.date(byAdding: .hour, value: 20, to: anchorDate),
            state: .failed,
            riskState: .atRisk
        )
        let habitReadRepository = HabitRuntimeReadRepositorySpy(signalSummaries: [summary])
        let useCase = ComputeEvaHomeInsightsUseCase(habitRuntimeReadRepository: habitReadRepository)

        let expectation = expectation(description: "eva-insights")
        var captured: EvaHomeInsights?
        useCase.execute(openTasks: [], focusTasks: [], anchorDate: anchorDate, now: anchorDate) { result in
            captured = try? result.get()
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(habitReadRepository.fetchSignalsCallCount, 1)
        XCTAssertEqual(
            captured?.focus.summaryLine,
            "Habits: 1 due, 1 at risk, 1 lapsed"
        )
    }
}

final class SaveWeeklyPlanUseCaseTests: XCTestCase {
    func testExecutePreservesExistingOutcomeStatusAndUpdatesAssignments() throws {
        let calendar = XPCalculationEngine.mondayCalendar()
        let referenceDate = Date(timeIntervalSince1970: 1_720_224_000)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: referenceDate, calendar: calendar)
        let taskID = UUID()
        let outcomeID = UUID()
        let existingPlan = WeeklyPlan(
            id: UUID(),
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            focusStatement: "Ship the week",
            selectedHabitIDs: [],
            targetCapacity: 3,
            minimumViableWeekEnabled: false,
            reviewStatus: .ready,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let existingOutcome = WeeklyOutcome(
            id: outcomeID,
            weeklyPlanID: existingPlan.id,
            title: "Close the loop",
            status: .completed,
            orderIndex: 0,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let taskRepository = InMemoryTaskDefinitionRepositoryStub(seed: [
            TaskDefinition(
                id: taskID,
                title: "Wrap launch checklist",
                planningBucket: .later,
                weeklyOutcomeID: nil,
                createdAt: weekStart,
                updatedAt: weekStart
            )
        ])
        let planRepository = InMemoryWeeklyPlanRepositoryStub(seed: [existingPlan])
        let outcomeRepository = InMemoryWeeklyOutcomeRepositoryStub(seed: [existingPlan.id: [existingOutcome]])
        let useCase = SaveWeeklyPlanUseCase(
            weeklyPlanRepository: planRepository,
            weeklyOutcomeRepository: outcomeRepository,
            updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase(repository: taskRepository),
            taskDefinitionRepository: taskRepository
        )

        let savedPlan = try awaitResult { completion in
            useCase.execute(
                request: SaveWeeklyPlanRequest(
                    weekStartDate: weekStart,
                    focusStatement: "Ship the week cleanly",
                    selectedHabitIDs: [],
                    targetCapacity: 4,
                    minimumViableWeekEnabled: true,
                    outcomes: [
                        SaveWeeklyPlanOutcomeInput(
                            id: outcomeID,
                            title: "Close the loop harder",
                            whyItMatters: "Reduces drag",
                            successDefinition: "All follow-through done"
                        )
                    ],
                    taskAssignments: [
                        SaveWeeklyPlanTaskAssignment(
                            task: taskRepository.byID[taskID]!,
                            planningBucket: .thisWeek,
                            weeklyOutcomeID: outcomeID
                        )
                    ],
                    savedAt: weekStart.addingTimeInterval(3600)
                ),
                completion: completion
            )
        }

        XCTAssertEqual(savedPlan.id, existingPlan.id)
        XCTAssertEqual(savedPlan.targetCapacity, 4)
        XCTAssertTrue(savedPlan.minimumViableWeekEnabled)

        let persistedOutcome = try XCTUnwrap(outcomeRepository.outcomesByPlanID[existingPlan.id]?.first)
        XCTAssertEqual(persistedOutcome.status, .completed)
        XCTAssertEqual(persistedOutcome.title, "Close the loop harder")

        let updatedTask = try XCTUnwrap(taskRepository.byID[taskID])
        XCTAssertEqual(updatedTask.planningBucket, .thisWeek)
        XCTAssertEqual(updatedTask.weeklyOutcomeID, outcomeID)
    }

    func testExecuteFailsWhenTaskUpdateFailsAndLeavesTaskUnchanged() {
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            title: "Failing assignment",
            planningBucket: .later,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let baseRepository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let taskRepository = FailingTaskDefinitionRepositoryStub(base: baseRepository, failingIDs: [taskID])
        let planRepository = InMemoryWeeklyPlanRepositoryStub()
        let outcomeRepository = InMemoryWeeklyOutcomeRepositoryStub()
        let useCase = SaveWeeklyPlanUseCase(
            weeklyPlanRepository: planRepository,
            weeklyOutcomeRepository: outcomeRepository,
            updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase(repository: taskRepository),
            taskDefinitionRepository: taskRepository
        )

        do {
            let _: WeeklyPlan = try awaitResult { completion in
                useCase.execute(
                    request: SaveWeeklyPlanRequest(
                        weekStartDate: weekStart,
                        focusStatement: "Should fail",
                        selectedHabitIDs: [],
                        targetCapacity: 2,
                        minimumViableWeekEnabled: false,
                        outcomes: [],
                        taskAssignments: [
                            SaveWeeklyPlanTaskAssignment(
                                task: task,
                                planningBucket: .thisWeek,
                                weeklyOutcomeID: nil
                            )
                        ],
                        savedAt: weekStart
                    ),
                    completion: completion
                )
            }
            XCTFail("Expected weekly plan save to fail")
        } catch {
            XCTAssertEqual((error as NSError).domain, "FailingTaskDefinitionRepositoryStub")
        }

        XCTAssertEqual(baseRepository.byID[taskID]?.planningBucket, .later)
    }
}

private func canonicalISOWeekStart(_ date: Date) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return XPCalculationEngine.startOfWeek(for: date, startingOn: .monday, calendar: calendar)
}

private func isSameCanonicalISOWeek(_ lhs: Date?, _ rhs: Date) -> Bool {
    guard let lhs else { return false }
    return canonicalISOWeekStart(lhs) == canonicalISOWeekStart(rhs)
}

final class WeeklyReviewDraftStoreTests: XCTestCase {
    private struct LegacyWeeklyReviewLocalStateFile: Codable {
        var draftsByWeekKey: [String: WeeklyReviewDraft]
        var completedTaskDecisionsByWeekKey: [String: [WeeklyReviewTaskDecision]]
    }

    func testRoundTripsDraftAndCompletedTaskDecisions() throws {
        let suiteName = "WeeklyReviewDraftStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "tasker.weekly.review.localstate.tests"
        let store = UserDefaultsWeeklyReviewDraftStore(defaults: defaults, storageKey: storageKey)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let taskID = UUID()
        let outcomeID = UUID()
        let draft = WeeklyReviewDraft(
            weekStartDate: weekStart,
            wins: "Won the week",
            blockers: "One blocker",
            lessons: "Keep scope tighter",
            nextWeekPrepNotes: "Start Monday with admin",
            perceivedWeekRating: 4,
            taskDecisions: [taskID: .carry],
            outcomeStatuses: [outcomeID: .completed],
            updatedAt: weekStart.addingTimeInterval(60)
        )
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let savedDraft = try awaitResult { completion in
            store.saveDraft(draft, completion: completion)
        }
        XCTAssertEqual(savedDraft.wins, "Won the week")

        let fetchedDraft = try awaitResult { completion in
            store.fetchDraft(weekStartDate: weekStart, completion: completion)
        }
        XCTAssertEqual(fetchedDraft?.taskDecisions[taskID], .carry)
        XCTAssertEqual(fetchedDraft?.outcomeStatuses[outcomeID], .completed)

        let decisions = [
            WeeklyReviewTaskDecision(taskID: taskID, disposition: .later)
        ]
        let savedDecisions = try awaitResult { completion in
            store.saveCompletedTaskDecisions(decisions, weekStartDate: weekStart, completion: completion)
        }
        XCTAssertEqual(savedDecisions, decisions)

        let fetchedDecisions = try awaitResult { completion in
            store.fetchCompletedTaskDecisions(weekStartDate: weekStart, completion: completion)
        }
        XCTAssertEqual(fetchedDecisions, decisions)

        let _: Void = try awaitResult { completion in
            store.clearDraft(weekStartDate: weekStart, completion: completion)
        }
        let clearedDraft = try awaitResult { completion in
            store.fetchDraft(weekStartDate: weekStart, completion: completion)
        }
        XCTAssertNil(clearedDraft)
    }

    func testFetchDraftMigratesLegacyAliasKeyToCanonicalWeekIdentity() throws {
        let suiteName = "WeeklyReviewDraftStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "tasker.weekly.review.localstate.tests"
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let referenceDate = Date(timeIntervalSince1970: 1_720_224_000)
        let legacyWeekStart = XPCalculationEngine.startOfWeek(for: referenceDate, startingOn: .sunday)
        let canonicalWeekStart = XPCalculationEngine.mondayStartOfWeek(
            for: referenceDate,
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let taskID = UUID()
        let outcomeID = UUID()
        let draft = WeeklyReviewDraft(
            weekStartDate: legacyWeekStart,
            wins: "Legacy key",
            blockers: "Legacy blockers",
            lessons: "Legacy lessons",
            nextWeekPrepNotes: "Legacy prep",
            perceivedWeekRating: 3,
            taskDecisions: [taskID: .carry],
            outcomeStatuses: [outcomeID: .completed],
            updatedAt: referenceDate
        )

        let legacyKey = isoDateStorageKey(for: legacyWeekStart)
        let legacyState = LegacyWeeklyReviewLocalStateFile(
            draftsByWeekKey: [legacyKey: draft],
            completedTaskDecisionsByWeekKey: [
                legacyKey: [WeeklyReviewTaskDecision(taskID: taskID, disposition: .carry)]
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(legacyState), forKey: storageKey)

        let store = UserDefaultsWeeklyReviewDraftStore(defaults: defaults, storageKey: storageKey)

        let fetchedDraft = try awaitResult { completion in
            store.fetchDraft(weekStartDate: canonicalWeekStart, completion: completion)
        }
        let fetchedDecisions = try awaitResult { completion in
            store.fetchCompletedTaskDecisions(weekStartDate: canonicalWeekStart, completion: completion)
        }

        XCTAssertEqual(fetchedDraft?.wins, "Legacy key")
        XCTAssertTrue(isSameCanonicalISOWeek(fetchedDraft?.weekStartDate, canonicalWeekStart))
        XCTAssertEqual(fetchedDecisions.first?.disposition, .carry)

        let persisted = try decodeStorageJSON(defaults: defaults, storageKey: storageKey)
        let draftKeys = Set((persisted["draftsByWeekKey"] as? [String: Any] ?? [:]).keys)
        let completedKeys = Set((persisted["completedTaskDecisionsByWeekKey"] as? [String: Any] ?? [:]).keys)
        XCTAssertEqual(draftKeys.count, 1)
        XCTAssertEqual(completedKeys.count, 1)
        XCTAssertTrue(draftKeys.allSatisfy { $0.hasPrefix("iso:") })
        XCTAssertTrue(completedKeys.allSatisfy { $0.hasPrefix("iso:") })
        XCTAssertFalse(draftKeys.contains(legacyKey))
        XCTAssertFalse(completedKeys.contains(legacyKey))
    }

    func testDraftStorePrunesToMostRecentTwentySixWeeks() throws {
        let suiteName = "WeeklyReviewDraftStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "tasker.weekly.review.localstate.tests"
        let store = UserDefaultsWeeklyReviewDraftStore(defaults: defaults, storageKey: storageKey)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let referenceWeek = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let calendar = Calendar(identifier: .gregorian)

        for offset in 0..<30 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: referenceWeek) ?? referenceWeek
            let draft = WeeklyReviewDraft(
                weekStartDate: weekStart,
                wins: "Week \(offset)",
                blockers: nil,
                lessons: nil,
                nextWeekPrepNotes: nil,
                perceivedWeekRating: 4,
                taskDecisions: [:],
                outcomeStatuses: [:],
                updatedAt: weekStart.addingTimeInterval(Double(offset))
            )
            _ = try awaitResult { completion in
                store.saveDraft(draft, completion: completion)
            }
            _ = try awaitResult { completion in
                store.saveCompletedTaskDecisions(
                    [WeeklyReviewTaskDecision(taskID: UUID(), disposition: .later)],
                    weekStartDate: weekStart,
                    completion: completion
                )
            }
        }

        let persisted = try decodeStorageJSON(defaults: defaults, storageKey: storageKey)
        let draftKeys = Set((persisted["draftsByWeekKey"] as? [String: Any] ?? [:]).keys)
        let completedKeys = Set((persisted["completedTaskDecisionsByWeekKey"] as? [String: Any] ?? [:]).keys)
        XCTAssertEqual(draftKeys.count, 26)
        XCTAssertEqual(completedKeys.count, 26)
        XCTAssertTrue(draftKeys.allSatisfy { $0.hasPrefix("iso:") })
        XCTAssertTrue(completedKeys.allSatisfy { $0.hasPrefix("iso:") })

        let prunedWeekStart = calendar.date(byAdding: .weekOfYear, value: -29, to: referenceWeek) ?? referenceWeek
        let keptWeekStart = calendar.date(byAdding: .weekOfYear, value: -25, to: referenceWeek) ?? referenceWeek
        let prunedDraft = try awaitResult { completion in
            store.fetchDraft(weekStartDate: prunedWeekStart, completion: completion)
        }
        let keptDraft = try awaitResult { completion in
            store.fetchDraft(weekStartDate: keptWeekStart, completion: completion)
        }
        XCTAssertNil(prunedDraft)
        XCTAssertNotNil(keptDraft)
    }

    private func isoDateStorageKey(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func decodeStorageJSON(defaults: UserDefaults, storageKey: String) throws -> [String: Any] {
        let data = try XCTUnwrap(defaults.data(forKey: storageKey))
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}

final class BuildRecoveryInsightsUseCaseTests: XCTestCase {
    func testExecuteBuildsRecoveryNarrativeFromTaskDecisions() {
        let useCase = BuildRecoveryInsightsUseCase()

        let insights = useCase.execute(decisions: [
            WeeklyReviewTaskDecision(taskID: UUID(), disposition: .carry),
            WeeklyReviewTaskDecision(taskID: UUID(), disposition: .carry),
            WeeklyReviewTaskDecision(taskID: UUID(), disposition: .drop)
        ])

        XCTAssertEqual(insights.carryForwardCount, 2)
        XCTAssertEqual(insights.laterCount, 0)
        XCTAssertEqual(insights.droppedCount, 1)
        XCTAssertEqual(insights.headline, "Next week is inheriting some pressure.")
        XCTAssertEqual(insights.narrative, "2 carried, 0 moved later, 1 consciously dropped.")
    }
}

final class CoreDataWeeklyReviewMutationRepositoryTests: XCTestCase {
    func testFinalizeReviewAppliesTaskDecisionOutcomeStatusAndPlanCompletion() throws {
        let container = try makeWeeklyContainer()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let planRepository = CoreDataWeeklyPlanRepository(container: container)
        let outcomeRepository = CoreDataWeeklyOutcomeRepository(container: container)
        let reviewRepository = CoreDataWeeklyReviewRepository(container: container)
        let mutationRepository = CoreDataWeeklyReviewMutationRepository(container: container)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let plan = WeeklyPlan(
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            reviewStatus: .ready,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedPlan = try awaitResult { completion in
            planRepository.savePlan(plan, completion: completion)
        }
        let outcome = WeeklyOutcome(
            weeklyPlanID: savedPlan.id,
            title: "Close launch",
            status: .planned,
            orderIndex: 0,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        _ = try awaitResult { completion in
            outcomeRepository.replaceOutcomes(weeklyPlanID: savedPlan.id, outcomes: [outcome], completion: completion)
        }
        let task = TaskDefinition(
            title: "Finalize postmortem",
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcome.id,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedTask = try awaitResult { completion in
            taskRepository.create(task, completion: completion)
        }

        let result = try awaitResult { completion in
            mutationRepository.finalizeReview(
                request: CompleteWeeklyReviewRequest(
                    weeklyPlanID: savedPlan.id,
                    wins: "Wrapped",
                    blockers: "None",
                    lessons: "Keep the finish line visible",
                    nextWeekPrepNotes: "Start with cleanup",
                    perceivedWeekRating: 4,
                    taskDecisions: [
                        WeeklyReviewTaskDecision(taskID: savedTask.id, disposition: .later)
                    ],
                    outcomeStatusesByOutcomeID: [outcome.id: .completed],
                    completedAt: weekStart.addingTimeInterval(3600)
                ),
                completion: completion
            )
        }

        XCTAssertEqual(result.review.weeklyPlanID, savedPlan.id)
        XCTAssertEqual(result.review.wins, "Wrapped")
        XCTAssertTrue(result.skippedTaskIDs.isEmpty)
        XCTAssertTrue(result.skippedOutcomeIDs.isEmpty)

        let updatedTask = try XCTUnwrap(try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: savedTask.id, completion: completion)
        })
        XCTAssertEqual(updatedTask.planningBucket, .later)
        XCTAssertNil(updatedTask.weeklyOutcomeID)
        XCTAssertTrue(isSameCanonicalISOWeek(updatedTask.deferredFromWeekStart, weekStart))
        XCTAssertEqual(updatedTask.deferredCount, 0)

        let updatedOutcomes = try awaitResult { completion in
            outcomeRepository.fetchOutcomes(weeklyPlanID: savedPlan.id, completion: completion)
        }
        let updatedOutcome = try XCTUnwrap(updatedOutcomes.first)
        XCTAssertEqual(updatedOutcome.status, .completed)

        let completedPlan = try XCTUnwrap(try awaitResult { completion in
            planRepository.fetchPlan(id: savedPlan.id, completion: completion)
        })
        XCTAssertEqual(completedPlan.reviewStatus, .completed)

        let persistedReview = try awaitResult { completion in
            reviewRepository.fetchReview(weeklyPlanID: savedPlan.id, completion: completion)
        }
        XCTAssertEqual(persistedReview?.wins, "Wrapped")
    }

    func testFinalizeReviewSkipsMissingReviewedTaskAndPersistsRemainingChanges() throws {
        let container = try makeWeeklyContainer()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let planRepository = CoreDataWeeklyPlanRepository(container: container)
        let outcomeRepository = CoreDataWeeklyOutcomeRepository(container: container)
        let reviewRepository = CoreDataWeeklyReviewRepository(container: container)
        let mutationRepository = CoreDataWeeklyReviewMutationRepository(container: container)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let plan = WeeklyPlan(
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            reviewStatus: .ready,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedPlan = try awaitResult { completion in
            planRepository.savePlan(plan, completion: completion)
        }
        let outcome = WeeklyOutcome(
            weeklyPlanID: savedPlan.id,
            title: "Keep pressure low",
            status: .planned,
            orderIndex: 0,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        _ = try awaitResult { completion in
            outcomeRepository.replaceOutcomes(weeklyPlanID: savedPlan.id, outcomes: [outcome], completion: completion)
        }
        let task = TaskDefinition(
            title: "Legit weekly task",
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcome.id,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedTask = try awaitResult { completion in
            taskRepository.create(task, completion: completion)
        }

        let result = try awaitResult { completion in
            mutationRepository.finalizeReview(
                request: CompleteWeeklyReviewRequest(
                    weeklyPlanID: savedPlan.id,
                    taskDecisions: [
                        WeeklyReviewTaskDecision(taskID: UUID(), disposition: .drop),
                        WeeklyReviewTaskDecision(taskID: savedTask.id, disposition: .later)
                    ],
                    outcomeStatusesByOutcomeID: [outcome.id: .completed],
                    completedAt: weekStart.addingTimeInterval(7200)
                ),
                completion: completion
            )
        }

        XCTAssertEqual(result.review.weeklyPlanID, savedPlan.id)
        XCTAssertEqual(result.skippedTaskIDs.count, 1)
        XCTAssertTrue(result.skippedOutcomeIDs.isEmpty)

        let unchangedTask = try XCTUnwrap(try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: savedTask.id, completion: completion)
        })
        XCTAssertEqual(unchangedTask.planningBucket, .later)
        XCTAssertNil(unchangedTask.weeklyOutcomeID)

        let unchangedOutcomes = try awaitResult { completion in
            outcomeRepository.fetchOutcomes(weeklyPlanID: savedPlan.id, completion: completion)
        }
        let unchangedOutcome = try XCTUnwrap(unchangedOutcomes.first)
        XCTAssertEqual(unchangedOutcome.status, .completed)

        let persistedReview = try awaitResult { completion in
            reviewRepository.fetchReview(weeklyPlanID: savedPlan.id, completion: completion)
        }
        XCTAssertEqual(persistedReview?.weeklyPlanID, savedPlan.id)

        let planAfterFailure = try XCTUnwrap(try awaitResult { completion in
            planRepository.fetchPlan(id: savedPlan.id, completion: completion)
        })
        XCTAssertEqual(planAfterFailure.reviewStatus, .completed)
    }

    func testFinalizeReviewSkipsMissingOutcomeStatusWithoutBlockingCompletion() throws {
        let container = try makeWeeklyContainer()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let planRepository = CoreDataWeeklyPlanRepository(container: container)
        let outcomeRepository = CoreDataWeeklyOutcomeRepository(container: container)
        let mutationRepository = CoreDataWeeklyReviewMutationRepository(container: container)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let plan = WeeklyPlan(
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            reviewStatus: .ready,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedPlan = try awaitResult { completion in
            planRepository.savePlan(plan, completion: completion)
        }
        let outcome = WeeklyOutcome(
            weeklyPlanID: savedPlan.id,
            title: "Keep pressure low",
            status: .planned,
            orderIndex: 0,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        _ = try awaitResult { completion in
            outcomeRepository.replaceOutcomes(weeklyPlanID: savedPlan.id, outcomes: [outcome], completion: completion)
        }
        let task = TaskDefinition(
            title: "Legit weekly task",
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcome.id,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        _ = try awaitResult { completion in
            taskRepository.create(task, completion: completion)
        }

        let result = try awaitResult { completion in
            mutationRepository.finalizeReview(
                request: CompleteWeeklyReviewRequest(
                    weeklyPlanID: savedPlan.id,
                    taskDecisions: [],
                    outcomeStatusesByOutcomeID: [
                        UUID(): .completed,
                        outcome.id: .dropped
                    ],
                    completedAt: weekStart.addingTimeInterval(7200)
                ),
                completion: completion
            )
        }

        XCTAssertEqual(result.skippedOutcomeIDs.count, 1)
        let outcomes = try awaitResult { completion in
            outcomeRepository.fetchOutcomes(weeklyPlanID: savedPlan.id, completion: completion)
        }
        XCTAssertEqual(outcomes.first?.status, .dropped)
    }

    func testFinalizeReviewCarryDecisionIsIdempotentForSameWeek() throws {
        let container = try makeWeeklyContainer()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let planRepository = CoreDataWeeklyPlanRepository(container: container)
        let mutationRepository = CoreDataWeeklyReviewMutationRepository(container: container)
        let weekStart = XPCalculationEngine.mondayStartOfWeek(
            for: Date(timeIntervalSince1970: 1_720_224_000),
            calendar: XPCalculationEngine.mondayCalendar()
        )

        let plan = WeeklyPlan(
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            reviewStatus: .ready,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedPlan = try awaitResult { completion in
            planRepository.savePlan(plan, completion: completion)
        }
        let task = TaskDefinition(
            title: "Carry me once",
            planningBucket: .thisWeek,
            createdAt: weekStart,
            updatedAt: weekStart
        )
        let savedTask = try awaitResult { completion in
            taskRepository.create(task, completion: completion)
        }

        let request = CompleteWeeklyReviewRequest(
            weeklyPlanID: savedPlan.id,
            taskDecisions: [WeeklyReviewTaskDecision(taskID: savedTask.id, disposition: .carry)],
            completedAt: weekStart.addingTimeInterval(3600)
        )
        _ = try awaitResult { completion in
            mutationRepository.finalizeReview(request: request, completion: completion)
        }

        let afterFirstPass = try XCTUnwrap(try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: savedTask.id, completion: completion)
        })
        XCTAssertEqual(afterFirstPass.deferredCount, 1)
        XCTAssertTrue(isSameCanonicalISOWeek(afterFirstPass.deferredFromWeekStart, weekStart))

        _ = try awaitResult { completion in
            mutationRepository.finalizeReview(
                request: CompleteWeeklyReviewRequest(
                    weeklyPlanID: savedPlan.id,
                    taskDecisions: [WeeklyReviewTaskDecision(taskID: savedTask.id, disposition: .carry)],
                    completedAt: weekStart.addingTimeInterval(7200)
                ),
                completion: completion
            )
        }

        let afterSecondPass = try XCTUnwrap(try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: savedTask.id, completion: completion)
        })
        XCTAssertEqual(afterSecondPass.deferredCount, 1)
    }

    func testFetchPlanMigratesLegacyWeekStartAliasToCanonicalIdentity() throws {
        let container = try makeWeeklyContainer()
        let planRepository = CoreDataWeeklyPlanRepository(container: container)
        let referenceDate = Date(timeIntervalSince1970: 1_720_224_000)
        let canonicalWeekStart = XPCalculationEngine.mondayStartOfWeek(
            for: referenceDate,
            calendar: XPCalculationEngine.mondayCalendar()
        )
        let legacyWeekStart = XPCalculationEngine.startOfWeek(for: referenceDate, startingOn: .sunday)
        let planID = UUID()
        let createdAt = referenceDate.addingTimeInterval(-120)
        let updatedAt = referenceDate.addingTimeInterval(-60)

        var insertionError: Error?
        container.viewContext.performAndWait {
            do {
                let object = NSEntityDescription.insertNewObject(forEntityName: "WeeklyPlan", into: container.viewContext)
                object.setValue(planID, forKey: "id")
                object.setValue(legacyWeekStart, forKey: "weekStartDate")
                object.setValue(
                    Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: legacyWeekStart),
                    forKey: "weekEndDate"
                )
                object.setValue("Legacy keyed plan", forKey: "focusStatement")
                object.setValue([], forKey: "selectedHabitIDs")
                object.setValue(WeeklyPlanReviewStatus.ready.rawValue, forKey: "reviewStatus")
                object.setValue(createdAt, forKey: "createdAt")
                object.setValue(updatedAt, forKey: "updatedAt")
                try container.viewContext.save()
            } catch {
                insertionError = error
            }
        }
        if let insertionError {
            throw insertionError
        }

        let fetchedFromLegacyStart = try awaitResult { completion in
            planRepository.fetchPlan(forWeekStarting: legacyWeekStart, completion: completion)
        }
        let fetchedFromCanonicalStart = try awaitResult { completion in
            planRepository.fetchPlan(forWeekStarting: canonicalWeekStart, completion: completion)
        }

        XCTAssertEqual(fetchedFromLegacyStart?.id, planID)
        XCTAssertEqual(fetchedFromCanonicalStart?.id, planID)
        XCTAssertTrue(isSameCanonicalISOWeek(fetchedFromLegacyStart?.weekStartDate, canonicalWeekStart))

        let persisted = try awaitResult { completion in
            planRepository.fetchPlan(id: planID, completion: completion)
        }
        XCTAssertTrue(isSameCanonicalISOWeek(persisted?.weekStartDate, canonicalWeekStart))
    }

    private func makeWeeklyContainer() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let modelURL = bundles.compactMap({ $0.url(forResource: "TaskModelV3", withExtension: "momd") }).first,
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(
                domain: "CoreDataWeeklyReviewMutationRepositoryTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load compiled TaskModelV3 model"]
            )
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

private final class InMemoryWeeklyPlanRepositoryStub: WeeklyPlanRepositoryProtocol {
    private(set) var plansByID: [UUID: WeeklyPlan]

    init(seed: [WeeklyPlan] = []) {
        self.plansByID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        completion(.success(plansByID[id]))
    }

    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        completion(.success(plansByID.values.first(where: { Calendar(identifier: .gregorian).isDate($0.weekStartDate, inSameDayAs: weekStartDate) })))
    }

    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void) {
        completion(.success(plansByID.values.filter { $0.weekStartDate >= startDate && $0.weekStartDate <= endDate }))
    }

    func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void) {
        plansByID[plan.id] = plan
        completion(.success(plan))
    }
}

private final class InMemoryWeeklyOutcomeRepositoryStub: WeeklyOutcomeRepositoryProtocol {
    fileprivate(set) var outcomesByPlanID: [UUID: [WeeklyOutcome]]

    init(seed: [UUID: [WeeklyOutcome]] = [:]) {
        self.outcomesByPlanID = seed
    }

    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) {
        completion(.success(outcomesByPlanID[weeklyPlanID] ?? []))
    }

    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void) {
        var outcomes = outcomesByPlanID[outcome.weeklyPlanID] ?? []
        outcomes.removeAll { $0.id == outcome.id }
        outcomes.append(outcome)
        outcomes.sort { $0.orderIndex < $1.orderIndex }
        outcomesByPlanID[outcome.weeklyPlanID] = outcomes
        completion(.success(outcome))
    }

    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        outcomesByPlanID[weeklyPlanID] = outcomes.sorted { $0.orderIndex < $1.orderIndex }
        completion(.success(outcomesByPlanID[weeklyPlanID] ?? []))
    }

    func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        for key in outcomesByPlanID.keys {
            outcomesByPlanID[key]?.removeAll { $0.id == id }
        }
        completion(.success(()))
    }
}

private final class FailingTaskDefinitionRepositoryStub: TaskDefinitionRepositoryProtocol {
    let base: InMemoryTaskDefinitionRepositoryStub
    let failingIDs: Set<UUID>

    init(base: InMemoryTaskDefinitionRepositoryStub, failingIDs: Set<UUID>) {
        self.base = base
        self.failingIDs = failingIDs
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchAll(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchAll(query: query, completion: completion)
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        base.fetchTaskDefinition(id: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(task, completion: completion)
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(request: request, completion: completion)
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        if failingIDs.contains(task.id) {
            completion(.failure(NSError(domain: "FailingTaskDefinitionRepositoryStub", code: 1)))
            return
        }
        base.update(task, completion: completion)
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        if failingIDs.contains(request.id) {
            completion(.failure(NSError(domain: "FailingTaskDefinitionRepositoryStub", code: 1)))
            return
        }
        base.update(request: request, completion: completion)
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        base.delete(id: id, completion: completion)
    }
}

@MainActor
final class AddHabitViewModelValidationTests: XCTestCase {
    func testLoadIfNeededRebaselinesAutofilledDefaults() async {
        let (viewModel, _) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        XCTAssertNotNil(viewModel.selectedLifeAreaID)
        XCTAssertNotNil(viewModel.selectedIconSymbolName)
        XCTAssertNotNil(TaskerHexColor.normalized(viewModel.selectedColorHex))
        XCTAssertFalse(viewModel.hasUnsavedChanges)

        viewModel.habitName = "Walk"
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }

    func testResetFormSeedsFreshAppearanceDefaults() async {
        let (viewModel, _) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Read"
        viewModel.selectedColorHex = ""
        viewModel.selectedIconSymbolName = nil

        viewModel.resetForm()

        XCTAssertEqual(viewModel.habitName, "")
        XCTAssertNotNil(viewModel.selectedIconSymbolName)
        XCTAssertNotNil(TaskerHexColor.normalized(viewModel.selectedColorHex))
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }

    func testCreateHabitIgnoresReentrantSubmissionWhileSaving() async {
        let (viewModel, habitRepository) = makeViewModel(deferCreateCompletion: true)

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Hydrate"

        viewModel.createHabit { _ in }
        viewModel.createHabit { _ in }

        XCTAssertTrue(viewModel.isSaving)
        XCTAssertEqual(habitRepository.createCallCount, 1)
    }

    func testReminderWindowValidationRejectsEndBeforeStart() {
        let (viewModel, _) = makeViewModel()
        viewModel.selectedLifeAreaID = UUID()
        viewModel.reminderWindowStart = "21:00"
        viewModel.reminderWindowEnd = "08:00"

        XCTAssertEqual(
            viewModel.reminderWindowValidationError,
            "Reminder end must be after the start on the same day."
        )
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testCreateHabitNormalizesSixDigitHexColor() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Hydrate"
        viewModel.selectedColorHex = "3b82f6"

        let expectation = expectation(description: "create normalized color")
        viewModel.createHabit { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        XCTAssertEqual(createdHabit.colorHex, "#3B82F6")
    }

    func testApplyPrefillWithExplicitIconRandomizesMissingColor() async {
        let (viewModel, _) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        let explicitIcon = "book.fill"
        viewModel.selectedColorHex = ""
        viewModel.applyPrefill(
            AddHabitPrefillTemplate(
                title: "Read",
                lifeAreaID: viewModel.selectedLifeAreaID,
                iconSymbolName: explicitIcon
            )
        )

        XCTAssertEqual(viewModel.selectedIconSymbolName, explicitIcon)
        XCTAssertNotNil(TaskerHexColor.normalized(viewModel.selectedColorHex))
    }

    func testLoadIfNeededBackfillsLifeAreaFromPrefilledProjectSelection() async {
        let lifeAreaID = UUID()
        let project = Project(
            id: UUID(),
            lifeAreaID: lifeAreaID,
            name: "Deep Work",
            createdDate: Date(),
            modifiedDate: Date(),
            isArchived: false
        )
        let (viewModel, _) = makeViewModel(
            lifeAreas: [LifeArea(id: lifeAreaID, name: "Work", createdAt: Date(), updatedAt: Date())],
            projects: [project]
        )
        viewModel.selectedProjectID = project.id

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        XCTAssertEqual(viewModel.selectedProjectID, project.id)
        XCTAssertEqual(viewModel.selectedLifeAreaID, lifeAreaID)
    }

    func testCreateHabitRandomizesMissingAppearance() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Hydrate"
        viewModel.selectedIconSymbolName = nil
        viewModel.selectedColorHex = ""

        let expectation = expectation(description: "create randomized appearance")
        viewModel.createHabit { result in
            if case .failure(let error) = result {
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        assertHabitAppearanceAssigned(createdHabit)
    }

    func testCreateHabitHonorsExplicitIconAndColor() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Journal"
        viewModel.selectedIconSymbolName = "book.fill"
        viewModel.selectedColorHex = "#5AA7A4"

        let expectation = expectation(description: "create explicit appearance")
        viewModel.createHabit { result in
            if case .failure(let error) = result {
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        XCTAssertEqual(createdHabit.iconSymbolName, "book.fill")
        XCTAssertEqual(createdHabit.colorHex, "#5AA7A4")
    }

    func testCreateHabitHonorsExplicitIconWhileRandomizingMissingColor() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Meditate"
        viewModel.selectedIconSymbolName = "sparkles"
        viewModel.selectedColorHex = ""

        let expectation = expectation(description: "create explicit icon only")
        viewModel.createHabit { result in
            if case .failure(let error) = result {
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        XCTAssertEqual(createdHabit.iconSymbolName, "sparkles")
        XCTAssertNotNil(createdHabit.colorHex)
    }

    func testCreateHabitHonorsExplicitColorWhileRandomizingMissingIcon() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Stretch"
        viewModel.selectedIconSymbolName = nil
        viewModel.selectedColorHex = "#8A46B5"

        let expectation = expectation(description: "create explicit color only")
        viewModel.createHabit { result in
            if case .failure(let error) = result {
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        XCTAssertNotNil(createdHabit.iconSymbolName)
        XCTAssertEqual(createdHabit.colorHex, "#8A46B5")
    }

    func testCreateHabitDropsInvalidHexColor() async {
        let (viewModel, habitRepository) = makeViewModel()

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.isLoading == false }

        viewModel.habitName = "Journal"
        viewModel.selectedColorHex = "blue"

        let expectation = expectation(description: "create invalid color")
        viewModel.createHabit { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Expected habit creation to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        guard let createdHabit = habitRepository.habitsByID.values.first else {
            XCTFail("Expected created habit to be stored")
            return
        }
        XCTAssertNil(createdHabit.colorHex)
    }

    private func assertHabitAppearanceAssigned(_ habit: HabitDefinitionRecord) {
        XCTAssertNotNil(habit.iconSymbolName)
        XCTAssertNotNil(habit.colorHex)
        XCTAssertNotNil(TaskerHexColor.normalized(habit.colorHex))
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        let pollInterval = Duration.nanoseconds(Int64(pollIntervalNanoseconds))

        while condition() == false {
            if ContinuousClock.now - start >= timeout {
                XCTFail("Timed out waiting for condition")
                return
            }
            try? await _Concurrency.Task.sleep(for: pollInterval)
        }
    }

    private func makeViewModel(
        deferCreateCompletion: Bool = false,
        lifeAreas: [LifeArea]? = nil,
        projects: [Project] = []
    ) -> (viewModel: AddHabitViewModel, habitRepository: InMemoryHabitRepository) {
        let anchorDate = Date(timeIntervalSince1970: 1_711_036_800)
        let lifeAreaID = UUID()
        let habitRepository = InMemoryHabitRepository()
        habitRepository.deferCreateCompletion = deferCreateCompletion
        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        let maintainHabitRuntimeUseCase = MaintainHabitRuntimeUseCase(
            syncHabitScheduleUseCase: SyncHabitScheduleUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                scheduleEngine: CoreSchedulingEngine(
                    scheduleRepository: scheduleRepository,
                    occurrenceRepository: occurrenceRepository
                ),
                occurrenceRepository: occurrenceRepository,
                recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                    habitRepository: habitRepository,
                    occurrenceRepository: occurrenceRepository
                )
            )
        )
        let lifeAreaRepository = CapturingLifeAreaRepository(
            storedAreas: lifeAreas ?? [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
        )
        let projectRepository = MockProjectRepository(projects: projects)

        return (
            AddHabitViewModel(
                createHabitUseCase: CreateHabitUseCase(
                    habitRepository: habitRepository,
                    lifeAreaRepository: lifeAreaRepository,
                    projectRepository: projectRepository,
                    scheduleRepository: scheduleRepository,
                    maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
                ),
                manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: lifeAreaRepository),
                manageProjectsUseCase: ManageProjectsUseCase(projectRepository: projectRepository)
            ),
            habitRepository
        )
    }
}

@MainActor
final class HabitDetailViewModelHydrationTests: XCTestCase {
    func testLoadIfNeededUsesTargetedReadOnlyHydrationOnly() async {
        let fixture = makeDetailFixture(returnedTitle: "Hydrate refreshed")

        XCTAssertFalse(fixture.viewModel.isCalendarMounted)
        XCTAssertFalse(fixture.viewModel.calendarViewState.weeks.isEmpty)

        fixture.viewModel.loadIfNeeded()
        await waitUntil { fixture.viewModel.isCalendarMounted }
        await waitUntil { fixture.viewModel.isLoading == false }

        XCTAssertEqual(fixture.readRepository.fetchDetailSummaryCallCount, 1)
        XCTAssertEqual(fixture.readRepository.fetchFilteredLibraryCallCount, 0)
        XCTAssertEqual(fixture.readRepository.fetchAllLibraryCallCount, 0)
        XCTAssertEqual(fixture.readRepository.fetchHistoryCallCount, 1)
        XCTAssertEqual(fixture.lifeAreaRepository.fetchAllCallCount, 0)
        XCTAssertEqual(fixture.projectRepository.fetchAllProjectsCallCount, 0)
        XCTAssertEqual(fixture.projectRepository.getTaskCountCallCount, 0)
        XCTAssertEqual(fixture.viewModel.row.title, "Hydrate refreshed")
        XCTAssertFalse(fixture.viewModel.isPreparingEditorData)
    }

    func testBeginEditingDefersAndCachesEditorSupportLoading() async {
        let fixture = makeDetailFixture()

        fixture.viewModel.loadIfNeeded()
        await waitUntil { fixture.viewModel.isLoading == false }

        fixture.viewModel.beginEditing()
        await waitUntil { fixture.viewModel.isEditing }

        XCTAssertEqual(fixture.lifeAreaRepository.fetchAllCallCount, 1)
        XCTAssertEqual(fixture.projectRepository.fetchAllProjectsCallCount, 1)
        XCTAssertEqual(fixture.projectRepository.getTaskCountCallCount, fixture.projectRepository.projectCount)
        XCTAssertFalse(fixture.viewModel.isPreparingEditorData)

        fixture.viewModel.cancelEditing()
        fixture.viewModel.beginEditing()
        await waitUntil { fixture.viewModel.isEditing }

        XCTAssertEqual(fixture.lifeAreaRepository.fetchAllCallCount, 1)
        XCTAssertEqual(fixture.projectRepository.fetchAllProjectsCallCount, 1)
        XCTAssertEqual(fixture.projectRepository.getTaskCountCallCount, fixture.projectRepository.projectCount)
    }

    func testMutateDayRefreshesReadOnlyDataWithoutLoadingEditorSupport() async {
        let fixture = makeDetailFixture()
        fixture.occurrenceRepository.occurrences = [makePendingOccurrence(habitID: fixture.row.habitID, on: Date())]

        fixture.viewModel.loadIfNeeded()
        await waitUntil { fixture.viewModel.isLoading == false }

        guard let todayCell = fixture.viewModel.detailCalendarWeeks
            .flatMap(\.cells)
            .first(where: { Calendar.current.isDateInToday($0.date) }) else {
            XCTFail("Expected a today cell in the detail calendar")
            return
        }

        fixture.viewModel.mutateDay(todayCell)
        await waitUntil { fixture.viewModel.isSaving == false && fixture.viewModel.isLoading == false }

        XCTAssertEqual(fixture.readRepository.fetchDetailSummaryCallCount, 2)
        XCTAssertEqual(fixture.readRepository.fetchFilteredLibraryCallCount, 0)
        XCTAssertEqual(fixture.readRepository.fetchHistoryCallCount, 2)
        XCTAssertEqual(fixture.lifeAreaRepository.fetchAllCallCount, 0)
        XCTAssertEqual(fixture.projectRepository.fetchAllProjectsCallCount, 0)
        XCTAssertEqual(fixture.projectRepository.getTaskCountCallCount, 0)
    }

    func testMutateDayPublishesMutationFeedbackWithTargetState() async {
        let fixture = makeDetailFixture()
        fixture.occurrenceRepository.occurrences = [makePendingOccurrence(habitID: fixture.row.habitID, on: Date())]

        fixture.viewModel.loadIfNeeded()
        await waitUntil { fixture.viewModel.isLoading == false }

        guard let todayCell = fixture.viewModel.detailCalendarWeeks
            .flatMap(\.cells)
            .first(where: { Calendar.current.isDateInToday($0.date) }) else {
            XCTFail("Expected a today cell in the detail calendar")
            return
        }

        fixture.viewModel.mutateDay(todayCell)
        await waitUntil {
            fixture.viewModel.isSaving == false
                && fixture.viewModel.isLoading == false
                && fixture.viewModel.mutationFeedback != nil
        }

        let feedback = try! XCTUnwrap(fixture.viewModel.mutationFeedback)
        XCTAssertTrue(feedback.message.contains("Marked complete"))
        XCTAssertEqual(feedback.haptic, .success)

        fixture.viewModel.clearMutationFeedback()
        XCTAssertNil(fixture.viewModel.mutationFeedback)
    }

    func testSaveChangesRefreshesReadOnlyDataWithoutReloadingEditorSupport() async {
        let fixture = makeDetailFixture()

        fixture.viewModel.loadIfNeeded()
        await waitUntil { fixture.viewModel.isLoading == false }

        fixture.viewModel.beginEditing()
        await waitUntil { fixture.viewModel.isEditing }

        fixture.viewModel.draft.title = "Hydrate better"
        let editorLifeAreaFetchCount = fixture.lifeAreaRepository.fetchAllCallCount
        let editorProjectListFetchCount = fixture.projectRepository.fetchAllProjectsCallCount
        let editorProjectCountFetches = fixture.projectRepository.getTaskCountCallCount

        let expectation = expectation(description: "save completes")
        fixture.viewModel.saveChanges {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        await waitUntil { fixture.viewModel.isSaving == false && fixture.viewModel.isLoading == false && fixture.viewModel.isEditing == false }

        XCTAssertEqual(fixture.readRepository.fetchDetailSummaryCallCount, 2)
        XCTAssertEqual(fixture.readRepository.fetchFilteredLibraryCallCount, 0)
        XCTAssertEqual(fixture.readRepository.fetchHistoryCallCount, 2)
        XCTAssertEqual(fixture.lifeAreaRepository.fetchAllCallCount, editorLifeAreaFetchCount + 1)
        XCTAssertEqual(fixture.projectRepository.fetchAllProjectsCallCount, editorProjectListFetchCount)
        XCTAssertEqual(fixture.projectRepository.getTaskCountCallCount, editorProjectCountFetches)
    }

    private struct DetailFixture {
        let row: HabitLibraryRow
        let viewModel: HabitDetailViewModel
        let readRepository: DetailReadRepositorySpy
        let lifeAreaRepository: CountingLifeAreaRepository
        let projectRepository: CountingProjectRepository
        let occurrenceRepository: InMemoryOccurrenceRepository
    }

    private final class DetailReadRepositorySpy: HabitRuntimeReadRepositoryProtocol {
        var libraryRows: [HabitLibraryRow]
        var historyWindows: [HabitHistoryWindow]
        private(set) var fetchAllLibraryCallCount = 0
        private(set) var fetchFilteredLibraryCallCount = 0
        private(set) var fetchDetailSummaryCallCount = 0
        private(set) var fetchHistoryCallCount = 0

        init(libraryRows: [HabitLibraryRow], historyWindows: [HabitHistoryWindow]) {
            self.libraryRows = libraryRows
            self.historyWindows = historyWindows
        }

        func fetchAgendaHabits(
            for date: Date,
            completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
        ) {
            completion(.success([]))
        }

        func fetchHistory(
            habitIDs: [UUID],
            endingOn date: Date,
            dayCount: Int,
            completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
        ) {
            fetchHistoryCallCount += 1
            let requestedIDs = Set(habitIDs)
            completion(.success(historyWindows.filter { requestedIDs.contains($0.habitID) }))
        }

        func fetchSignals(
            start: Date,
            end: Date,
            completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
        ) {
            completion(.success([]))
        }

        func fetchHabitLibrary(
            includeArchived: Bool,
            completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
        ) {
            fetchAllLibraryCallCount += 1
            completion(.success(libraryRows))
        }

        func fetchHabitLibrary(
            habitIDs: [UUID]?,
            includeArchived: Bool,
            completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
        ) {
            fetchFilteredLibraryCallCount += 1
            guard let habitIDs, habitIDs.isEmpty == false else {
                completion(.success(libraryRows))
                return
            }
            let requestedIDs = Set(habitIDs)
            completion(.success(libraryRows.filter { requestedIDs.contains($0.habitID) }))
        }

        func fetchHabitDetailSummary(
            habitID: UUID,
            includeArchived: Bool,
            completion: @escaping (Result<HabitLibraryRow?, Error>) -> Void
        ) {
            fetchDetailSummaryCallCount += 1
            completion(.success(libraryRows.first(where: { $0.habitID == habitID })))
        }
    }

    private final class CountingLifeAreaRepository: LifeAreaRepositoryProtocol {
        let storedAreas: [LifeArea]
        private(set) var fetchAllCallCount = 0

        init(storedAreas: [LifeArea]) {
            self.storedAreas = storedAreas
        }

        func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
            fetchAllCallCount += 1
            completion(.success(storedAreas))
        }

        func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
            completion(.success(area))
        }

        func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
            completion(.success(area))
        }

        func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
            completion(.success(()))
        }
    }

    private final class CountingProjectRepository: ProjectRepositoryProtocol {
        private let projectsByID: [UUID: Project]
        private(set) var fetchAllProjectsCallCount = 0
        private(set) var getTaskCountCallCount = 0

        init(projects: [Project]) {
            self.projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        }

        var projectCount: Int { projectsByID.count }

        func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
            fetchAllProjectsCallCount += 1
            completion(.success(Array(projectsByID.values)))
        }

        func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
            completion(.success(projectsByID[id]))
        }

        func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
            completion(.success(projectsByID.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }))
        }

        func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
            completion(.success(Project.createInbox()))
        }

        func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
            completion(.success(Array(projectsByID.values)))
        }

        func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
            completion(.success(project))
        }

        func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
            completion(.success(Project.createInbox()))
        }

        func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
            completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
        }

        func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
            completion(.success(project))
        }

        func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
            if var project = projectsByID[id] {
                project.name = newName
                completion(.success(project))
            } else {
                completion(.failure(NSError(domain: "CountingProjectRepository", code: 404)))
            }
        }

        func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
            completion(.success(()))
        }

        func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
            getTaskCountCallCount += 1
            completion(.success(0))
        }

        func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
            completion(.success([]))
        }

        func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
            completion(.success(()))
        }

        func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
            completion(.success(true))
        }
    }

    private func makeDetailFixture(returnedTitle: String = "Hydrate") -> DetailFixture {
        let anchorDate = Date(timeIntervalSince1970: 1_711_036_800)
        let lifeAreaID = UUID()
        let projectID = UUID()
        let habitID = UUID()
        let project = Project(
            id: projectID,
            lifeAreaID: lifeAreaID,
            name: "Wellness",
            createdDate: anchorDate,
            modifiedDate: anchorDate,
            isArchived: false
        )
        let row = HabitLibraryRow(
            habitID: habitID,
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: lifeAreaID,
            lifeAreaName: "Health",
            projectID: projectID,
            projectName: project.name,
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
            colorHex: "#3B82F6",
            isPaused: false,
            isArchived: false,
            currentStreak: 3,
            bestStreak: 8,
            last14Days: [],
            reminderWindowStart: "08:00",
            reminderWindowEnd: "09:00",
            notes: "Stay consistent"
        )
        let refreshedRow = HabitLibraryRow(
            habitID: habitID,
            title: returnedTitle,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: lifeAreaID,
            lifeAreaName: "Health",
            projectID: projectID,
            projectName: project.name,
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
            colorHex: "#3B82F6",
            isPaused: false,
            isArchived: false,
            currentStreak: 3,
            bestStreak: 8,
            last14Days: [],
            reminderWindowStart: "08:00",
            reminderWindowEnd: "09:00",
            notes: "Stay consistent"
        )
        let historyWindow = HabitHistoryWindow(habitID: habitID, marks: [])
        let readRepository = DetailReadRepositorySpy(
            libraryRows: [refreshedRow],
            historyWindows: [historyWindow]
        )
        let lifeAreaRepository = CountingLifeAreaRepository(
            storedAreas: [LifeArea(id: lifeAreaID, name: "Health", createdAt: anchorDate, updatedAt: anchorDate)]
        )
        let projectRepository = CountingProjectRepository(projects: [project])
        let habitRepository = InMemoryHabitRepository(habits: [
            HabitDefinitionRecord(
                id: habitID,
                lifeAreaID: lifeAreaID,
                projectID: projectID,
                title: "Hydrate",
                habitType: "check_in",
                kindRaw: HabitKind.positive.rawValue,
                trackingModeRaw: HabitTrackingMode.dailyCheckIn.rawValue,
                iconSymbolName: "drop.fill",
                iconCategoryKey: "health",
                colorHex: "#3B82F6",
                notes: "Stay consistent",
                createdAt: anchorDate,
                updatedAt: anchorDate
            )
        ])
        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        let gamificationRepository = InMemoryGamificationEngineRepository()
        let gamificationEngine = GamificationEngine(repository: gamificationRepository)
        let recomputeHabitStreaksUseCase = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let schedulingEngine = RecordingSchedulingEngine(occurrenceRepository: occurrenceRepository)
        let maintainHabitRuntimeUseCase = MaintainHabitRuntimeUseCase(
            syncHabitScheduleUseCase: SyncHabitScheduleUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                scheduleEngine: schedulingEngine,
                occurrenceRepository: occurrenceRepository,
                recomputeHabitStreaksUseCase: recomputeHabitStreaksUseCase
            )
        )

        let viewModel = HabitDetailViewModel(
            row: row,
            getHabitLibraryUseCase: GetHabitLibraryUseCase(readRepository: readRepository),
            getHabitHistoryUseCase: GetHabitHistoryUseCase(readRepository: readRepository),
            updateHabitUseCase: UpdateHabitUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                scheduleEngine: schedulingEngine,
                projectRepository: projectRepository,
                lifeAreaRepository: lifeAreaRepository,
                maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
            ),
            pauseHabitUseCase: PauseHabitUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
            ),
            archiveHabitUseCase: ArchiveHabitUseCase(
                habitRepository: habitRepository,
                pauseHabitUseCase: PauseHabitUseCase(
                    habitRepository: habitRepository,
                    scheduleRepository: scheduleRepository,
                    maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
                ),
                maintainHabitRuntimeUseCase: maintainHabitRuntimeUseCase
            ),
            resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                occurrenceRepository: occurrenceRepository,
                scheduleEngine: schedulingEngine,
                recomputeHabitStreaksUseCase: recomputeHabitStreaksUseCase,
                gamificationEngine: gamificationEngine
            ),
            resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository,
                recomputeHabitStreaksUseCase: recomputeHabitStreaksUseCase,
                gamificationEngine: gamificationEngine
            ),
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: lifeAreaRepository),
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: projectRepository)
        )

        return DetailFixture(
            row: row,
            viewModel: viewModel,
            readRepository: readRepository,
            lifeAreaRepository: lifeAreaRepository,
            projectRepository: projectRepository,
            occurrenceRepository: occurrenceRepository
        )
    }

    private func makePendingOccurrence(habitID: UUID, on date: Date) -> OccurrenceDefinition {
        let templateID = UUID()
        let scheduledAt = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
        return OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: OccurrenceKeyCodec.encode(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: habitID
            ),
            scheduleTemplateID: templateID,
            sourceType: .habit,
            sourceID: habitID,
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: .pending,
            isGenerated: true,
            generationWindow: nil,
            createdAt: scheduledAt,
            updatedAt: scheduledAt
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        let pollInterval = Duration.nanoseconds(Int64(pollIntervalNanoseconds))

        while condition() == false {
            if ContinuousClock.now - start >= timeout {
                XCTFail("Timed out waiting for condition")
                return
            }
            try? await _Concurrency.Task.sleep(for: pollInterval)
        }
    }
}

final class DeleteHabitUseCaseCompensationTests: XCTestCase {
    func testDeleteHabitReturnsOriginalErrorWhenRestoreSucceeds() {
        let habitID = UUID()
        let templateID = UUID()
        let habit = HabitDefinitionRecord(
            id: habitID,
            lifeAreaID: UUID(),
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_711_036_800),
            updatedAt: Date(timeIntervalSince1970: 1_711_036_800)
        )
        let habitRepository = InMemoryHabitRepository(habits: [habit])
        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habitID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: Date(timeIntervalSince1970: 1_711_036_800),
                isActive: true,
                createdAt: Date(timeIntervalSince1970: 1_711_036_800),
                updatedAt: Date(timeIntervalSince1970: 1_711_036_800)
            )
        ]
        let templateDeleteError = NSError(domain: "InMemoryScheduleRepository", code: 501)
        scheduleRepository.deleteTemplateErrorsByID[templateID] = templateDeleteError
        let useCase = makeDeleteHabitUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository
        )

        let expectation = expectation(description: "delete habit returns original error")
        useCase.execute(id: habitID) { result in
            switch result {
            case .success:
                XCTFail("Expected delete failure")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 501)
                XCTAssertNotNil(habitRepository.habitsByID[habitID])
                XCTAssertEqual(scheduleRepository.templates.first?.id, templateID)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDeleteHabitReturnsCompensationErrorWhenRestoreFails() {
        let habitID = UUID()
        let templateID = UUID()
        let habit = HabitDefinitionRecord(
            id: habitID,
            lifeAreaID: UUID(),
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_711_036_800),
            updatedAt: Date(timeIntervalSince1970: 1_711_036_800)
        )
        let habitRepository = InMemoryHabitRepository(habits: [habit])
        habitRepository.createError = NSError(domain: "InMemoryHabitRepository", code: 502)
        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habitID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: Date(timeIntervalSince1970: 1_711_036_800),
                isActive: true,
                createdAt: Date(timeIntervalSince1970: 1_711_036_800),
                updatedAt: Date(timeIntervalSince1970: 1_711_036_800)
            )
        ]
        scheduleRepository.deleteTemplateErrorsByID[templateID] = NSError(domain: "InMemoryScheduleRepository", code: 501)
        let useCase = makeDeleteHabitUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository
        )

        let expectation = expectation(description: "delete habit returns compensation error")
        useCase.execute(id: habitID) { result in
            switch result {
            case .success:
                XCTFail("Expected delete failure")
            case .failure(let error):
                guard case let HabitDeleteCompensationError.restoreFailed(underlying, restoreError) = error else {
                    return XCTFail("Expected restoreFailed, got \(error)")
                }
                XCTAssertEqual((underlying as NSError).code, 501)
                XCTAssertEqual((restoreError as NSError).code, 502)
                XCTAssertNil(habitRepository.habitsByID[habitID])
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    private func makeDeleteHabitUseCase(
        habitRepository: InMemoryHabitRepository,
        scheduleRepository: InMemoryScheduleRepository
    ) -> DeleteHabitUseCase {
        let occurrenceRepository = InMemoryOccurrenceRepository()
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let engine = RecordingSchedulingEngine(occurrenceRepository: occurrenceRepository)
        let maintain = MaintainHabitRuntimeUseCase(
            syncHabitScheduleUseCase: SyncHabitScheduleUseCase(
                habitRepository: habitRepository,
                scheduleRepository: scheduleRepository,
                scheduleEngine: engine,
                occurrenceRepository: occurrenceRepository,
                recomputeHabitStreaksUseCase: recompute
            )
        )
        return DeleteHabitUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            maintainHabitRuntimeUseCase: maintain
        )
    }
}

@MainActor
final class DailyBriefServiceTests: XCTestCase {
    func testGenerateBriefUsesSingleCapturedReferenceDateForSignalResolution() async {
        let expectedReferenceDate = Date(timeIntervalSince1970: 1_711_583_140)
        var dateProviderCallCount = 0
        let repository = HabitRuntimeReadRepositorySpy(
            signalSummaries: [
                makeHabitSummary(
                    title: "Journal",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    dueAt: expectedReferenceDate.addingTimeInterval(-1_800),
                    state: .pending,
                    riskState: .stable
                )
            ]
        )
        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: nil,
            projectRepository: nil,
            lifeAreaRepository: nil,
            tagRepository: nil,
            habitRuntimeReadRepository: repository
        )
        defer {
            LLMContextRepositoryProvider.configure(
                taskReadModelRepository: nil,
                projectRepository: nil,
                lifeAreaRepository: nil,
                tagRepository: nil,
                habitRuntimeReadRepository: nil
            )
        }

        let service = DailyBriefService(
            llm: nil,
            dateProvider: {
                dateProviderCallCount += 1
                return expectedReferenceDate
            }
        )

        let brief = await service.generateBrief(
            todayOpenCount: 3,
            overdueCount: 1,
            completedTodayCount: 2,
            streak: 4
        )

        XCTAssertEqual(dateProviderCallCount, 1)
        XCTAssertEqual(repository.fetchSignalsCallCount, 1)
        XCTAssertEqual(repository.lastFetchSignalsStart, Calendar.current.startOfDay(for: expectedReferenceDate))
        XCTAssertEqual(
            repository.lastFetchSignalsEnd,
            Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: expectedReferenceDate))
        )
        XCTAssertTrue(brief.contains("• Habits due: 1"))
    }
}

final class BuildHomeAgendaUseCaseOrderingTests: XCTestCase {
    func testAgendaOrdersOverdueBeforeDueAndPreservesMixedRows() {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_711_209_600))
        let overdueTask = TaskDefinition(
            id: UUID(),
            projectID: ProjectConstants.inboxProjectID,
            projectName: ProjectConstants.inboxProjectName,
            title: "Overdue task",
            dueDate: calendar.date(byAdding: .day, value: -1, to: anchorDate),
            isComplete: false
        )
        let dueTask = TaskDefinition(
            id: UUID(),
            projectID: ProjectConstants.inboxProjectID,
            projectName: ProjectConstants.inboxProjectName,
            title: "Later task",
            dueDate: calendar.date(byAdding: .hour, value: 10, to: anchorDate),
            isComplete: false
        )
        let dueHabit = HomeHabitRow(
            habitID: UUID(),
            title: "Journal",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Mind",
            iconSymbolName: "book.closed",
            dueAt: calendar.date(byAdding: .hour, value: 8, to: anchorDate),
            state: .due
        )
        let skippedHabit = HomeHabitRow(
            habitID: UUID(),
            title: "Skip coffee",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            iconSymbolName: "cup.and.saucer",
            dueAt: calendar.date(byAdding: .hour, value: 12, to: anchorDate),
            state: .skippedToday
        )

        let result = BuildHomeAgendaUseCase().execute(
            date: anchorDate,
            taskRows: [dueTask, overdueTask],
            habitRows: [skippedHabit, dueHabit]
        )

        XCTAssertEqual(result.taskCount, 2)
        XCTAssertEqual(result.habitCount, 2)
        XCTAssertEqual(result.rows.count, 4)
        XCTAssertEqual(result.rows[0], .task(overdueTask))
        XCTAssertEqual(result.rows[1], .habit(dueHabit))
        XCTAssertEqual(result.rows[2], .task(dueTask))
        XCTAssertEqual(result.rows[3], .habit(skippedHabit))
    }
}

final class HabitRuntimeMigrationFlagTests: XCTestCase {
    func testRepairFlagRoundTripClearsPendingRepair() {
        let suiteName = "tasker.habit.runtime.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "tasker.habit.runtime.repair_required.v1")
        defaults.set(false, forKey: "tasker.habit.runtime.repair_completed.v1")

        XCTAssertTrue(TaskerPersistentRuntimeInitializer.shouldRunRepair(defaults: defaults))

        TaskerPersistentRuntimeInitializer.markRepairCompleted(defaults: defaults)

        XCTAssertFalse(TaskerPersistentRuntimeInitializer.shouldRunRepair(defaults: defaults))
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private func makeHabitSummary(
    habitID: UUID = UUID(),
    title: String,
    kind: HabitKind,
    trackingMode: HabitTrackingMode,
    dueAt: Date?,
    state: OccurrenceState,
    riskState: HabitRiskState
) -> HabitOccurrenceSummary {
    HabitOccurrenceSummary(
        habitID: habitID,
        occurrenceID: UUID(),
        title: title,
        kind: kind,
        trackingMode: trackingMode,
        lifeAreaID: UUID(),
        lifeAreaName: "Health",
        projectID: nil,
        projectName: nil,
        icon: HabitIconMetadata(symbolName: "heart", categoryKey: "health"),
        dueAt: dueAt,
        state: state,
        currentStreak: 3,
        bestStreak: 5,
        riskState: riskState,
        last14Days: []
    )
}

private final class InMemoryHabitRepository: HabitRepositoryProtocol {
    private(set) var habitsByID: [UUID: HabitDefinitionRecord]
    private(set) var createCallCount = 0
    var deferCreateCompletion = false
    var createError: Error?
    private var pendingCreateCompletions: [(Result<HabitDefinitionRecord, Error>) -> Void] = []

    init(habits: [HabitDefinitionRecord] = []) {
        self.habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
    }

    convenience init(seed: [HabitDefinitionRecord] = []) {
        self.init(habits: seed)
    }

    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) {
        completion(.success(Array(habitsByID.values)))
    }

    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        createCallCount += 1
        if let createError {
            completion(.failure(createError))
            return
        }
        habitsByID[habit.id] = habit
        if deferCreateCompletion {
            pendingCreateCompletions.append(completion)
            return
        }
        completion(.success(habit))
    }

    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        habitsByID[habit.id] = habit
        completion(.success(habit))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        habitsByID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class RecordingSchedulingEngine: SchedulingEngineProtocol {
    struct ResolveCall: Equatable {
        let id: UUID
        let resolution: OccurrenceResolutionType
        let actor: OccurrenceActor
    }

    private let occurrenceRepository: InMemoryOccurrenceRepository?
    private let generatedOccurrences: [OccurrenceDefinition]
    private(set) var generateSourceFilters: [ScheduleSourceType?] = []
    private(set) var resolvedOccurrences: [ResolveCall] = []
    private(set) var rebuildTemplateIDs: [UUID] = []

    init(
        occurrenceRepository: InMemoryOccurrenceRepository? = nil,
        generatedOccurrences: [OccurrenceDefinition] = []
    ) {
        self.occurrenceRepository = occurrenceRepository
        self.generatedOccurrences = generatedOccurrences
    }

    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void
    ) {
        generateSourceFilters.append(sourceFilter)
        if let occurrenceRepository, generatedOccurrences.isEmpty == false {
            occurrenceRepository.saveOccurrences(generatedOccurrences) { _ in
                completion(.success(self.generatedOccurrences))
            }
            return
        }
        completion(.success(generatedOccurrences))
    }

    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        resolvedOccurrences.append(ResolveCall(id: id, resolution: resolution, actor: actor))
        guard let occurrenceRepository else {
            completion(.success(()))
            return
        }
        occurrenceRepository.resolve(
            OccurrenceResolutionDefinition(
                id: UUID(),
                occurrenceID: id,
                resolutionType: resolution,
                resolvedAt: Date(),
                actor: actor.rawValue,
                reason: nil,
                createdAt: Date()
            ),
            completion: completion
        )
    }

    func rebuildFutureOccurrences(
        templateID: UUID,
        effectiveFrom: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        rebuildTemplateIDs.append(templateID)
        completion(.success(()))
    }

    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }
}

private final class HabitRuntimeReadRepositorySpy: HabitRuntimeReadRepositoryProtocol {
    var agendaSummaries: [HabitOccurrenceSummary]
    var historyWindows: [HabitHistoryWindow]
    var signalSummaries: [HabitOccurrenceSummary]
    var libraryRows: [HabitLibraryRow]
    private(set) var fetchAgendaCallCount = 0
    private(set) var fetchHistoryCallCount = 0
    private(set) var fetchSignalsCallCount = 0
    private(set) var fetchHabitLibraryCallCount = 0
    private(set) var lastFetchSignalsStart: Date?
    private(set) var lastFetchSignalsEnd: Date?

    init(
        agendaSummaries: [HabitOccurrenceSummary] = [],
        historyWindows: [HabitHistoryWindow] = [],
        signalSummaries: [HabitOccurrenceSummary] = [],
        libraryRows: [HabitLibraryRow] = []
    ) {
        self.agendaSummaries = agendaSummaries
        self.historyWindows = historyWindows
        self.signalSummaries = signalSummaries
        self.libraryRows = libraryRows
    }

    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        fetchAgendaCallCount += 1
        completion(.success(agendaSummaries))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        fetchHistoryCallCount += 1
        completion(.success(historyWindows))
    }

    func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        fetchSignalsCallCount += 1
        lastFetchSignalsStart = start
        lastFetchSignalsEnd = end
        completion(.success(signalSummaries))
    }

    func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchHabitLibraryCallCount += 1
        completion(.success(libraryRows))
    }
}


// MARK: - Daily Reflection Tests

import XCTest
@testable import To_Do_List

final class DailyReflectionUseCasesTests: XCTestCase {
    func testResolveTargetReturnsSameDayWhenYesterdayIsComplete() throws {
        let defaults = UserDefaults(suiteName: "DailyReflectionUseCasesTests.sameDay")!
        defaults.removePersistentDomain(forName: "DailyReflectionUseCasesTests.sameDay")
        let store = UserDefaultsDailyReflectionStore(defaults: defaults)
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        try store.markCompleted(on: yesterday, completedAt: yesterday, payload: nil)

        let useCase = ResolveDailyReflectionTargetUseCase(
            reflectionStore: store,
            nowProvider: { today }
        )

        let target = useCase.execute()

        XCTAssertEqual(target?.mode, .sameDay)
        XCTAssertEqual(target?.reflectionDate, today)
        XCTAssertEqual(target?.planningDate, calendar.date(byAdding: .day, value: 1, to: today))
    }

    func testResolveTargetReturnsCatchUpWhenYesterdayIsIncomplete() {
        let defaults = UserDefaults(suiteName: "DailyReflectionUseCasesTests.catchUp")!
        defaults.removePersistentDomain(forName: "DailyReflectionUseCasesTests.catchUp")
        let store = UserDefaultsDailyReflectionStore(defaults: defaults)
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let useCase = ResolveDailyReflectionTargetUseCase(
            reflectionStore: store,
            nowProvider: { today }
        )

        let target = useCase.execute()

        XCTAssertEqual(target?.mode, .catchUpYesterday)
        XCTAssertEqual(target?.reflectionDate, yesterday)
        XCTAssertEqual(target?.planningDate, today)
    }

    func testStoreKeepsLegacyCompletionKeysReadable() {
        let suiteName = "DailyReflectionUseCasesTests.legacy"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(["20260418"], forKey: UserDefaultsDailyReflectionStore.legacyCompletionDefaultsKey)

        let store = UserDefaultsDailyReflectionStore(defaults: defaults)

        XCTAssertTrue(store.completedDateStamps().contains("20260418"))
    }

    func testPlanSuggestionPrefersCarryoverAndAvoidsDuplicates() {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        let carryover = TaskDefinition(title: "Carryover", priority: .max, dueDate: planningDate)
        let due = TaskDefinition(title: "Due today", priority: .high, dueDate: planningDate)
        let stabilizer = TaskDefinition(title: "Stabilizer", priority: .none, dueDate: planningDate)

        let useCase = BuildNextDayPlanSuggestionUseCase(calendarEventsProvider: nil)
        let expectation = expectation(description: "plan suggestion")

        useCase.execute(
            planningDate: planningDate,
            carryoverTasks: [carryover],
            planningDateTasks: [carryover, due, stabilizer],
            atRiskHabit: nil
        ) { result in
            let suggestion = try? result.get()
            XCTAssertEqual(suggestion?.topTasks.first?.title, "Carryover")
            XCTAssertEqual(Set(suggestion?.topTasks.map(\.id) ?? []).count, suggestion?.topTasks.count)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadCoordinatorBuildsCompactRecapContent() async throws {
        let calendar = Calendar.autoupdatingCurrent
        let reflectionDate = calendar.startOfDay(for: Date())
        let planningDate = calendar.date(byAdding: .day, value: 1, to: reflectionDate)!
        let tasks = [
            TaskDefinition(
                title: "Beta polish",
                priority: .high,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: true,
                dateCompleted: reflectionDate.addingTimeInterval(60)
            ),
            TaskDefinition(
                title: "Alpha closeout",
                priority: .high,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: true,
                dateCompleted: reflectionDate.addingTimeInterval(120)
            ),
            TaskDefinition(
                title: "Top priority fix",
                priority: .max,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: true,
                dateCompleted: reflectionDate.addingTimeInterval(180)
            ),
            TaskDefinition(
                title: "Low priority cleanup",
                priority: .low,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: true,
                dateCompleted: reflectionDate.addingTimeInterval(240)
            ),
            TaskDefinition(
                title: "Carryover open",
                priority: .high,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: false
            )
        ]

        let habits = [
            HabitOccurrenceSummary(
                habitID: UUID(),
                occurrenceID: UUID(),
                title: "Stretch",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(),
                lifeAreaName: "Health",
                colorHex: "#4A86E8",
                state: .missed,
                currentStreak: 2,
                riskState: .broken,
                last14Days: makeReflectionMarks(endingOn: reflectionDate, lastSevenStates: [.failure, .success, .success, .success, .failure, .success, .failure])
            ),
            HabitOccurrenceSummary(
                habitID: UUID(),
                occurrenceID: UUID(),
                title: "Walk",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(),
                lifeAreaName: "Health",
                colorHex: "#4E9A2F",
                state: .skipped,
                currentStreak: 5,
                riskState: .atRisk,
                last14Days: makeReflectionMarks(endingOn: reflectionDate, lastSevenStates: [.success, .success, .skipped, .success, .success, .success, .skipped])
            ),
            HabitOccurrenceSummary(
                habitID: UUID(),
                occurrenceID: UUID(),
                title: "Read",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(),
                lifeAreaName: "Learning",
                colorHex: "#8A46B5",
                state: .completed,
                currentStreak: 7,
                riskState: .stable,
                last14Days: makeReflectionMarks(endingOn: reflectionDate, lastSevenStates: [.success, .success, .success, .success, .success, .success, .success])
            ),
            HabitOccurrenceSummary(
                habitID: UUID(),
                occurrenceID: UUID(),
                title: "Water",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(),
                lifeAreaName: "Health",
                colorHex: "#5AA7A4",
                state: .completed,
                currentStreak: 9,
                riskState: .stable,
                last14Days: makeReflectionMarks(endingOn: reflectionDate, lastSevenStates: [.success, .success, .success, .success, .success, .success, .success])
            ),
            HabitOccurrenceSummary(
                habitID: UUID(),
                occurrenceID: UUID(),
                title: "Journal",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(),
                lifeAreaName: "Mind",
                colorHex: "#F5B23C",
                state: .completed,
                currentStreak: 3,
                riskState: .stable,
                last14Days: makeReflectionMarks(endingOn: reflectionDate, lastSevenStates: [.success, .success, .success, .success, .success, .success, .success])
            )
        ]

        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(seed: tasks),
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(tasks: tasks),
            projectRepository: MockProjectRepository(projects: [Project.createInbox()]),
            habitRuntimeReadRepository: CapturingHabitRuntimeReadRepository(agendaSummaries: habits)
        )

        let bundle = try await coordinator.dailyReflectionLoadCoordinator.loadCore(
            target: DailyReflectionTarget(
                mode: .sameDay,
                reflectionDate: reflectionDate,
                planningDate: planningDate
            )
        )

        XCTAssertEqual(bundle.coreSnapshot.closedTasks.map(\.title), [
            "Top priority fix",
            "Alpha closeout",
            "Beta polish"
        ])
        XCTAssertEqual(bundle.coreSnapshot.habitGrid.map(\.title), [
            "Stretch",
            "Walk",
            "Water",
            "Read"
        ])
        XCTAssertEqual(bundle.coreSnapshot.habitGrid.first?.colorFamily, .blue)
        XCTAssertEqual(bundle.coreSnapshot.habitGrid.first?.last7Days.count, 7)
        XCTAssertEqual(
            bundle.coreSnapshot.narrativeSummary.planCardLine,
            "You closed 4 tasks, kept 3 habit streaks alive, and missed Stretch and Walk."
        )
        XCTAssertEqual(
            bundle.coreSnapshot.narrativeSummary.homeCardLine,
            "4 tasks closed, 3 habits kept, missed Stretch and Walk."
        )
    }

    func testNarrativeSummaryHandlesNoMissesAndOverflow() {
        let calm = ReflectionNarrativeSummary.make(
            completedCount: 1,
            keptCount: 2,
            missedTitles: []
        )
        XCTAssertEqual(
            calm.planCardLine,
            "You closed 1 task and kept 2 habit streaks alive, so tomorrow can stay narrow."
        )
        XCTAssertEqual(
            calm.homeCardLine,
            "1 task closed, 2 habits kept. Keep tomorrow tight."
        )

        let overflow = ReflectionNarrativeSummary.make(
            completedCount: 3,
            keptCount: 1,
            missedTitles: ["Water", "Walk", "Read"]
        )
        XCTAssertEqual(
            overflow.planCardLine,
            "You closed 3 tasks, kept 1 habit streak alive, and missed Water, Walk, and 1 more."
        )
    }

    func testCalendarContextSkipsInvalidPreHardStopWindows() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "first",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "First block",
                    startDate: planningDate,
                    endDate: planningDate.addingTimeInterval(30 * 60),
                    isAllDay: false
                ),
                TaskerCalendarEventSnapshot(
                    id: "second",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Later block",
                    startDate: planningDate.addingTimeInterval(4 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(5 * 60 * 60),
                    isAllDay: false
                )
            ]
        )
        let useCase = BuildNextDayPlanSuggestionUseCase(calendarEventsProvider: provider, calendar: calendar)

        let result = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)

        XCTAssertEqual(result.status, .loaded)
        XCTAssertNotNil(result.context?.bestFocusWindow)
        XCTAssertGreaterThanOrEqual(result.context?.bestFocusWindow?.start ?? .distantPast, planningDate.addingTimeInterval(30 * 60))
    }

    func testCalendarContextBuildsOffMainWhenProviderCompletesOnMain() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = MainQueueCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "main_queue_event",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Main queue callback",
                    startDate: planningDate.addingTimeInterval(9 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(10 * 60 * 60),
                    isAllDay: false
                )
            ]
        )
        let useCase = BuildNextDayPlanSuggestionUseCase(calendarEventsProvider: provider, calendar: calendar)

        let result = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)

        XCTAssertEqual(result.status, .loaded)
        XCTAssertNotNil(result.context)
        XCTAssertEqual(result.context?.eventCount, 1)
    }

    func testCalendarContextTimeoutReturnsDegradedPlanState() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(
            events: [],
            delayNanoseconds: 1_000_000_000
        )
        let useCase = BuildNextDayPlanSuggestionUseCase(calendarEventsProvider: provider, calendar: calendar)

        let result = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 0.05)

        XCTAssertNil(result.context)
        XCTAssertEqual(
            result.status,
            .degraded("Calendar context timed out. Suggestions use tasks and habits only.")
        )
    }

    func testCalendarContextUsesSelectedCalendarIDsFromWorkspacePreferences() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(events: [])
        let suiteName = "DailyReflectionUseCasesTests.workspace.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["work", "personal"]))

        let useCase = BuildNextDayPlanSuggestionUseCase(
            calendarEventsProvider: provider,
            calendar: calendar,
            workspacePreferencesStore: workspaceStore
        )

        _ = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)

        XCTAssertEqual(provider.lastRequestedCalendarIDs, Set(["work", "personal"]))
    }

    func testCalendarContextSkipsFetchWhenNoCalendarsAreSelected() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "should-not-fetch",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Hidden",
                    startDate: planningDate.addingTimeInterval(9 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(10 * 60 * 60),
                    isAllDay: false
                )
            ]
        )
        let suiteName = "DailyReflectionUseCasesTests.workspace.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.save(TaskerWorkspacePreferences(selectedCalendarIDs: []))

        let useCase = BuildNextDayPlanSuggestionUseCase(
            calendarEventsProvider: provider,
            calendar: calendar,
            workspacePreferencesStore: workspaceStore
        )

        let result = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)
        XCTAssertNil(result.context)
        XCTAssertEqual(
            result.status,
            .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
        )
        XCTAssertEqual(provider.fetchEventsCallCount, 0)

        let lookup = await useCase.loadCachedOrStaleCalendarContext(for: planningDate)
        if case .miss = lookup {
            // expected
        } else {
            XCTFail("Expected cache miss when no calendars are selected")
        }
    }

    func testCachedCalendarContextFreshHitReturnsWithoutProviderFetch() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "cache-fresh",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Focus",
                    startDate: planningDate.addingTimeInterval(9 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(10 * 60 * 60),
                    isAllDay: false
                )
            ]
        )
        var now = Date()
        let useCase = BuildNextDayPlanSuggestionUseCase(
            calendarEventsProvider: provider,
            calendar: calendar,
            nowProvider: { now }
        )

        _ = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)
        XCTAssertEqual(provider.fetchEventsCallCount, 1)

        let lookup = await useCase.loadCachedOrStaleCalendarContext(for: planningDate)
        switch lookup {
        case .fresh(let context):
            XCTAssertEqual(context.eventCount, 1)
        default:
            XCTFail("Expected fresh cached context")
        }
        XCTAssertEqual(provider.fetchEventsCallCount, 1)
    }

    func testCachedCalendarContextStaleHitIsReported() async {
        let calendar = Calendar.autoupdatingCurrent
        let planningDate = calendar.startOfDay(for: Date())
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let provider = DelayedCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "cache-stale",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Standup",
                    startDate: planningDate.addingTimeInterval(8 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(9 * 60 * 60),
                    isAllDay: false
                )
            ]
        )
        var now = Date()
        let useCase = BuildNextDayPlanSuggestionUseCase(
            calendarEventsProvider: provider,
            calendar: calendar,
            nowProvider: { now }
        )

        _ = await useCase.loadCalendarContext(for: planningDate, timeoutSeconds: 1.0)
        XCTAssertEqual(provider.fetchEventsCallCount, 1)

        now = now.addingTimeInterval(31 * 60)
        let lookup = await useCase.loadCachedOrStaleCalendarContext(for: planningDate)
        switch lookup {
        case .stale(let context):
            XCTAssertEqual(context.eventCount, 1)
        default:
            XCTFail("Expected stale cached context")
        }
        XCTAssertEqual(provider.fetchEventsCallCount, 1)
    }

    func testSaveUseCasePreservesManualDraftByDefault() throws {
        let suiteName = "DailyReflectionUseCasesTests.save"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsDailyReflectionStore(defaults: defaults)
        let gamificationRepository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: gamificationRepository)
        let markUseCase = MarkDailyReflectionCompleteUseCase(engine: engine, reflectionStore: store)
        let saveUseCase = SaveDailyReflectionAndPlanUseCase(
            reflectionStore: store,
            markDailyReflection: markUseCase
        )

        let calendar = Calendar.autoupdatingCurrent
        let reflectionDate = calendar.startOfDay(for: Date())
        let planningDate = calendar.date(byAdding: .day, value: 1, to: reflectionDate)!
        let manualDraft = DailyPlanDraft(
            date: planningDate,
            topTasks: [DailyPlanTaskOption(id: UUID(), title: "Manual plan", priority: .high)],
            source: .manual
        )
        try store.savePlanDraft(manualDraft, replaceExisting: true)

        let snapshot = DailyReflectionSnapshot(
            reflectionDate: reflectionDate,
            planningDate: planningDate,
            mode: .sameDay,
            pulseNote: "Pulse",
            biggestWins: [],
            tasksSummary: TaskReflectionSummary(completedCount: 1, scheduledCount: 2, carryOverCount: 0, overdueOpenCount: 0),
            habitsSummary: nil,
            calendarSummary: nil,
            suggestedPlan: DailyPlanSuggestion(topTasks: [DailyPlanTaskOption(id: UUID(), title: "Suggested", priority: .high)])
        )
        let editablePlan = EditableDailyPlan(planningDate: planningDate, suggestion: snapshot.suggestedPlan)
        let expectation = expectation(description: "save reflection")

        saveUseCase.execute(
            snapshot: snapshot,
            input: DailyReflectionInput(mood: .good),
            plan: editablePlan
        ) { result in
            let saveResult = try? result.get()
            XCTAssertEqual(saveResult?.preservedExistingManualDraft, true)
            XCTAssertEqual(store.fetchPlanDraft(on: planningDate)?.source, .manual)
            XCTAssertTrue(store.isCompleted(on: reflectionDate))
            XCTAssertEqual(store.fetchReflectionPayload(on: reflectionDate)?.mood, .good)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor
    func testDailyReflectPlanViewModelPublishesCoreBeforeOptionalContextFinishes() async {
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let calendar = Calendar.autoupdatingCurrent
        let reflectionDate = calendar.startOfDay(for: Date())
        let planningDate = calendar.date(byAdding: .day, value: 1, to: reflectionDate)!
        let tasks = [
            TaskDefinition(
                title: "Carryover",
                priority: .max,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: false
            ),
            TaskDefinition(
                title: "Finished",
                priority: .high,
                type: .morning,
                dueDate: reflectionDate,
                isComplete: true,
                dateCompleted: reflectionDate.addingTimeInterval(60 * 60)
            ),
            TaskDefinition(
                title: "Tomorrow due",
                priority: .high,
                type: .morning,
                dueDate: planningDate,
                isComplete: false
            )
        ]
        let projectRepository = MockProjectRepository(projects: [Project.createInbox()])
        let taskRepository = InMemoryTaskDefinitionRepositoryStub(seed: tasks)
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: tasks)
        let calendarProvider = DelayedCalendarEventsProviderStub(
            events: [],
            delayNanoseconds: 5_000_000_000
        )
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: taskRepository,
            taskReadModelRepository: readModel,
            projectRepository: projectRepository,
            habitRuntimeReadRepository: CapturingHabitRuntimeReadRepository(),
            calendarEventsProvider: calendarProvider
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: reflectionDate) ?? reflectionDate
        XCTAssertNoThrow(
            try coordinator.dailyReflectionStore.markCompleted(
                on: yesterday,
                completedAt: reflectionDate,
                payload: nil as ReflectionPayload?
            )
        )
        let viewModel = DailyReflectPlanViewModel(useCaseCoordinator: coordinator, calendar: calendar)

        let baselineLoaded = await waitForCondition(timeout: 1.0) {
            viewModel.loadState == DailyReflectionLoadState.fullyLoaded
                && viewModel.coreSnapshot != nil
                && viewModel.editablePlan != nil
                && viewModel.snapshot != nil
                && viewModel.optionalContext?.status == .loading
        }
        XCTAssertTrue(baselineLoaded)

        let timedOut = await waitForCondition(timeout: 2.0) {
            if case .some(.degraded(_)) = viewModel.optionalContext?.status {
                return true
            }
            return false
        }
        XCTAssertTrue(timedOut)
        XCTAssertEqual(viewModel.coreSnapshot?.closedTasks.map(\.title), ["Finished"])
        XCTAssertEqual(viewModel.coreSnapshot?.habitGrid.count, 0)
        XCTAssertEqual(
            viewModel.coreSnapshot?.narrativeSummary.planCardLine,
            "You closed 1 task, and tomorrow can stay narrow."
        )
        XCTAssertEqual(
            viewModel.optionalContext?.status,
            .degraded("Calendar context timed out. Suggestions use tasks and habits only.")
        )
    }

    @MainActor
    func testDailyReflectPlanViewModelPreservesSwappedTasksAfterCalendarEnrichment() async {
        await ReflectionCalendarContextCacheStore.shared.clearAll()
        let calendar = Calendar.autoupdatingCurrent
        let reflectionDate = calendar.startOfDay(for: Date())
        let planningDate = calendar.date(byAdding: .day, value: 1, to: reflectionDate)!
        let tasks = [
            TaskDefinition(title: "Task A", priority: .max, type: .morning, dueDate: reflectionDate, isComplete: false),
            TaskDefinition(title: "Task B", priority: .high, type: .morning, dueDate: reflectionDate, isComplete: false),
            TaskDefinition(title: "Task C", priority: .low, type: .morning, dueDate: planningDate, isComplete: false),
            TaskDefinition(title: "Task D", priority: .low, type: .morning, dueDate: planningDate, isComplete: false),
            TaskDefinition(title: "Task E", priority: .high, type: .morning, dueDate: planningDate, isComplete: false)
        ]
        let provider = DelayedCalendarEventsProviderStub(
            events: [
                TaskerCalendarEventSnapshot(
                    id: "meeting",
                    calendarID: "calendar",
                    calendarTitle: "Primary",
                    title: "Team meeting",
                    startDate: planningDate.addingTimeInterval(10 * 60 * 60),
                    endDate: planningDate.addingTimeInterval(11 * 60 * 60),
                    isAllDay: false
                )
            ],
            delayNanoseconds: 150_000_000
        )
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(seed: tasks),
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(tasks: tasks),
            projectRepository: MockProjectRepository(projects: [Project.createInbox()]),
            habitRuntimeReadRepository: CapturingHabitRuntimeReadRepository(),
            calendarEventsProvider: provider
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: reflectionDate) ?? reflectionDate
        XCTAssertNoThrow(
            try coordinator.dailyReflectionStore.markCompleted(
                on: yesterday,
                completedAt: reflectionDate,
                payload: nil as ReflectionPayload?
            )
        )

        let viewModel = DailyReflectPlanViewModel(useCaseCoordinator: coordinator, calendar: calendar)

        let baselineLoaded = await waitForCondition(timeout: 1.0) {
            viewModel.loadState == DailyReflectionLoadState.fullyLoaded
                && viewModel.editablePlan != nil
                && viewModel.optionalContext?.status == .loading
        }
        XCTAssertTrue(baselineLoaded)

        guard let swapOption = viewModel.swapOptions(for: 0).first else {
            XCTFail("Expected at least one swap option in baseline plan")
            return
        }

        viewModel.swapTask(slotIndex: 0, with: swapOption)
        XCTAssertEqual(viewModel.editablePlan?.topTasks.first?.id, swapOption.id)

        let enrichmentLoaded = await waitForCondition(timeout: 2.0) {
            viewModel.optionalContext?.status == .loaded
        }
        XCTAssertTrue(enrichmentLoaded)
        XCTAssertEqual(viewModel.editablePlan?.topTasks.first?.id, swapOption.id)
        XCTAssertEqual(
            viewModel.editablePlan?.focusWindow,
            viewModel.optionalContext?.suggestedPlan.focusWindow
        )
    }

    @MainActor
    private func waitForCondition(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.05,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
        let pollNanoseconds = UInt64(max(0.01, pollInterval) * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if condition() {
                return true
            }
            try? await _Concurrency.Task.sleep(nanoseconds: pollNanoseconds)
        }

        return condition()
    }
}

private func makeReflectionMarks(
    endingOn date: Date,
    lastSevenStates: [HabitDayState]
) -> [HabitDayMark] {
    let calendar = Calendar.autoupdatingCurrent
    return lastSevenStates.enumerated().compactMap { index, state in
        guard let day = calendar.date(byAdding: .day, value: index - (lastSevenStates.count - 1), to: date) else {
            return nil
        }
        return HabitDayMark(date: day, state: state)
    }
}

private final class InMemoryGamificationRepositoryStub: GamificationRepositoryProtocol {
    private var profile = GamificationSnapshot()
    private var xpEvents: [XPEventDefinition] = []
    private var dailyAggregates: [String: DailyXPAggregateDefinition] = [:]

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        completion(.success(profile))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        self.profile = profile
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success(xpEvents))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success(xpEvents.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        xpEvents.append(event)
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(xpEvents.contains(where: { $0.idempotencyKey == idempotencyKey })))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        completion(.success(dailyAggregates[dateKey]))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        dailyAggregates[aggregate.dateKey] = aggregate
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        completion(.success(dailyAggregates.values.filter { $0.dateKey >= startDateKey && $0.dateKey <= endDateKey }))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        completion(.success([]))
    }
}

private final class DelayedCalendarEventsProviderStub: CalendarEventsProviderProtocol {
    private let events: [TaskerCalendarEventSnapshot]
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _fetchEventsCallCount = 0
    private var _lastRequestedCalendarIDs: Set<String> = []

    init(events: [TaskerCalendarEventSnapshot], delayNanoseconds: UInt64 = 0) {
        self.events = events
        self.delayNanoseconds = delayNanoseconds
    }

    var fetchEventsCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _fetchEventsCallCount
    }

    var lastRequestedCalendarIDs: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return _lastRequestedCalendarIDs
    }

    func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        .authorized
    }

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func resetStoreStateAfterPermissionChange() {}

    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchEvents(
        startDate _: Date,
        endDate _: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        lock.lock()
        _fetchEventsCallCount += 1
        _lastRequestedCalendarIDs = calendarIDs
        lock.unlock()
        _Concurrency.Task {
            if delayNanoseconds > 0 {
                try? await _Concurrency.Task.sleep(nanoseconds: delayNanoseconds)
            }
            completion(.success(events))
        }
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }
}

private final class MainQueueCalendarEventsProviderStub: CalendarEventsProviderProtocol {
    private let events: [TaskerCalendarEventSnapshot]

    init(events: [TaskerCalendarEventSnapshot]) {
        self.events = events
    }

    func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        .authorized
    }

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func resetStoreStateAfterPermissionChange() {}

    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        DispatchQueue.main.async {
            completion(.success([]))
        }
    }

    func fetchEvents(
        startDate _: Date,
        endDate _: Date,
        calendarIDs _: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(.success(self.events))
        }
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }
}
