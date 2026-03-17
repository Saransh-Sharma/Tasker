import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var includeHorizontalPadding: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
            Text(title)
                .font(.tasker(.title3))
                .fontWeight(.bold)
                .foregroundColor(.tasker(.textPrimary))

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.tasker(.callout))
                    .foregroundColor(.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, includeHorizontalPadding ? TaskerSwiftUITokens.spacing.screenHorizontal : 0)
    }
}
