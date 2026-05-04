import SwiftUI

struct SettingsFooterView: View {
    var body: some View {
        Text("Made with care by Saransh")
            .font(.tasker(.caption2))
            .foregroundColor(.tasker(.textQuaternary))
        .frame(maxWidth: .infinity)
        .padding(.top, TaskerSwiftUITokens.spacing.s24)
        .padding(.bottom, TaskerSwiftUITokens.spacing.s40)
    }
}
