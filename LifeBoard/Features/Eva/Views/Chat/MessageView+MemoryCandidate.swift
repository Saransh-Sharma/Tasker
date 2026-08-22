import SwiftUI

extension MessageView {
    @ViewBuilder
    var inlineMemoryCandidate: some View {
        if let candidate = activeMemoryCandidate {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("Remember this?", systemImage: "person.crop.circle.badge.questionmark").font(.headline)
                if isEditingMemoryCandidate {
                    TextField("Memory", text: $memoryCandidateDraft, axis: .vertical).lineLimit(2...4)
                    Button("Done editing") { isEditingMemoryCandidate = false }.buttonStyle(.bordered)
                } else {
                    Text(memoryCandidateDraft.isEmpty ? candidate.text : memoryCandidateDraft)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                HStack {
                    Button("Save") { saveMemoryCandidate(candidate) }.buttonStyle(.lifeBoardPrimaryCompact)
                    Button("Edit") {
                        memoryCandidateDraft = memoryCandidateDraft.isEmpty ? candidate.text : memoryCandidateDraft
                        isEditingMemoryCandidate = true
                        Task { await ProductTelemetry.shared.record(.memoryProposalEdited) }
                    }.buttonStyle(.bordered)
                    Button("Later") { deferMemoryCandidate(candidate) }.buttonStyle(.bordered)
                    Button("Dismiss", role: .destructive) { dismissMemoryCandidate(candidate) }.buttonStyle(.borderless)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16))
            .onAppear { if memoryCandidateDraft.isEmpty { memoryCandidateDraft = candidate.text } }
            .accessibilityIdentifier("eva.memoryCandidate.inline")
        }
    }

    private var activeMemoryCandidate: EvaMemoryCandidate? {
        _ = memoryCandidateRevision
        guard let candidate = renderModel.memoryCandidate else { return nil }
        return EvaMemoryCandidateDefaultsStore.load().pending.first {
            $0.id == candidate.id && $0.state == .inline
        }
    }

    private func saveMemoryCandidate(_ candidate: EvaMemoryCandidate) {
        var store = EvaMemoryDefaultsStoreV3.load()
        if store.statements.count >= EvaMemoryStoreV3.maxStatements,
           let replacement = store.statements.last(where: { $0.provenance != .userStated })?.id
            ?? store.statements.last?.id { store.remove(id: replacement) }
        store.upsert(EvaMemoryStatement(
            section: candidate.section, text: memoryCandidateDraft, provenance: .inferredCandidate
        ))
        EvaMemoryDefaultsStoreV3.save(store)
        mutateInbox { $0.pending.removeAll { $0.id == candidate.id } }
        Task { await ProductTelemetry.shared.record(.memoryProposalSaved) }
    }

    private func deferMemoryCandidate(_ candidate: EvaMemoryCandidate) {
        mutateInbox { $0.deferCandidate(id: candidate.id) }
        Task { await ProductTelemetry.shared.record(.memoryProposalDeferred) }
    }

    private func dismissMemoryCandidate(_ candidate: EvaMemoryCandidate) {
        mutateInbox { $0.dismiss(id: candidate.id) }
        Task { await ProductTelemetry.shared.record(.memoryProposalDismissed) }
    }

    private func mutateInbox(_ update: (inout EvaMemoryCandidateInbox) -> Void) {
        var inbox = EvaMemoryCandidateDefaultsStore.load()
        update(&inbox)
        EvaMemoryCandidateDefaultsStore.save(inbox)
        memoryCandidateRevision += 1
    }
}
