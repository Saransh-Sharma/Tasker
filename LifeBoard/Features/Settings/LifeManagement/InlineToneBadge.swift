import SwiftUI
import UIKit

struct InlineToneBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard(.accentPrimary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.lifeboard(.accentWash))
            )
    }
}
