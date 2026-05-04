//
//  DeviceNotSupportedView.swift
//
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var onDismiss: (() -> Void)? = nil
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    var body: some View {
        VStack(spacing: LifeBoardTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.lifeboard(.statusDanger).opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "iphone.slash")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.lifeboard(.statusDanger))
            }

            VStack(spacing: LifeBoardTheme.Spacing.sm) {
                Text("\(assistantIdentity.snapshot.displayName) isn't available on this device")
                    .font(.lifeboard(.title1))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.center)

                Text("\(assistantIdentity.snapshot.displayName)'s local model needs a newer Apple GPU feature set to run on-device.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                Text(String(localized: "eva.device_not_supported.why", defaultValue: "Why this happens"))
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text("This device does not support the local runtime \(assistantIdentity.snapshot.displayName) needs for private on-device responses.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(LifeBoardTheme.Spacing.lg)
            .lifeboardPremiumSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.xl,
                fillColor: Color.lifeboard(.surfacePrimary),
                strokeColor: Color.lifeboard(.strokeHairline),
                accentColor: Color.lifeboard(.statusDanger),
                level: .e1
            )
            .padding(.horizontal, LifeBoardTheme.Spacing.xl)

            if let onDismiss {
                Button(action: onDismiss) {
                    Text(String(localized: "eva.device_not_supported.dismiss", defaultValue: "Back"))
                        .font(.lifeboard(.button))
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.lifeboard(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, LifeBoardTheme.Spacing.xl)
            }

            Text("You can continue using LifeBoard as usual while \(assistantIdentity.snapshot.displayName) stays unavailable on this device.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textQuaternary))

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
