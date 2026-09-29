import HealthKit
import SwiftUI
import UIKit

// MARK: - Priming sheet

/// The single host for every permission invitation. Apple Health keeps its own
/// richer body — it is the one kind with a per-domain sharing choice — while the
/// rest share one compact clay sheet, so the ask always reads the same way.
public struct PermissionPrimingSheet: View {
    public let prompt: PermissionPrompt
    public let onGrant: (Set<HealthDomain>) -> Void
    public let onDecline: () -> Void

    public init(
        prompt: PermissionPrompt,
        onGrant: @escaping (Set<HealthDomain>) -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.onGrant = onGrant
        self.onDecline = onDecline
    }

    public var body: some View {
        switch prompt.kind {
        case .appleHealth:
            HealthConnectPromptSheet(
                leadDomain: prompt.leadHealthDomain ?? .hydration,
                onConnect: onGrant,
                onDecline: onDecline
            )
        default:
            compactSheet
        }
    }

    private var compactSheet: some View {
        // Content-sized, not a fixed height: at large text sizes a 330pt sheet
        // clipped the title and pushed the buttons off the bottom. The body
        // scrolls when it outgrows the medium detent.
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: prompt.kind.symbolName)
                    .lifeboardFont(.title1)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 64, height: 64)
                    .lifeBoardClaySurface(.well, cornerRadius: 20)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(prompt.kind.title)
                        .lifeboardFont(.title3)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .multilineTextAlignment(.center)
                    Text(prompt.kind.blurb)
                        .lifeboardFont(.callout)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    Button(prompt.kind.allowTitle) { onGrant([]) }
                        .buttonStyle(.lifeBoardPrimary)
                    Button("Not now") { onDecline() }
                        .lifeboardFont(.callout)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("permission.priming.\(prompt.kind.rawValue)")
    }
}

// MARK: - Denied recovery

/// Shown in place of a feature when iOS has recorded a denial. There is nothing
/// the app can do at that point but explain and open Settings — this is the one
/// place that says so, replacing four separate hand-rolled copies of the same
/// `openSettingsURLString` dance.
public struct PermissionRecoveryCard: View {
    public let kind: PermissionKind
    public let detail: String?

    public init(kind: PermissionKind, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(kind.title, systemImage: kind.symbolName)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))

            Text(detail ?? kind.blurb)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") { PermissionRecoveryCard.openSystemSettings() }
                .buttonStyle(.lifeBoardChip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lifeBoardClaySurface(.resting)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("permission.recovery.\(kind.rawValue)")
    }

    /// The one sanctioned route to the app's Settings page.
    @MainActor
    public static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
