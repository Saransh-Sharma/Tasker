//
//  DeviceNotSupportedView.swift
//
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var onDismiss: (() -> Void)? = nil
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.lifeboard(.statusDanger).opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "iphone.slash")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(Color.lifeboard(.statusDanger))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("This device can’t run \(assistantIdentity.snapshot.displayName) offline")
                    .font(.lifeboard(.title1))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.center)

                Text("\(assistantIdentity.snapshot.displayName) in the cloud still works.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(String(localized: "eva.device_not_supported.why", defaultValue: "Why this happens"))
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text("Offline models need a newer Apple chip.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(Theme.Spacing.lg)
            .lifeboardPremiumSurface(
                cornerRadius: Theme.CornerRadius.xl,
                fillColor: Color.lifeboard(.surfacePrimary),
                strokeColor: Color.lifeboard(.strokeHairline),
                accentColor: Color.lifeboard(.statusDanger),
                level: .e1
            )
            .padding(.horizontal, Theme.Spacing.xl)

            if let onDismiss {
                Button(action: onDismiss) {
                    Text(String(localized: "eva.device_not_supported.dismiss", defaultValue: "Back"))
                        .font(.lifeboard(.button))
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.lifeboard(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lifeboard(.bgCanvas))
    }
}

#Preview("Default") {
    DeviceNotSupportedView()
}

#Preview("Dismissible") {
    DeviceNotSupportedView(onDismiss: {})
}
