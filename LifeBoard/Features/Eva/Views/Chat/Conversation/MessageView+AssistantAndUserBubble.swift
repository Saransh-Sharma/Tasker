//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension MessageView {
    var runtimeRunning: Bool {
        runtime?.running ?? false
    }

    var runtimeElapsedTime: TimeInterval? {
        runtime?.elapsedTime
    }

    var isThinking: Bool {
        renderModel.isThinkingOpenEnded
    }

    var answerIsEmpty: Bool {
        renderModel.answerText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    var thinkingIsEmpty: Bool {
        renderModel.thinkingText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    var isPendingResponse: Bool {
        pendingPhase.isActive
    }

    var activeWorkingStatuses: [String] {
        if runtimeRunning {
            return workingStatuses
        }
        if let pendingStatusText, pendingStatusText.isEmpty == false {
            return [pendingStatusText]
        }
        return workingStatuses
    }

    var time: String {
        if isThinking, runtimeRunning, let elapsedTime = runtimeElapsedTime {
            return "(\(elapsedTime.formatted))"
        }
        if let generatingTime = renderModel.generatingTime {
            return generatingTime.formatted
        }
        return "0s"
    }

    var messageMaxWidth: CGFloat {
        switch layoutClass {
        case .phone:
            return .infinity
        case .padCompact:
            return 620
        case .padRegular:
            return 680
        case .padExpanded:
            return 720
        }
    }

    var oppositeSideInset: CGFloat {
        switch layoutClass {
        case .phone:
            return 32
        case .padCompact:
            return 48
        case .padRegular, .padExpanded:
            return 64
        }
    }

    var thinkingLabel: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                collapsed.toggle()
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.lifeboard(.caption2))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }

            Text("\(isThinking ? "thinking..." : "thought for") \(time)")
                .lifeboardFont(.caption1)
                .italic()
                .foregroundStyle(Color.lifeboard(.textTertiary))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .lifeboardChromeSurface(
            cornerRadius: 16,
            accentColor: Color.lifeboard(.accentSecondary),
            level: .e1
        )
        .buttonStyle(.borderless)
    }

    var shouldShowLiveWorkingStatus: Bool {
        isLiveOutput &&
        (runtimeRunning || isPendingResponse) &&
        answerIsEmpty &&
        thinkingIsEmpty
    }

    var shouldShowTypingIndicator: Bool {
        isLiveOutput && (runtimeRunning || isPendingResponse)
    }

    @ViewBuilder
    var assistantBody: some View {
        if let payload = renderModel.cardPayload {
            // Proposals, command results and receipts are bounded objects, and
            // `DESIGN.md` gives them clay — not glass. Glass belongs to the
            // control layer, and an assistant message is content no matter how
            // structured it is. This was a premium glass-style surface, which
            // put a translucent pane behind text the person has to read and act
            // on before approving a change.
            assistantCardView(payload: payload)
                .padding(Theme.Spacing.lg)
                .lifeBoardClaySurface(.raised)
                .frame(maxWidth: messageMaxWidth, alignment: .leading)
                .padding(.trailing, oppositeSideInset)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if shouldShowLiveWorkingStatus {
                    EvaLiveWorkingStatusView(statuses: activeWorkingStatuses)
                }

                if EvaThinkingVisibilityPolicy.showsVisibleThinking,
                   let thinking = renderModel.thinkingText {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        thinkingLabel
                        if !collapsed, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: Theme.Spacing.md) {
                                Capsule()
                                    .frame(width: 2)
                                    .padding(.vertical, 1)
                                    .foregroundStyle(Color.lifeboard(.accentMuted))
                                markdownText(
                                    thinking,
                                    color: Color.lifeboard(.textSecondary)
                                )
                            }
                            .padding(.leading, 5)
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        collapsed.toggle()
                        if isThinking, isLiveOutput {
                            runtime?.collapsed = collapsed
                        }
                    }
                }

                if let answer = renderModel.answerText {
                    markdownText(
                        answer,
                        color: Color.lifeboard(.textPrimary)
                    )
                    if isLiveOutput == false {
                        evidenceCitationRail(for: answer)
                        spokenOutputControls(for: answer)
                        if renderModel.contextReceipt != nil {
                            Button("Context used", systemImage: "checkmark.shield") {
                                showsContextReceipt = true
                                Task { await ProductTelemetry.shared.record(.contextReceiptOpened) }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("eva.contextReceipt.open")
                        }
                        inlineMemoryCandidate
                    }
                }

            }
            // Ordinary Eva prose is a reading surface, not a card. Proposal,
            // result, and Undo payloads above remain bounded tactile objects;
            // the conversation itself stays open and calm.
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: messageMaxWidth, alignment: .leading)
            .padding(.trailing, oppositeSideInset)
        }
    }

    @ViewBuilder
    func spokenOutputControls(for text: String) -> some View {
        if EvaCloudAccountState.shared.configuration?.ttsEnabled == true,
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    if spokenOutput.activeText == text {
                        switch spokenOutput.state {
                        case .loading:
                            ProgressView()
                                .controlSize(.small)
                            Button("Stop", systemImage: "stop.fill") { spokenOutput.stop() }
                        case .playing:
                            Button("Pause", systemImage: "pause.fill") { spokenOutput.pause() }
                        case .paused:
                            Button("Resume", systemImage: "play.fill") { spokenOutput.resume() }
                            Button("Stop", systemImage: "stop.fill") { spokenOutput.stop() }
                        case .failed:
                            Button("Try again", systemImage: "arrow.clockwise") { spokenOutput.play(text: text) }
                            if spokenOutput.requiresPaidRegeneration {
                                Button("Regenerate · 1 credit") { paidSpeechRegenerationText = text }
                            }
                        case .idle:
                            Button("Speak", systemImage: "speaker.wave.2.fill") { spokenOutput.play(text: text) }
                        }
                    } else {
                        Button("Speak", systemImage: "speaker.wave.2.fill") { spokenOutput.play(text: text) }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text(spokenOutput.disclosure)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .accessibilityLabel("Spoken with an AI-generated voice")
            }
            .accessibilityElement(children: .contain)
        }
    }

    /// `DESIGN.md`: "user messages use quiet clay".
    ///
    /// Was a saturated two-stop gradient with a white inner stroke and its own
    /// hand-rolled drop shadow — the loudest object in the transcript, competing
    /// with the assistant's answer for attention on a screen whose whole purpose
    /// is reading that answer. Clay `.resting` puts it a plane above the canvas
    /// and no further, and the hairline, rim and shadow all come from the depth
    /// scale rather than from three literals here.
    var userBody: some View {
        Markdown(renderModel.displayContent)
            .textSelection(.enabled)
            .markdownTextStyle {
                ForegroundColor(Color.lifeboard(.textPrimary))
            }
        #if os(iOS) || os(visionOS)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        #else
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        #endif
            .lifeBoardClaySurface(.resting, fill: Color.lifeboard(.surfaceSecondary))
            .frame(maxWidth: messageMaxWidth, alignment: .trailing)
            .padding(.leading, oppositeSideInset)
    }

    /// Renders assistant prose.
    ///
    /// Two things used to go wrong here while a reply was streaming, and both
    /// came from this function.
    ///
    /// **Raw markdown reached the reader.** Streaming took a `Text` branch, so
    /// `**bold**`, `###` and list bullets appeared as literal syntax and only
    /// resolved into formatting once generation finished. `Markdown` renders
    /// partial documents perfectly well — an unterminated `**` is simply shown as
    /// text until its closing pair arrives — so there is no reason to withhold
    /// formatting until the end, and the swap between the two branches was itself
    /// a visible re-layout on the last frame.
    ///
    /// **The text flashed on every update.** `.id(renderModel.markdownSourceHash)`
    /// derives identity from the content, so each new phrase gave the view a new
    /// identity and SwiftUI tore down and rebuilt the whole subtree rather than
    /// diffing it. `Markdown` is a plain value view holding `let content`; it
    /// re-renders correctly when that content changes, and needs no identity
    /// override at all. Do not reintroduce one keyed on content.
    func markdownText(_ text: String, color: Color) -> some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTextStyle {
                ForegroundColor(color)
            }
            // Content grows from the top, so keep the block anchored there while
            // it does; the default centre anchor makes settled lines drift.
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(nil, value: text)
    }

    @ViewBuilder
    func evidenceCitationRail(for text: String) -> some View {
        let citations = authorizedLifeEvidence.citations(in: text)
        if citations.isEmpty == false {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Evidence")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(citations) { citation in
                            Button {
                                evidenceOpenAction.open(citation.reference)
                            } label: {
                                Label(citation.label, systemImage: "checkmark.shield")
                                    .font(.lifeboard(.caption1))
                                    .lineLimit(1)
                                    .frame(minHeight: 32)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Evidence: \(citation.label)")
                            .accessibilityHint("Opens the recorded LifeBoard source")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func assistantCardView(payload: AssistantCardPayload) -> some View {
        if payload.cardType == .unknown {
            // Chat history can outlive an app version. A newer card therefore
            // degrades to its human-readable message instead of exposing the
            // persisted wire marker and JSON as a chat bubble.
            Text(payload.message ?? "This card was created by a newer version of LifeBoard.")
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let navigation = payload.navigation {
            navigationCardView(navigation)
        } else if let evaProposal = payload.evaProposal {
            evaProposalCardView(payload: payload, proposal: evaProposal)
        } else if let dayOverview = payload.dayOverview {
            dayOverviewCardView(payload: payload, overview: dayOverview)
        } else if payload.cardType == .commandResult, let commandResult = payload.commandResult {
            commandResultCardView(commandResult)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    EvaMascotView(
                        placement: payload.cardType == .undo ? .proposalApplied : .proposalReview,
                        size: .chip
                    )

                    Text(payload.cardType == .undo ? "Changes applied" : "\(AssistantIdentityText.currentSnapshot().displayName)'s Plan")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))

                    Spacer()
                    if payload.cardType == .proposal {
                        Text("Affects \(payload.affectedTaskCount) tasks")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                    }
                }

                if let rationale = payload.rationale, !rationale.isEmpty {
                    Text("Rationale: \"\(rationale)\"")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }

                if !payload.diffLines.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(Array(payload.diffLines.enumerated()), id: \.offset) { _, line in
                            Text("• \(line.text)")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(
                                    line.isDestructive ? Color.lifeboard(.statusDanger) : Color.lifeboard(.textPrimary)
                                )
                        }
                    }
                }

                if payload.captureReferences.isEmpty == false {
                    ForEach(payload.captureReferences, id: \.recordID) { reference in
                        Button {
                            onOpenRecordFromCard?(reference)
                        } label: {
                            Label(reference.title, systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if payload.cardType == .undo {
                    HStack {
                        Text(undoLabel(payload: payload))
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                        Spacer()
                        Button("Undo") {
                            if let runID = payload.runID {
                                undoAssistantRun(runID, payload: payload)
                            }
                        }
                            .buttonStyle(.borderedProminent)
                            .disabled(isUndoExpired(payload: payload) || isUndoingEvaRun || payload.runID == nil)
                    }
                } else if payload.cardType == .proposal {
                    if payload.runID == nil {
                        Text("Invalid proposal card (missing run ID).")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.statusDanger))
                    } else if payload.status == .pending || payload.status == .confirmed {
                        HStack(spacing: Theme.Spacing.sm) {
                            Button("Reject") {}
                                .buttonStyle(.bordered)

                            Button("Apply Changes") {}
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text(payload.message ?? proposalStatusText(payload.status))
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                    }
                } else if let status = payload.message {
                    Text(status)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                }
            }
        }
    }

    @ViewBuilder
    private func navigationCardView(_ navigation: EvaNavigationCardPayload) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Open in LifeBoard", systemImage: "arrow.up.forward.app")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text(navigation.message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard(.textSecondary))

            if navigation.candidates.isEmpty {
                Button("Open") {
                    onOpenNavigationTargetFromCard?(navigation.target)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ForEach(navigation.candidates) { candidate in
                    Button {
                        onOpenRecordFromCard?(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                if let subtitle = candidate.subtitle {
                                    Text(subtitle)
                                        .font(.lifeboard(.caption1))
                                        .foregroundStyle(Color.lifeboard(.textTertiary))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.navigation_card")
    }
}
