import UIKit

// Launch-time pieces of the scene: the bootstrap-failure root and the day-loop
// UI-test seed. Split out of SceneDelegate.swift for the file-size ratchet;
// behaviour is unchanged.
extension SceneDelegate {
    /// Executes showBootstrapFailureRoot.
    func showBootstrapFailureRoot(message: String) {
        let failureViewController = BootstrapFailureViewController(
            message: message,
            onRetrySync: { [weak self] in
                self?.performBootstrapFailureAction(.retrySync)
            },
            onRecoverFromICloud: { [weak self] in
                self?.performBootstrapFailureAction(.recoverFromICloud)
            }
        )
        window?.rootViewController = failureViewController
        window?.makeKeyAndVisible()
    }

    func performBootstrapFailureAction(_ action: BootstrapFailureAction) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let mode: LaunchRootMode
        switch action {
        case .retrySync:
            mode = appDelegate.retryPersistentStoreBootstrap()
        case .recoverFromICloud:
            mode = appDelegate.recoverFromCloudAuthoritativeReset()
        }

        renderRoot(for: mode)
        if case .bootstrapFailure(let message) = mode,
           let failureVC = window?.rootViewController as? BootstrapFailureViewController {
            failureVC.setWorking(false, hint: message)
        }
    }

    /// Commits three known tasks to a day so the day-loop rituals have a deck.
    ///
    /// `-LIFEBOARD_TEST_SEED_DAY_CLOSE` commits them to today, which is what the
    /// evening ritual reconciles. `-LIFEBOARD_TEST_SEED_DAY_OPEN` commits them to
    /// yesterday, because `DayCloseStore` in `.open` mode reads a distinct
    /// `retrospectiveDay` — seeding today leaves the morning surface empty.
    ///
    /// This creates its own tasks. It previously wrote planning metadata over
    /// whatever another seeder had already made and returned silently when it
    /// found none, so it produced an empty deck unless it happened to be paired
    /// with a workspace seed — and `-LIFEBOARD_TEST_SEED_DAY_CLOSE` is not a
    /// case `HomeUITestWorkspaceSeeder` recognises, so pairing it did not help.
    /// Owning the rows also makes the must-do-first ordering deterministic
    /// instead of depending on which task `fetchAll` returned first.
    static func seedDayLoopRitualsIfNeeded(
        planning: CoreDataPlanningRepository,
        tasks: any TaskDefinitionRepositoryProtocol,
        completion: @escaping () -> Void
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let seedsClose = arguments.contains("-LIFEBOARD_TEST_SEED_DAY_CLOSE")
        let seedsOpen = arguments.contains("-LIFEBOARD_TEST_SEED_DAY_OPEN")
        guard seedsClose || seedsOpen else {
            completion()
            return
        }
        // Fixed identifiers so the deck's "must-do first, then UUID" ordering is
        // reproducible across runs and a screenshot can be compared to the last.
        let seeds: [(id: UUID, title: String, commitment: TaskCommitmentLevel)] = [
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000001")!,
             "Draft the quarterly note", .mustDo),
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000002")!,
             "Reply to the venue about Friday", .standard),
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000003")!,
             "Book the dentist", .standard)
        ]
        let day = PlanningDay(
            date: seedsOpen ? Date().addingTimeInterval(-86_400) : Date()
        )

        Task { @MainActor in
            defer { completion() }
            let existing: [TaskDefinition] = await withCheckedContinuation { continuation in
                tasks.fetchAll { continuation.resume(returning: (try? $0.get()) ?? []) }
            }
            let existingIDs = Set(existing.map(\.id))
            let existingMetadata = (
                try? await planning.fetchTaskMetadata(taskIDs: Set(seeds.map(\.id)))
            ) ?? []
            let metadataByID = Dictionary(
                uniqueKeysWithValues: existingMetadata.map { ($0.taskID, $0) }
            )

            for seed in seeds {
                if existingIDs.contains(seed.id) == false {
                    let definition = TaskDefinition(
                        id: seed.id,
                        projectID: ProjectConstants.inboxProjectID,
                        title: seed.title
                    )
                    let created: Bool = await withCheckedContinuation { continuation in
                        tasks.create(definition) { continuation.resume(returning: (try? $0.get()) != nil) }
                    }
                    guard created else {
                        // Swallowing this made a failed seed indistinguishable
                        // from a successful one, which is how the empty deck
                        // went undiagnosed.
                        logError("Day-loop seed could not create task \(seed.title)")
                        continue
                    }
                }
                // Read-modify-write: constructing fresh metadata reset fields the
                // deck filters on, notably `availability` and
                // `unscheduledDisposition`.
                var metadata = metadataByID[seed.id] ?? PlanningTaskMetadata(taskID: seed.id)
                metadata.planningDay = day
                metadata.commitmentLevel = seed.commitment
                metadata.availability = .actionable
                metadata.unscheduledDisposition = .inbox
                metadata.updatedAt = Date()
                do {
                    try await planning.saveTaskMetadata(metadata)
                } catch {
                    logError("Day-loop seed could not commit \(seed.title): \(error)")
                }
            }
        }
    }
}
