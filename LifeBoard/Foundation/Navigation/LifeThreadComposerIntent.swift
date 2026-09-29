import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// What the composer does with what you typed.
///
/// Separated from `LifeThreadComposerHost`'s chrome because these are the two
/// genuinely different jobs in that surface: drawing the field and its tool row,
/// versus resolving free text into an intent, staging a preview, applying it,
/// and offering the undo. An extension rather than a second type, so the
/// shell's thirteen bindings are not plumbed twice.
extension LifeThreadComposerHost {
    func liveResolveComposerIntent(router: AppRouter) {
        guard V2FeatureFlags.universalInputRoutingEnabled else { return }
        // A submit is already working on this draft and its own resolution
        // decides what happens next. A preview now would only re-offer the
        // text that is being saved — the Return key's newline strip lands here
        // mid-submit.
        guard composer.state != .working else { return }
        liveIntentResolveTask?.cancel()
        // An interpretation belongs to the exact draft that produced it.
        // Clear it synchronously before debouncing the replacement so a
        // quick edit-then-submit can never execute a stale action.
        composer.dismissInterpretation()
        composer.dismissClarification()
        // Don't interpret while recording — the composer text is volatile
        // (live transcript) and the user can't yet act on an interpretation
        // row. Resolution runs once on stop, via `submitLifeThreadComposer`.
        guard dictationController.isRecording == false else { return }
        let text = composer.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            return
        }
        #if DEBUG
        // Lets UI tests reach the path where Send beats the preview, which a
        // person hits by tapping within about 0.3 s of the last keystroke.
        if ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_DISABLE_COMPOSER_LIVE_PREVIEW") { return }
        #endif
        liveIntentResolveTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            let input = LifeThreadIntentInput(
                text: text,
                attachments: composer.attachments.map(\.localIdentifier),
                destination: composer.destination,
                origin: .conversation,
                inputSource: composer.lastInputSource,
                selectedDate: router.selectedDestination == .home ? homeViewModel.selectedDate : nil,
                daypart: runtime.preferences.resolvedDaypart(),
                dashboardMode: router.dashboardMode,
                calendarAvailable: homeViewModel.homeCalendarSnapshot.authorizationStatus.isAuthorizedForRead,
                dayRescueEligible: !homeViewModel.dayRescueTasksByID.isEmpty,
                overdueRescueEligible: !homeViewModel.evaRescueTasksByID.isEmpty,
                overdueTaskCount: homeViewModel.evaRescueTasksByID.count
            )
            let resolution = await universalInputCoordinator.resolvePreview(input)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard composer.state != .working else { return }
                switch resolution {
                case .captureDraft(let draft):
                    composer.showInterpretation(for: draft)
                case .navigation(let navigation):
                    composer.showInterpretation(for: navigation)
                case .surfaceAction(let action):
                    composer.showInterpretation(for: action)
                case .clarification(let clarification):
                    composer.showClarification(clarification)
                case .answer, .transactionPreview:
                    // No preview interpretation to show for free-text or
                    // transaction previews that already drive their own
                    // affordance. Leave the composer ready to submit
                    // directly via the Send button.
                    composer.dismissInterpretation()
                    composer.dismissClarification()
                }
            }
        }
    }

    func submitLifeThreadComposer(router: AppRouter) {
        // One submit at a time: Return, Send and an accepted row can each
        // arrive while the last submit is still working.
        guard composer.state != .working else { return }
        // Sending ends editing (`DESIGN.md`): the keyboard goes away as the work
        // starts. Disabling the field for `.working` does not do it — the
        // keyboard stayed up over the receipt — and an empty Send or Return
        // means "I'm done typing" anyway.
        lifeThreadComposerIsFocused = false
        liveIntentResolveTask?.cancel()
        liveIntentResolveTask = nil
        if let interpretation = composer.interpretation {
            let res = interpretation.resolution
            composer.dismissInterpretation()
            handleLifeThreadResolution(res, router: router)
            return
        }
        let text = composer.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        guard V2FeatureFlags.universalInputRoutingEnabled else {
            do {
                try EvaChatLaunchRequestStore.shared.submit(.init(prompt: text))
                composer.dismissDraft()
                lifeThreadComposerIsFocused = false
                router.activateRoot(.eva)
                Haptic.pick.play()
            } catch {
                composer.returnToEditing()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: String(localized: "Try again. Your draft is still here.")
                )
            }
            return
        }
        let input = LifeThreadIntentInput(
            text: text,
            attachments: composer.attachments.map(\.localIdentifier),
            destination: composer.destination,
            origin: .conversation,
            inputSource: composer.lastInputSource,
            selectedDate: router.selectedDestination == .home ? homeViewModel.selectedDate : nil,
            daypart: runtime.preferences.resolvedDaypart(),
            dashboardMode: router.dashboardMode,
            calendarAvailable: homeViewModel.homeCalendarSnapshot.authorizationStatus.isAuthorizedForRead,
            dayRescueEligible: !homeViewModel.dayRescueTasksByID.isEmpty,
            overdueRescueEligible: !homeViewModel.evaRescueTasksByID.isEmpty,
            overdueTaskCount: homeViewModel.evaRescueTasksByID.count
        )
        composer.beginWorking(String(localized: "Thinking…"))
        Task {
            let resolution = await universalInputCoordinator.resolve(input)
            await MainActor.run {
                handleLifeThreadResolution(resolution, router: router)
            }
        }
    }

    func handleLifeThreadResolution(_ resolution: LifeThreadIntentResolution, router: AppRouter) {
        switch resolution {
        case .answer(let request):
            if ComposerPlainPhraseChoice.consumeAsk(request.prompt) == false,
               QuickCaptureSavePolicy.isPlainPhrase(request.prompt) {
                composer.returnToEditing()
                composer.showClarification(ComposerPlainPhraseChoice.clarification(
                    for: request,
                    destination: composer.destination
                ))
                Haptic.pick.play()
                return
            }
            do {
                try EvaChatLaunchRequestStore.shared.submit(.init(prompt: request.prompt))
                composer.dismissDraft()
                lifeThreadComposerIsFocused = false
                router.activateRoot(.eva)
                Haptic.pick.play()
            } catch {
                composer.returnToEditing()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: String(localized: "Try again. Your draft is still here.")
                )
            }
        case .captureDraft(let draft):
            // "Save as task" on a plain phrase: saved to the Inbox in place,
            // like any typed task, rather than opening the editor.
            if draft.kind == .task, let seed = draft.seed, ComposerPlainPhraseChoice.consumeTask(draft.id) {
                saveTaskInPlace(seed, router: router)
                return
            }
            if draft.kind == .task, QuickCaptureSavePolicy.canSaveInPlace(draft.seed), let seed = draft.seed {
                saveTaskInPlace(seed, router: router)
                return
            }
            composer.returnToEditing()
            runtime.captureRouter.request(
                kind: draft.kind,
                source: .shell,
                prefilledText: draft.seed?.rawText,
                captureSeed: draft.seed
            )
        case .transactionPreview(let preview):
            composer.review(preview)
        case .navigation(let request):
            composer.returnToEditing()
            router.activateRoot(request.destination)
            if let route = request.route {
                router.push(route, in: request.destination)
            }
        case .clarification(let clarification):
            composer.showClarification(clarification)
        case .surfaceAction(let action):
            // Surface actions preserve the composer draft so the user can
            // resume if the action is cancelled. We don't dismiss the
            // keyboard or the draft; only the deck navigates over the
            // composer.
            // Reached straight from a submit, the composer is still working;
            // nothing else would ever release it.
            composer.returnToEditing()
            lifeThreadComposerIsFocused = false
            switch action {
            case .showTodaySchedule:
                let calendarAvailable = homeViewModel.homeCalendarSnapshot
                    .authorizationStatus.isAuthorizedForRead
                router.activateRoot(.home)
                // Always focus today so "check my meetings" lands on the
                // current day even if Home was scrubbed.
                if calendarAvailable {
                    homeViewModel.returnToToday(source: .universalInput)
                    presentCalendarSchedule(router: router)
                } else {
                    // Calendar-unavailable: navigate to Home and surface
                    // the canonical permission-guidance body copy as a
                    // toast so the user can grant access and retry.
                    let accessAction = homeViewModel.homeCalendarSnapshot.accessAction
                    let guidance: String
                    switch accessAction {
                    case .requestPermission:
                        guidance = String(localized: "Connect your calendar to see events.")
                    case .openSystemSettings:
                        guidance = String(localized: "Calendar access is off. Turn it on in Settings.")
                    case .unavailable:
                        guidance = String(localized: "Calendar access is restricted on this device.")
                    case .noneNeeded:
                        guidance = String(localized: "No calendars selected. Pick one on Home.")
                    }
                    router.activeAlert = .init(
                        title: "Calendar isn’t connected",
                        message: guidance
                    )
                }
            case .dayRescue:
                presentPlanOverdueRescue(
                    OverdueRescueLaunchContext.universalInputDayRescue(
                        referenceDate: Date()
                    )
                )
            case .overdueRescue:
                presentPlanOverdueRescue(
                    OverdueRescueLaunchContext.home(
                        referenceDate: Date()
                    )
                )
            }
        }
    }

    /// Sends "check my meetings" to Plan's day lens.
    ///
    /// This route used to depend on a detached UIKit home and could silently
    /// no-op. The typed foundation route is now the sole authority.
    ///
    /// `.planDay` is not a compromise destination: it draws the same calendar
    /// events (`PlanDaySnapshot.commitments`, built from `externalCommitments`)
    /// on an hour grid with the free-window layer, and it is already where
    /// `lifeboard://calendar/schedule` lands from the widget — so the two paths
    /// that used to disagree now don't.

    func presentCalendarSchedule(router: AppRouter) {
        router.select(.plan)
        router.push(.planDay, in: .plan)
    }

    /// Type-and-go: a confidently parsed task saves on Send and leaves a receipt
    /// with Undo, instead of opening the editor. It goes through the same view
    /// model the editor uses, so tags, project, and schedule resolve identically.
    /// Anything uncertain — an unknown `+project`, a failed save — falls back to
    /// the editor with the draft intact.
    func saveTaskInPlace(_ seed: CaptureSeed, router: AppRouter) {
        let openEditor = {
            composer.returnToEditing()
            runtime.captureRouter.request(
                kind: .task,
                source: .shell,
                prefilledText: seed.rawText,
                captureSeed: seed
            )
        }
        guard let parsed = seed.parsedCapture else {
            openEditor()
            return
        }
        // A submit that resolved into this save already holds the lock and
        // only needs a truer label; the interpretation row's Add arrives
        // without it. This used to return whenever the composer was working —
        // the very state the submit path leaves it in — so a Send that beat
        // the live preview stayed on "Understanding what you need" for good.
        if composer.beginWorking(String(localized: "Adding…")) == false {
            composer.relabelWorking(String(localized: "Adding…"))
        }
        Task { @MainActor in
            let viewModel = CompositionRoot.shared.makeNewAddTaskViewModel()
            viewModel.applyCaptureSeed(parsed, rawText: seed.rawText)
            guard await viewModel.awaitCaptureSelectionsResolved() else {
                openEditor()
                return
            }
            let created: Result<UUID, Error> = await withCheckedContinuation { continuation in
                viewModel.createTask { continuation.resume(returning: $0) }
            }
            guard case .success(let taskID) = created else {
                openEditor()
                return
            }
            let title = viewModel.taskName
            let message = QuickCaptureSavePolicy.receiptMessage(
                title: title,
                scheduledStartAt: viewModel.scheduledStartAt,
                dueDate: viewModel.plannedDate
            )
            let preview = TransactionPreview(
                destination: .plan,
                summary: "Add task",
                changes: [message],
                origin: .conversation
            )
            let deleteTask = CompositionRoot.shared.useCaseCoordinator.deleteTaskDefinition
            await lifeBoardMutationCoordinator.prepare(MutationCommand(
                preview: preview,
                apply: { message },
                undo: {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        deleteTask.execute(taskID: taskID) { continuation.resume(with: $0) }
                    }
                }
            ))
            IntentDonations.taskAdded(title: title)
            do {
                lifeBoardActionReceipt = try await lifeBoardMutationCoordinator.apply(previewID: preview.id)
            } catch {
                // The task exists; only the receipt failed. Say so plainly.
                lifeBoardActionReceipt = ActionReceipt(transactionID: preview.id, message: message, canUndo: false)
            }
            lifeBoardActionReceipt?.taskID = taskID
            composer.dismissDraft()
            composer.settle()
            Haptic.commit.play()
            try? await Task.sleep(for: .milliseconds(220))
            composer.finishSettling()
        }
    }

    func applyLifeThreadPreview(
        _ preview: TransactionPreview,
        router: AppRouter
    ) {
        // A second tap while the first apply is in flight must not apply the
        // same preview twice. `DESIGN.md`: running prevents duplicate submission.
        guard composer.beginWorking(String(localized: "Saving…")) else { return }
        Task {
            do {
                let receipt = try await lifeBoardMutationCoordinator.apply(previewID: preview.id)
                await MainActor.run {
                    lifeBoardActionReceipt = receipt
                    composer.dismissDraft()
                    composer.settle()
                    Haptic.commit.play()
                }
                try? await Task.sleep(for: .milliseconds(220))
                await MainActor.run { composer.finishSettling() }
            } catch {
                await MainActor.run {
                    composer.review(preview)
                    router.activeAlert = .init(
                        title: String(localized: "Couldn’t apply change"),
                        message: String(localized: "Nothing changed. Try again.")
                    )
                }
            }
        }
    }

    func undoLifeThreadReceipt(
        _ receipt: ActionReceipt,
        router: AppRouter
    ) {
        Task {
            do {
                try await lifeBoardMutationCoordinator.undo(receiptID: receipt.id)
                await MainActor.run {
                    lifeBoardActionReceipt = nil
                    Haptic.decline.play()
                }
            } catch {
                await MainActor.run {
                    router.activeAlert = .init(
                        title: "Couldn’t undo",
                        message: String(localized: "Try again from where you made it.")
                    )
                }
            }
        }
    }
}

/// The "Save as task / Ask Eva" question for a plain phrase, and the memory of
/// which answer was picked so acting on it does not ask again. An answer only
/// counts once its option is chosen: dismissing the question and sending the
/// same words asks again.
@MainActor
enum ComposerPlainPhraseChoice {
    private static var pendingTaskOptions: [UUID: UUID] = [:]
    private static var pendingAskOptions: [UUID: String] = [:]
    private static var confirmedTaskDraftIDs: Set<UUID> = []
    private static var confirmedAskPrompts: Set<String> = []

    static func clarification(
        for request: LifeThreadAnswerRequest,
        destination: Destination
    ) -> ClarificationRequest {
        let text = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = TaskCaptureParser.parse(text)
        let draft = LifeThreadCaptureDraft(
            kind: .task,
            text: text,
            destination: destination,
            seed: CaptureSeed(rawText: text, parsedCapture: parsed, inputSource: .typed)
        )
        let assistant = AssistantIdentitySnapshot.current.displayName
        let save = ClarificationOption(label: "Save as task", systemImage: "checklist", resolution: .captureDraft(draft))
        let ask = ClarificationOption(label: "Ask \(assistant)", systemImage: "sparkles", resolution: .answer(request))
        pendingTaskOptions = [save.id: draft.id]
        pendingAskOptions = [ask.id: request.prompt]
        return ClarificationRequest(
            question: "Save \u{201C}\(text)\u{201D} as a task?",
            options: [save, ask],
            originalText: request.prompt
        )
    }

    /// Call when a clarification option is picked, before acting on it.
    static func didChoose(_ option: ClarificationOption) {
        if let draftID = pendingTaskOptions[option.id] { confirmedTaskDraftIDs.insert(draftID) }
        if let prompt = pendingAskOptions[option.id] { confirmedAskPrompts.insert(prompt) }
        pendingTaskOptions = [:]
        pendingAskOptions = [:]
    }

    static func consumeTask(_ id: UUID) -> Bool {
        confirmedTaskDraftIDs.remove(id) != nil
    }

    static func consumeAsk(_ prompt: String) -> Bool {
        confirmedAskPrompts.remove(prompt) != nil
    }
}
