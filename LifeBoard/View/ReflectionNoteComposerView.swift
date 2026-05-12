import SwiftUI

struct ReflectionNoteComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    @ObservedObject var viewModel: ReflectionNoteComposerViewModel
    let onSaved: ((ReflectionNote) -> Void)?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        viewModel: ReflectionNoteComposerViewModel,
        onSaved: ((ReflectionNote) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            WeeklyRitualScaffold(
                eyebrow: "Reflection",
                title: WeeklyCopy.reflectionTitle,
                subtitle: "Capture one honest note while the signal is still clear.",
                weekRange: viewModel.title,
                steps: [
                    WeeklyRitualStep(id: 0, title: "Set the prompt", isComplete: viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
                    WeeklyRitualStep(id: 1, title: "Write the reflection", isComplete: viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
                    WeeklyRitualStep(id: 2, title: "Save it", isComplete: false)
                ],
                message: viewModel.saveMessage,
                messageTone: .accent
            ) {
                WeeklySectionCard(
                    title: "Set the prompt",
                    detail: "A short prompt keeps the note easier to understand when you read it later."
                ) {
                    reflectionField(
                        title: "Prompt",
                        helper: "Say what you are trying to notice or remember.",
                        text: $viewModel.prompt,
                        lineLimit: 2...4
                    )
                }

                WeeklySectionCard(
                    title: "Write the reflection",
                    detail: "Keep it concrete. What changed, what mattered, or what should not be forgotten?"
                ) {
                    reflectionField(
                        title: "Reflection",
                        helper: "Write what future-you would actually want to read.",
                        text: $viewModel.noteText,
                        lineLimit: 4...8
                    )
                }

                WeeklySectionCard(
                    title: "Add a quick signal",
                    detail: "Use these only as a quick read on how the work felt."
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        signalSelector(title: "Mood", value: $viewModel.mood)
                        signalSelector(title: "Energy", value: $viewModel.energy)
                    }
                }
            } footer: {
                WeeklyStickyActionBar {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                } trailing: {
                    Button(viewModel.isSaving ? "Saving..." : "Save reflection") {
                        viewModel.save { note in
                            onSaved?(note)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSave)
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .alert(WeeklyCopy.reflectionErrorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func reflectionField(
        title: String,
        helper: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)

            TextField(title, text: text, axis: .vertical)
                .lineLimit(lineLimit)
                .padding(12)
                .lifeboardDenseSurface(cornerRadius: 16, fillColor: Color.lifeboard.surfaceSecondary)

            Text(helper)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func signalSelector(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { option in
                    Button {
                        value.wrappedValue = option
                    } label: {
                        Text("\(option)")
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundStyle(value.wrappedValue == option ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(value.wrappedValue == option ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
