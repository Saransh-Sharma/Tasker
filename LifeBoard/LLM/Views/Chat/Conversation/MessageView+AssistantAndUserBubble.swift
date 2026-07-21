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
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
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
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
            assistantCardView(payload: payload)
                .padding(LifeBoardTheme.Spacing.lg)
                .lifeboardPremiumSurface(
                    cornerRadius: 24,
                    fillColor: EvaChatSunriseGlass.glassFill,
                    strokeColor: EvaChatSunriseGlass.assistantBorder.opacity(0.72),
                    accentColor: EvaChatSunriseGlass.primary,
                    level: .e2,
                    useNativeGlass: false
                )
                .frame(maxWidth: messageMaxWidth, alignment: .leading)
                .padding(.trailing, oppositeSideInset)
        } else {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.lg) {
                if shouldShowLiveWorkingStatus {
                    EvaLiveWorkingStatusView(statuses: activeWorkingStatuses)
                }

                if EvaThinkingVisibilityPolicy.showsVisibleThinking,
                   let thinking = renderModel.thinkingText {
                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                        thinkingLabel
                        if !collapsed, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: LifeBoardTheme.Spacing.md) {
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
                    }
                }

                if shouldShowTypingIndicator {
                    TypingIndicator()
                }
            }
            .padding(LifeBoardTheme.Spacing.lg)
            .lifeboardPremiumSurface(
                cornerRadius: 24,
                fillColor: EvaChatSunriseGlass.glassFill,
                strokeColor: EvaChatSunriseGlass.assistantBorder.opacity(0.72),
                accentColor: EvaChatSunriseGlass.primary,
                level: .e2,
                useNativeGlass: false
            )
            .frame(maxWidth: messageMaxWidth, alignment: .leading)
            .padding(.trailing, oppositeSideInset)
        }
    }

    var userBody: some View {
        Markdown(renderModel.displayContent)
            .textSelection(.enabled)
            .markdownTextStyle {
                ForegroundColor(Color.lifeboard(.accentOnPrimary))
            }
        #if os(iOS) || os(visionOS)
            .padding(.horizontal, LifeBoardTheme.Spacing.lg)
            .padding(.vertical, LifeBoardTheme.Spacing.md)
        #else
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        #endif
            .background(
                LinearGradient(
                    colors: [EvaChatSunriseGlass.primary, EvaChatSunriseGlass.primaryDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        #if os(iOS) || os(visionOS)
            .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
        #elseif os(macOS)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        #endif
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: EvaChatSunriseGlass.primary.opacity(0.16), radius: 12, x: 0, y: 6)
            .frame(maxWidth: messageMaxWidth, alignment: .trailing)
            .padding(.leading, oppositeSideInset)
    }

    @ViewBuilder
    func markdownText(_ text: String, color: Color) -> some View {
        if isLiveOutput && runtimeRunning {
            Text(text)
                .lifeboardFont(.body)
                .foregroundStyle(color)
                .textSelection(.enabled)
        } else {
            Markdown(text)
                .textSelection(.enabled)
                .markdownTextStyle {
                    ForegroundColor(color)
                }
                .id(renderModel.markdownSourceHash)
        }
    }

    @ViewBuilder
    func evidenceCitationRail(for text: String) -> some View {
        let citations = authorizedLifeEvidence.citations(in: text)
        if citations.isEmpty == false {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                Text("Evidence")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
        if let evaProposal = payload.evaProposal {
            evaProposalCardView(payload: payload, proposal: evaProposal)
        } else if let dayOverview = payload.dayOverview {
            dayOverviewCardView(payload: payload, overview: dayOverview)
        } else if payload.cardType == .commandResult, let commandResult = payload.commandResult {
            commandResultCardView(commandResult)
        } else {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                HStack(spacing: LifeBoardTheme.Spacing.sm) {
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
                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                        ForEach(Array(payload.diffLines.enumerated()), id: \.offset) { _, line in
                            Text("• \(line.text)")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(
                                    line.isDestructive ? Color.lifeboard(.statusDanger) : Color.lifeboard(.textPrimary)
                                )
                        }
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
                                undoEvaRun(runID, payloadRunID: payload.runID)
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
                        HStack(spacing: LifeBoardTheme.Spacing.sm) {
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
}
