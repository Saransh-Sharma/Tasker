import SwiftUI

extension DayCloseRoute {
    // MARK: - Morning variant

    /// The morning's whole point: agree with a day that has already been
    /// computed. Editing is available and secondary.
    @ViewBuilder
    var commitAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Today")

            if store.alreadyCommitted {
                Label("Day started", systemImage: "checkmark.seal")
                    .font(Typography.sectionTitle())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Button("Undo") { Task { await store.undoOpen() } }
                    .buttonStyle(.lifeBoardChip)
                    .accessibilityIdentifier("dayOpen.undo")
            } else if store.openProposal.isEmpty {
                Text("Nothing planned yet")
                    .font(Typography.body())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                CommitControl(
                    title: String(localized: "Start the day"),
                    runningTitle: String(localized: "Starting…"),
                    successTitle: String(localized: "Day started"),
                    phase: store.openCommitPhase
                ) {
                    Task {
                        await store.commitOpen()
                        // The boundary: the sweep and the haptic wait for the
                        // receipt, not for the tap.
                        if store.alreadyCommitted {
                            firstLightTrigger += 1
                            Haptic.commit.play()
                        }
                    }
                }
                .accessibilityIdentifier("dayOpen.commit")
            } else {
                ForEach(Array(store.openProposal.enumerated()), id: \.element.id) { index, candidate in
                    proposalRow(candidate)
                        // Loose until committed, then square.
                        //
                        // The morning act is agreeing to a shape for the day, so
                        // the proposal arrives as a set of loose possibilities
                        // and settles into an ordered list at the moment you say
                        // yes. Chaos to intention, which is what the act means.
                        .offset(
                            x: store.alreadyCommitted ? 0 : proposalLean(index),
                            y: 0
                        )
                        .rotationEffect(
                            .degrees(store.alreadyCommitted ? 0 : proposalLean(index) * 0.22)
                        )
                }
                CommitControl(
                    title: String(localized: "Start the day"),
                    runningTitle: String(localized: "Starting…"),
                    successTitle: String(localized: "Day started"),
                    phase: store.openCommitPhase
                ) {
                    Task {
                        await store.commitOpen()
                        // The boundary: the sweep and the haptic wait for the
                        // receipt, not for the tap.
                        if store.alreadyCommitted {
                            firstLightTrigger += 1
                            Haptic.commit.play()
                        }
                    }
                }
                .accessibilityIdentifier("dayOpen.commit")
                Text("Tap a task to leave it out.")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
        .dayCloseCard()
        .lifeBoardMotion(.controlMorph, value: store.openSelection.count)
        .lifeBoardMotion(.firstLight, value: store.alreadyCommitted)
        // One warm sweep across the committed day. Fires on the persisted-state
        // boundary — never on selection, which would promise something the
        // ledger has not been told yet.
        .lifeboardFirstLight(
            trigger: firstLightTrigger,
            tint: Color(SemanticColorTokens.foundationSunAccent)
        )
        .accessibilityIdentifier("dayOpen.commitAct")
    }

    private func proposalRow(_ candidate: DayOpenCandidate) -> some View {
        let isSelected = store.openSelection.contains(candidate.id)
        return Button {
            store.toggleOpenSelection(candidate.id)
            Haptic.pick.play()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected
                            ? Color(SemanticColorTokens.foundationSunAccent)
                            : Color(SemanticColorTokens.inkTertiary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.task.title)
                        .font(Typography.body())
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    if candidate.origin == .anchor {
                        Text("Picked last night")
                            .font(Typography.metadata())
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("dayOpen.proposal.\(candidate.id.uuidString)")
    }

    @ViewBuilder
    var carriedSummary: some View {
        // The anchor first and named, because it is the one thing a person
        // deliberately chose. Everything else is what merely survived.
        if let anchor = store.carriedAnchor {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Start here")
                HStack(spacing: 12) {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(Color(SemanticColorTokens.foundationSunInk))
                    Text(anchor.title)
                        .font(Typography.sectionTitle())
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
                Text("Picked when you closed yesterday.")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .dayCloseCard()
            .accessibilityIdentifier("dayOpen.anchor")
        }

        if store.unfinished.isEmpty {
            // Nothing carried: no card to say so, just the way on. The commit
            // act above already says the day is clear.
            Button("Open Plan") { onFinished() }
                .buttonStyle(.lifeBoardPrimary)
                .accessibilityIdentifier("dayOpen.carried")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // "Open from yesterday" is true whether or not yesterday was
                // closed, so the header no longer needs a provenance note.
                sectionHeader("Open from yesterday")
                ForEach(store.unfinished) { task in
                    Text(task.title)
                        .font(Typography.body())
                        .foregroundStyle(
                            task.id == store.carriedAnchorTaskID
                                ? Color(SemanticColorTokens.inkTertiary)
                                : Color(SemanticColorTokens.inkPrimary)
                        )
                }
                Button("Open Plan") { onFinished() }
                    .buttonStyle(.lifeBoardPrimary)
            }
            .dayCloseCard()
            .accessibilityIdentifier("dayOpen.carried")
        }
    }
}
