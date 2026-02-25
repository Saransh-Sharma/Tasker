import SwiftUI

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.tasker(.title2))
            .foregroundColor(.tasker(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TaskerSwiftUITokens.spacing.screenHorizontal)
    }
}
