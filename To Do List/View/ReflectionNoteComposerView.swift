import SwiftUI

struct ReflectionNoteComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReflectionNoteComposerViewModel
    let onSaved: ((ReflectionNote) -> Void)?

    init(
        viewModel: ReflectionNoteComposerViewModel,
        onSaved: ((ReflectionNote) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Context") {
                    TextField("Prompt", text: $viewModel.prompt, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Reflection") {
                    TextField("What changed, what mattered, or what to remember", text: $viewModel.noteText, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Signal") {
                    Stepper("Mood: \(viewModel.mood)/5", value: $viewModel.mood, in: 1...5)
                    Stepper("Energy: \(viewModel.energy)/5", value: $viewModel.energy, in: 1...5)
                }
            }
            .navigationTitle(viewModel.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        viewModel.save { note in
                            onSaved?(note)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .overlay(alignment: .bottom) {
                if let saveMessage = viewModel.saveMessage {
                    Text(saveMessage)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                }
            }
            .alert("Reflection error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
