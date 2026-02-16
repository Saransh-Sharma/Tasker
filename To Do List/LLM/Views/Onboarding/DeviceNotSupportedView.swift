//
//  DeviceNotSupportedView.swift
//
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: TaskerTheme.Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.tasker(.statusDanger).opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "iphone.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color.tasker(.statusDanger))
            }

            VStack(spacing: TaskerTheme.Spacing.sm) {
                Text("device not supported")
                    .font(.tasker(.title1))
                    .foregroundColor(Color.tasker(.textPrimary))

                Text("sorry, Eva's on-device assistant can only run on devices that support Metal 3.")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TaskerTheme.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tasker(.bgCanvas))
    }
}

#Preview {
    DeviceNotSupportedView()
}
