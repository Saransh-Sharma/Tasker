import SwiftUI

struct SetupCenterDisclosureCard<Content: View>: View {
    let snapshot: SetupCenterIntegrationSnapshot
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { identity; Spacer(minLength: 8); status }
                    VStack(alignment: .leading, spacing: 10) { identity; status }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setupCenter.\(snapshot.integration.rawValue).expand")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                Divider().overlay(Color.lifeboard(.strokeHairline)).padding(.vertical, 14)
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.largeCard)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setupCenter.\(snapshot.integration.rawValue)")
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsRowIcon(iconName: snapshot.integration.symbolName, tone: snapshot.state.tone)
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.integration.title)
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(snapshot.integration.benefit)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var status: some View {
        HStack(spacing: 6) {
            Image(systemName: snapshot.state.symbolName)
            Text(snapshot.status)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .accessibilityHidden(true)
        }
        .lifeboardFont(.caption1)
        .foregroundStyle(Color.lifeboard(.textSecondary))
        .accessibilityIdentifier("setupCenter.\(snapshot.integration.rawValue).status")
    }
}

struct SetupCenterPrimaryAction: View {
    let title: String
    let identifier: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.lifeBoardPrimary)
            .disabled(!isEnabled)
            .accessibilityIdentifier(identifier)
    }
}

struct SetupCenterEvaGrantsSection: View {
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud EVA receives only the categories you enable below. Health data stays on-device unless Health is separately granted here.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(grants, id: \.grant) { entry in
                Toggle(entry.title, isOn: entry.isOn)
                    .toggleStyle(.lifeBoardClay)
                    .accessibilityIdentifier("setupCenter.eva.grant.\(entry.grant.rawValue)")
            }
        }
    }
}

private extension SetupCenterIntegration {
    var title: String {
        switch self { case .calendar: "Calendar"; case .health: "Apple Health"; case .eva: "EVA" }
    }
    var symbolName: String {
        switch self { case .calendar: "calendar"; case .health: "heart.text.square.fill"; case .eva: "sparkles" }
    }
    var benefit: String {
        switch self {
        case .calendar: "Plan around the events already shaping your day."
        case .health: "Use private, on-device wellness context."
        case .eva: "Choose Cloud intelligence or an on-device model."
        }
    }
}
