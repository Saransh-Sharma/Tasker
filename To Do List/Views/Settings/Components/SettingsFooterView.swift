import SwiftUI

struct SettingsFooterView: View {
    let version: String
    let build: String

    var body: some View {
        Text("Tasker v\(version) (\(build))")
            .font(.tasker(.caption2))
            .foregroundColor(.tasker(.textQuaternary))
            .frame(maxWidth: .infinity)
            .padding(.top, TaskerSwiftUITokens.spacing.s16)
            .padding(.bottom, TaskerSwiftUITokens.spacing.s40)
    }
}
