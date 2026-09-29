import SwiftUI

struct ReflectionNoteComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardTokens) private var tokens

    @ObservedObject var viewModel: ReflectionNoteComposerViewModel
    let onSaved: ((ReflectionNote) -> Void)?

    private var spacing: SemanticSpacingTokens { tokens.spacing }

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
                eyebrow: String(localized: "Note"),
                title: WeeklyCopy.reflectionTitle,
                subtitle: subtitle,
                weekRange: viewModel.title,
                steps: [
                    WeeklyRitualStep(id: 0, title: String(localized: "Prompt"), isComplete: viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
                    WeeklyRitualStep(id: 1, title: String(localized: "Note"), isComplete: viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
                    WeeklyRitualStep(id: 2, title: String(localized: "Save"), isComplete: false)
                ],
                message: viewModel.saveMessage,
                messageTone: .accent
            ) {
                WeeklySectionCard(title: String(localized: "Prompt")) {
                    reflectionField(
                        title: String(localized: "Optional"),
                        text: $viewModel.prompt,
                        lineLimit: 2...4
                    )
                }

                WeeklySectionCard(title: String(localized: "Note")) {
                    reflectionField(
                        title: String(localized: "Start writing…"),
                        text: $viewModel.noteText,
                        lineLimit: 4...8
                    )
                }

                WeeklySectionCard(title: String(localized: "Mood & energy")) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        signalSelector(title: String(localized: "Mood"), value: $viewModel.mood)
                        signalSelector(title: String(localized: "Energy"), value: $viewModel.energy)
                    }
                }
            } footer: {
                WeeklyStickyActionBar {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.lifeBoardChip)
                } trailing: {
                    Button(viewModel.isSaving ? "Saving…" : "Save note") {
                        viewModel.save { note in
                            onSaved?(note)
                            dismiss()
                        }
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
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

    /// What the note is saved with. The old subtitle narrated the act of
    /// writing; this states where the note goes.
    private var subtitle: String {
        switch viewModel.kind {
        case .taskCompletion: String(localized: "Saved with this task.")
        case .projectReflection: String(localized: "Saved with this project.")
        case .weeklyReview: String(localized: "Saved with this week.")
        case .habitRecovery: String(localized: "Saved with this habit.")
        default: String(localized: "The prompt is optional.")
        }
    }

    /// `title` is the field's placeholder; the card above it names the field.
    private func reflectionField(
        title: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        TextField(title, text: text, axis: .vertical)
            .lineLimit(lineLimit)
            .padding(12)
            .lifeboardDenseSurface(cornerRadius: 16, fillColor: Color.lifeboard.surfaceSecondary)
    }

    private func signalSelector(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { option in
                    let isSelected = value.wrappedValue == option
                    Button {
                        value.wrappedValue = option
                    } label: {
                        Text("\(option)")
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundStyle(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(option)")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}
