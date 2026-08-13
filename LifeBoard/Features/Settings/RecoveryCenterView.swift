import SwiftUI

/// The screen a person opens when they are worried they have lost something.
///
/// Deliberately built from calm open rows rather than diagnostic cards: the
/// first job is to answer "is my work still there?", and a wall of status
/// tiles answers that badly. Technical detail is available, but it lives behind
/// the diagnostics action rather than in front of someone who is anxious.
///
/// Every rebuild offered here regenerates a *derived* surface only. Canonical
/// entries, tasks and notes are never touched, and the copy says so at the
/// point of action rather than in a help article.
struct RecoveryCenterView: View {
    @Environment(\.lifeboardTokens) private var tokens

    let status: RecoveryStatus
    /// Returns the human-readable outcome to announce when the work finishes.
    let onRecover: (RecoveryStatus.Recovery) async -> String
    let onExportDiagnostics: () -> Void

    @State private var runningRecovery: RecoveryStatus.Recovery?
    @State private var lastOutcome: String?

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.cardStackVertical) {
                headline

                ForEach(status.areas) { area in
                    areaRow(area)
                    if area.id != status.areas.last?.id {
                        Divider().overlay(Color.lifeboard.strokeHairline)
                    }
                }

                if let lastOutcome {
                    Text(lastOutcome)
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .accessibilityAddTraits(.updatesFrequently)
                        .padding(.top, 4)
                }

                diagnosticsRow
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.vertical, spacing.cardStackVertical)
        }
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.recoveryCenter")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(status.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Text("Checked \(status.generatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.footnote)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.recoveryCenter.headline")
    }

    @ViewBuilder
    private func areaRow(_ area: RecoveryStatus.Area) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                indicator(for: area.health)
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    Text(area.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let recovery = area.recovery {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recovery.reassurance)
                        .font(.footnote)
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        run(recovery)
                    } label: {
                        if runningRecovery == recovery {
                            HStack(spacing: 6) {
                                ProgressView()
                                Text("Rebuilding…")
                            }
                        } else {
                            Text(recovery.actionTitle)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(runningRecovery != nil)
                    .accessibilityIdentifier("settings.recoveryCenter.\(area.id).action")
                }
                .padding(.leading, 22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.recoveryCenter.area.\(area.id)")
    }

    /// Shape carries the state as well as color, so Differentiate Without Color
    /// still distinguishes healthy from degraded.
    private func indicator(for health: RecoveryStatus.Health) -> some View {
        Image(systemName: symbol(for: health))
            .font(.body)
            .foregroundStyle(tint(for: health))
            .accessibilityLabel(accessibilityLabel(for: health))
    }

    private func symbol(for health: RecoveryStatus.Health) -> String {
        switch health {
        case .healthy: return "checkmark.circle.fill"
        case .working: return "arrow.triangle.2.circlepath"
        case .attention: return "exclamationmark.circle"
        case .unavailable: return "pause.circle.fill"
        }
    }

    private func tint(for health: RecoveryStatus.Health) -> Color {
        switch health {
        case .healthy: return Color.lifeboard.statusSuccess
        case .working: return Color(SemanticColorTokens.inkSecondary)
        case .attention: return Color.lifeboard.statusWarning
        case .unavailable: return Color.lifeboard.statusWarning
        }
    }

    private func accessibilityLabel(for health: RecoveryStatus.Health) -> String {
        switch health {
        case .healthy: return "Ready"
        case .working: return "In progress"
        case .attention: return "Needs attention"
        case .unavailable: return "Paused"
        }
    }

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Color.lifeboard.strokeHairline)
            Button("Copy diagnostics", action: onExportDiagnostics)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings.recoveryCenter.diagnostics")
            Text("Operation names, counts and timings only. No titles, entries, health values or attachments.")
                .font(.footnote)
                .foregroundStyle(Color.lifeboard.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func run(_ recovery: RecoveryStatus.Recovery) {
        guard runningRecovery == nil else { return }
        runningRecovery = recovery
        lastOutcome = nil
        Task {
            let outcome = await onRecover(recovery)
            await MainActor.run {
                runningRecovery = nil
                lastOutcome = outcome
            }
        }
    }
}
