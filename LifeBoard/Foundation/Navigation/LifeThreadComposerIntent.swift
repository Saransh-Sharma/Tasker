import SwiftUI
import SwiftData
import TranscriptionKit
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
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } catch {
                composer.focus()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: "Your draft is still here. Please try again."
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
        composer.beginWorking("Understanding what you need")
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
            do {
                try EvaChatLaunchRequestStore.shared.submit(.init(prompt: request.prompt))
                composer.dismissDraft()
                lifeThreadComposerIsFocused = false
                router.activateRoot(.eva)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } catch {
                composer.focus()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: "Your draft is still here. Please try again."
                )
            }
        case .captureDraft(let draft):
            composer.focus()
            runtime.captureRouter.request(
                kind: draft.kind,
                source: .shell,
                prefilledText: draft.seed?.rawText,
                captureSeed: draft.seed
            )
        case .transactionPreview(let preview):
            composer.review(preview)
        case .navigation(let request):
            composer.focus()
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
                        guidance = "Connect Calendar to surface next meetings and free windows."
                    case .openSystemSettings:
                        guidance = "Calendar access is denied. Enable LifeBoard in Settings > Privacy & Security > Calendars to see your meetings here."
                    case .unavailable:
                        guidance = "Calendar access is restricted by system policy."
                    case .noneNeeded:
                        guidance = "Calendar is connected, but no calendars are selected. Pick one in Home to see your meetings."
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

    func applyLifeThreadPreview(
        _ preview: TransactionPreview,
        router: AppRouter
    ) {
        composer.beginWorking("Saving locally")
        Task {
            do {
                let receipt = try await lifeBoardMutationCoordinator.apply(previewID: preview.id)
                await MainActor.run {
                    lifeBoardActionReceipt = receipt
                    composer.dismissDraft()
                    composer.settle()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                try? await Task.sleep(for: .milliseconds(220))
                await MainActor.run { composer.finishSettling() }
            } catch {
                await MainActor.run {
                    composer.review(preview)
                    router.activeAlert = .init(
                        title: "Change wasn’t applied",
                        message: "Nothing was changed. Your preview is still here so you can try again."
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    router.activeAlert = .init(
                        title: "Couldn’t undo",
                        message: "The saved change is still in place. Please open its source and try again."
                    )
                }
            }
        }
    }
}
