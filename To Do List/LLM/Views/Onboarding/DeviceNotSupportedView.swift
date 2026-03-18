//
//  DeviceNotSupportedView.swift
//
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: TaskerTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.tasker(.statusDanger).opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "iphone.slash")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.tasker(.statusDanger))
            }

            VStack(spacing: TaskerTheme.Spacing.sm) {
                Text("Eva isn't available on this device")
                    .font(.tasker(.title1))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .multilineTextAlignment(.center)

                Text("Eva's local model needs a newer Apple GPU feature set to run on-device.")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                Text("Why this happens")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text("This device does not support the local runtime Eva needs for private on-device responses.")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }
            .padding(TaskerTheme.Spacing.lg)
            .taskerPremiumSurface(
                cornerRadius: TaskerTheme.CornerRadius.xl,
                fillColor: Color.tasker(.surfacePrimary),
                strokeColor: Color.tasker(.strokeHairline),
                accentColor: Color.tasker(.statusDanger),
                level: .e1
            )
            .padding(.horizontal, TaskerTheme.Spacing.xl)

            if let onDismiss {
                Button(action: onDismiss) {
                    Text("Back")
                        .font(.tasker(.button))
                        .foregroundStyle(Color.tasker(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.tasker(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, TaskerTheme.Spacing.xl)
            }

            Text("You can still use the rest of Tasker normally.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textQuaternary))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tasker(.bgCanvas))
    }
}

#Preview {
    DeviceNotSupportedView()
}
