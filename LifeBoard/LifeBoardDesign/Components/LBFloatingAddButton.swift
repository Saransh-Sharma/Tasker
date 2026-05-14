import SwiftUI

struct LBFloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background {
                    LinearGradient(
                        colors: [LBColorTokens.violetFill, LBColorTokens.sky],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Circle())
                }
                .overlay {
                    Circle()
                        .stroke(LBColorTokens.whiteStroke, lineWidth: 1)
                }
                .shadow(color: LBColorTokens.floatingShadow, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.addTaskButton")
        .accessibilityLabel("Add Task")
    }
}
