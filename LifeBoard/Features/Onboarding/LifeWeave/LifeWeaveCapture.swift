import Foundation

/// The first real thing the user gives LifeBoard.
///
/// Two rules govern this whole surface. Nothing is written until the user says
/// "Keep this" — classification proposes, it never commits. And when the
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

    /// Whether the interpretation needs the user to choose.
    var captureNeedsDisambiguation: Bool {
        draft.stagedCapture?.isReviewed == false && isCaptureAmbiguous
    }

    /// Classifies the typed sentence and stages a **proposal**.
    ///
    /// Never sets `isReviewed`. The staged capture is a suggestion the review
    /// card renders; only `keepCapture` promotes it to something the commit will
    /// write.
    func resolveCapture() async {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        isResolvingCapture = true
        errorMessage = nil
        isCaptureAmbiguous = false
        defer { isResolvingCapture = false }

        let resolution = await universalInput.resolve(
            LifeThreadIntentInput(text: text, destination: .home)
        )

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
        feedback.medium()
    }

    /// The user corrected or confirmed the interpretation. Still not written —
    /// the commit does that, at the end of the flow.
    func keepCapture(kind: LifeMapCaptureKind, areaTemplateID: String?) {
        mutateDraft { draft in
            draft.stagedCapture?.kind = kind
            draft.stagedCapture?.lifeAreaTemplateID = areaTemplateID
            draft.stagedCapture?.isReviewed = true
        }
        isCaptureAmbiguous = false
        feedback.medium()
    }

    /// Back to editing, with the text intact.
    func reopenCapture() {
        mutateDraft { $0.stagedCapture?.isReviewed = false }
        feedback.light()
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
