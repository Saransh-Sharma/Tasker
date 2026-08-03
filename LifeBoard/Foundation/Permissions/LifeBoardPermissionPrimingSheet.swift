import HealthKit
import SwiftUI
import UIKit

// MARK: - Priming sheet

/// The single host for every permission invitation. Apple Health keeps its own
/// richer body — it is the one kind with a per-domain sharing choice — while the
/// rest share one compact clay sheet, so the ask always reads the same way.
public struct LifeBoardPermissionPrimingSheet: View {
    public let prompt: LifeBoardPermissionPrompt
    public let onGrant: (Set<HealthDomain>) -> Void
    public let onDecline: () -> Void

    public init(
        prompt: LifeBoardPermissionPrompt,
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
        VStack(spacing: 20) {
            Image(systemName: prompt.kind.symbolName)
                .font(.largeTitle)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 64, height: 64)
                .lifeBoardClaySurface(.well, cornerRadius: 20)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(prompt.kind.title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(prompt.kind.blurb)
                    .font(.subheadline)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Button(prompt.kind.allowTitle) { onGrant([]) }
                    .buttonStyle(.lifeBoardPrimary)
                Button("Not now") { onDecline() }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("permission.priming.\(prompt.kind.rawValue)")
    }
}

// MARK: - Denied recovery

/// Shown in place of a feature when iOS has recorded a denial. There is nothing
/// the app can do at that point but explain and open Settings — this is the one
/// place that says so, replacing four separate hand-rolled copies of the same
/// `openSettingsURLString` dance.
public struct LifeBoardPermissionRecoveryCard: View {
    public let kind: LifeBoardPermissionKind
    public let detail: String?

    public init(kind: LifeBoardPermissionKind, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.lifeboard(.textPrimary))

            Text(detail ?? kind.blurb)
                .font(.footnote)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") { LifeBoardPermissionRecoveryCard.openSystemSettings() }
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
