import SwiftUI

struct SettingsFooterView: View {
    var body: some View {
        Text("Made with care by Saransh")
            .font(.lifeboard(.caption2))
            .foregroundColor(.lifeboard(.textQuaternary))
        .frame(maxWidth: .infinity)
        .padding(.top, LifeBoardSwiftUITokens.spacing.s24)
        .padding(.bottom, LifeBoardSwiftUITokens.spacing.s40)
    }
}
