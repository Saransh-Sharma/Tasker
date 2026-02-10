//
//  DeviceNotSupportedView.swift
//
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.tasker(.display))
                .foregroundStyle(.primary, .tertiary)
            
            VStack(spacing: 4) {
                Text("device not supported")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("sorry, on device assistant can only run on devices that support Metal 3.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    DeviceNotSupportedView()
}
