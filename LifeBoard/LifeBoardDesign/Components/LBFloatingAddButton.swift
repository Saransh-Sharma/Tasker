import SwiftUI

struct LBFloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.lifeboard(.primary, on: .accent))
                .frame(width: 58, height: 58)
                .background {
                    Circle().fill(Color.lifeboard(.accentSecondary))
                }
                .overlay {
                    Circle()
                        .stroke(Color.lifeboard(.surfacePrimary), lineWidth: 2)
                }
                .shadow(color: Color.lifeboard(.textPrimary).opacity(0.16), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.addTaskButton")
        .accessibilityLabel("Add Task")
    }
}
