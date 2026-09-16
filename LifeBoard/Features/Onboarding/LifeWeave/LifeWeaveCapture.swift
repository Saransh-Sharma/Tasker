import Foundation

/// What the capture step needs from a resolver: one sentence in, one
/// interpretation out. `UniversalInputCoordinator` is the production answer;
/// tests substitute one they can hold open and release on cue.
protocol LifeWeaveCaptureResolving: Sendable {
    func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution
}

extension UniversalInputCoordinator: LifeWeaveCaptureResolving {}

/// The first real thing the user gives LifeBoard.
///
/// Two rules govern this whole surface. Nothing is written until the user says
/// "Save" — classification proposes, it never commits. And when the
/// interpretation is genuinely uncertain, the user is *asked* rather than
/// guessed at, because a first capture that silently lands in the wrong place is
/// a worse introduction than one extra tap.
@MainActor
extension LifeWeaveOnboardingModel {

    /// The destinations onboarding can honestly offer.
    ///
    /// Task and Journal only, and deliberately not Note. `LifeMapCommitCoordinator`
    /// writes both `.note` and `.journal` to the same `ReflectionNote` store,
    /// while the rest of the product routes a note to Knowledge via
    /// `KnowledgeStore.createNote` — so offering "Note" here promises a
    /// destination onboarding does not actually write to.
    ///
    /// Routing it to Knowledge properly is the real fix, but `createNote`
    /// requires a `selectedSpaceID` and returns nil without one, and a brand-new
    /// workspace has no knowledge space yet. That would make the first capture —
    /// the one write that must not fail — depend on space bootstrapping. Until
    /// that exists, offering two truthful destinations beats offering three when
    /// one of them is a lie.
    static let offeredCaptureKinds: [LifeMapCaptureKind] = [.task, .journal]

    /// Classifies the typed sentence and stages a **proposal**.
    ///
    /// Never sets `isReviewed`. The staged capture is a suggestion the review
    /// card renders; only `keepCapture` promotes it to something the commit will
    /// write.
    ///
    /// One interpretation per sentence: if the same text is already with the
    /// resolver, this joins that pass instead of starting a second, so Save
    /// pressed during the pause cannot race the pause. A pass whose sentence
    /// has been edited since it started is discarded when it returns.
    func resolveCapture() async {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        if let inFlight = captureResolution, inFlight.text == text {
            await inFlight.task.value
            return
        }
        let generation = captureEditGeneration
        isResolvingCapture = true
        errorMessage = nil
        isCaptureAmbiguous = false
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performCaptureResolution(text: text, generation: generation)
        }
        captureResolution = (text, task)
        await task.value
        // Only the latest pass owns the spinner. An older one that finishes after
        // a newer started must not switch it off underneath the newer.
        if captureResolution?.text == text {
            captureResolution = nil
            isResolvingCapture = false
        }
    }

    private func performCaptureResolution(text: String, generation: Int) async {
        let resolution = await captureResolver.resolve(
            LifeThreadIntentInput(text: text, destination: .home)
        )
        // The sentence moved on while the resolver was thinking: this answer is
        // about text that is no longer on screen.
        guard generation == captureEditGeneration else { return }
        // A late proposal never demotes something the user already kept.
        if let staged = draft.stagedCapture, staged.isReviewed, staged.text == text { return }

        let kind: LifeMapCaptureKind
        switch resolution {
        case .captureDraft(let captureDraft):
            switch captureDraft.kind {
            // A note and a journal entry land in the same store today, and the
            // user is told "Journal" because that is where it goes.
            case .note, .journal: kind = .journal
            default: kind = .task
            }
        case .clarification:
            // The resolver said it does not know. v5 answered that by falling
            // through to `hasPrefix("note")` and `contains("i feel")`, which is
            // a guess wearing the costume of an interpretation. Ask instead.
            kind = .task
            isCaptureAmbiguous = true
        default:
            // `.answer`, `.navigation`, `.surfaceAction`, `.transactionPreview`:
            // none of these is a thing to *keep*, and the semantic model may
            // simply be unavailable. A task is the safe default and the chooser
            // is shown, so the user is never told we understood something we did
            // not.
            kind = .task
            isCaptureAmbiguous = true
        }

        setStagedCapture(
            LifeMapStagedCapture(
                id: draft.stagedCapture?.id ?? UUID(),
                text: text,
                kind: kind,
                lifeAreaTemplateID: suggestedAreaID(for: text),
                isReviewed: false
            )
        )
    }

    /// Interprets while the user types, instead of behind a button.
    ///
    /// "Make sense of this" was a tap that existed only because the model could
    /// not listen. Now a pause in typing is the request: the proposal appears
    /// under the field, and Save is available from the first character. Each
    /// edit cancels the pending pass, so a fast typist triggers one resolution,
    /// not one per keystroke. A pass already with the resolver is not cancelled;
    /// `resolveCapture` discards its result if the text has changed by then.
    func scheduleCaptureInterpretation(after delay: Duration = .milliseconds(600)) {
        captureInterpretationTask?.cancel()
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            if draft.stagedCapture?.isReviewed == false { setStagedCapture(nil) }
            isCaptureAmbiguous = false
            // Whatever is still with the resolver is answering a sentence that
            // no longer exists; its result is discarded by generation, and the
            // spinner must not wait for it.
            captureResolution = nil
            isResolvingCapture = false
            return
        }
        // Already interpreted this exact sentence: nothing to redo, and the
        // user's own Task/Journal choice must not be overwritten.
        if draft.stagedCapture?.text == text { return }
        captureInterpretationTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            await self?.resolveCapture()
        }
    }

    /// The user changed the proposed kind. Still a proposal until Save.
    func chooseCaptureKind(_ kind: LifeMapCaptureKind) {
        mutateDraft { $0.stagedCapture?.kind = kind }
        isCaptureAmbiguous = false
        feedback.selection()
    }

    /// Save: one action, whatever state interpretation is in.
    ///
    /// If the pause has not happened yet, the sentence is interpreted now and
    /// saved as whatever that proposes — the kind control was visible the whole
    /// time, so the user has not been denied a choice, only spared a wait.
    func saveCapture() async {
        captureInterpretationTask?.cancel()
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        if draft.stagedCapture?.text != text {
            await resolveCapture()
        }
        guard let staged = draft.stagedCapture else { return }
        keepCapture(kind: staged.kind, areaTemplateID: staged.lifeAreaTemplateID)
    }

    /// The user confirmed the interpretation. Still not written — the commit
    /// does that, at the end of the flow.
    func keepCapture(kind: LifeMapCaptureKind, areaTemplateID: String?) {
        mutateDraft { draft in
            draft.stagedCapture?.kind = kind
            draft.stagedCapture?.lifeAreaTemplateID = areaTemplateID
            draft.stagedCapture?.isReviewed = true
        }
        isCaptureAmbiguous = false
        feedback.medium()
    }

    /// Which of the user's own areas the sentence seems to belong to.
    ///
    /// Only ever chooses among areas the user actually selected, so the capture
    /// cannot land in a part of life they left off their map.
    func suggestedAreaID(for text: String) -> String? {
        let lower = text.lowercased()
        return selectedAreaTemplates.first { template in
            lower.contains(template.name.lowercased())
                || template.aliases.contains { lower.contains($0) }
        }?.id ?? draft.primaryLifeAreaTemplateID ?? selectedAreaTemplates.first?.id
    }
}
