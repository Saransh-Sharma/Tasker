import SwiftUI

/// What a root asked Eva to look at when it presented her as a sheet. The
/// shell keeps the request; the chat consumes the matching launch request.
struct EvaSheetRequest: Identifiable, Equatable {
    let id: UUID
    let context: EvaLaunchContext?

    init(id: UUID = UUID(), context: EvaLaunchContext?) {
        self.id = id
        self.context = context
    }
}

/// Eva over whichever root is showing. The atmosphere environment does not
/// cross a sheet boundary, so the snapshot is read again inside; the content
/// is the same `EvaDestination` the Eva tab renders, so nothing is duplicated
/// and dismissing returns to the root with its state intact (roots are cached).
struct EvaSheetHost: View {
    let request: EvaSheetRequest
    let onClose: () -> Void
    let content: () -> AnyView

    var body: some View {
        PresentationScaffold(mode: .focused, readableWidth: 720) {
            AtmosphereSnapshotReader { _ in
                content()
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Label(request.context?.title ?? AssistantIdentitySnapshot.current.displayName, systemImage: "sparkles")
                        .lifeboardFont(.bodyStrong)
                        .lineLimit(1)
                    Spacer()
                    Button("Close", action: onClose)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("eva.sheet.close")
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.sm)
                .lifeBoardSystemGlass(.regular, in: Rectangle())
            }
        }
        // Full height only: at the medium detent the composer sat mid-screen
        // and the keyboard covered the conversation it was replying to.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.sheet")
    }
}
