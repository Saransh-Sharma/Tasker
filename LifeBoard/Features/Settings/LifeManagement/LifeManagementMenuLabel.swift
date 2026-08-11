import SwiftUI
import UIKit

struct LifeManagementMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .lifeboardFont(.title2)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(title))
    }
}
