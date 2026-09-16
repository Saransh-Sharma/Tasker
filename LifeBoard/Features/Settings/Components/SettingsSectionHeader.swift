import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var includeHorizontalPadding: Bool = true

    var body: some View {
        // Built on the shared `SectionHeader` rather than its own bold title3:
        // Settings had the only section headers in the product at a different
        // size, and `DESIGN.md` calls an individually restyled header a defect.
        // The subtitle stays as a separate line below it, which is where the
        // header contract puts supporting copy.
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
            SectionHeader(title)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundColor(.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, includeHorizontalPadding ? SwiftUITokens.spacing.screenHorizontal : 0)
    }
}
