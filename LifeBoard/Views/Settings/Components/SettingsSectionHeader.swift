import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var includeHorizontalPadding: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
            Text(title)
                .font(.lifeboard(.title3))
                .fontWeight(.bold)
                .foregroundColor(.lifeboard(.textPrimary))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundColor(.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, includeHorizontalPadding ? LifeBoardSwiftUITokens.spacing.screenHorizontal : 0)
    }
}
