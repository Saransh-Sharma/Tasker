import Foundation
import LifeBoardTokens

/// The commit boundary: assemble, hold the floor, reveal.
///
/// Split from the model so the class body stays under the file-size gate's
/// largest-type budget. Everything here writes the draft through `mutateDraft`,
/// which persists, so a retry after a crash resumes from what was recorded.
@MainActor
extension LifeWeaveOnboardingModel {
    // MARK: - Commit

    /// The transient assemble phase.
    ///
    /// On failure the draft stays on `.firstCapture` with its snapshot intact and
    /// `commitPhase` recording how far it got, so the primary action resumes
    /// rather than restarts. Nothing is cleared until the commit reports success.
    func assemble() async {
        isCommitting = true
        defer { isCommitting = false }
        let startedAt = Date()
        await ProductTelemetry.shared.record(.commitStarted, flowVersion: 6)
        do {
            mutateDraft { $0.lifecyclePhase = .committing }
            let legacy = draft.makeCommitDraft(moduleIDs: recommendedModuleIDs)
            let committed = try await commitCoordinator.commit(legacy) { [weak self] partial in
                guard let self else { return }
                self.mutateDraft { $0.absorbCommitResult(partial) }
            }
            mutateDraft {
                $0.absorbCommitResult(committed)
                $0.lifecyclePhase = .captureWritten
            }
            await ProductTelemetry.shared.record(.commitCompleted, flowVersion: 6)
            await holdAssemblyFloor(since: startedAt)
            await prepareRevealAfterCanonicalCommit()
        } catch {
            // The banner says what happened in human words and offers a retry.
            // The raw description is for the log, not for somebody on their
            // first minute with the app.
            errorMessage = LifeWeaveCopy.Failure.body
            logOnboardingInfo(
                event: "onboarding_commit_failed",
                message: "Canonical onboarding commit failed",
                fields: ["error": String(describing: error)]
            )
            persist()
            await ProductTelemetry.shared.record(.commitFailed, flowVersion: 6, errorCode: "canonical_commit")
        }
    }

    /// Keeps the assemble sequence legible without exceeding `DESIGN.md`'s 800 ms
    /// signature-moment ceiling. Under reduced motion there is no sequence to
    /// protect, so the overlay crossfades out immediately.
    private func holdAssemblyFloor(since startedAt: Date) async {
        guard MotionOverride.effectiveReduceMotion == false else { return }
        let remaining = Self.assemblyFloor - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
    }

    private static let assemblyFloor: TimeInterval = 0.62

    func prepareRevealAfterCanonicalCommit() async {
        guard draft.resolvedLifecyclePhase == .captureWritten else { return }
        await performEvaHandoff()
        mutateDraft {
            $0.step = .reveal
            $0.lifecyclePhase = .revealReady
        }
        recordCoreCompletion()
        OnboardingFirstAction.save(from: draft)
        feedback.successSignature()
        await ProductTelemetry.shared.record(.revealViewed, flowVersion: 6)
    }
}

/// Seeds bounded local context and starter prompts after canonical onboarding
/// writes. Cloud activation is confirmed on the reveal after these local writes.
@MainActor
extension LifeWeaveOnboardingModel {
    func performEvaHandoff() async {
        let legacy = draft.makeCommitDraft(moduleIDs: recommendedModuleIDs)

        if draft.didWriteEvaProfile == false {
            let profile = LifeMapEvaProfileMapper.profileDraft(from: legacy)
            let merged = EvaMemoryMapper.mergeIntoV3Store(
                draft: profile,
                existing: EvaMemoryDefaultsStoreV3.load()
            )
            EvaMemoryDefaultsStoreV3.save(merged)
            mutateDraft { $0.didWriteEvaProfile = true }
        }

        let prompts = LifeMapEvaOpeningPrompt.prompts(
            for: legacy,
            upcomingEventCount: await powerUps.upcomingEventCount()
        )
        recordOpeningPrompts(prompts)
        EvaOpeningPromptStore.stage(prompts)
    }
}
