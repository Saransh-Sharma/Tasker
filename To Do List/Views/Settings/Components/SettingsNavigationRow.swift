import SwiftUI

struct SettingsNavigationRow: View {
    let iconName: String
    let title: String
    var detailText: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            TaskerFeedback.light()
            action?()
        } label: {
            HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
                // Tinted icon circle
                ZStack {
                    Circle()
                        .fill(Color.tasker(.accentSecondaryWash))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconName)
                        .font(.tasker(.meta))
                        .foregroundColor(.tasker(.brandSecondary))
                }

                Text(title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(.tasker(.textPrimary))

                Spacer()

                if let detailText {
                    Text(detailText)
                        .font(.tasker(.callout))
                        .foregroundColor(.tasker(.textTertiary))
                }

                Image(systemName: "chevron.right")
                    .font(.tasker(.meta))
                    .foregroundColor(.tasker(.textQuaternary))
            }
            .padding(.vertical, TaskerSwiftUITokens.spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
