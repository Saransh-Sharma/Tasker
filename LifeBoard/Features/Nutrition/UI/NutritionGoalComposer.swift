import SwiftUI

/// Sets the daily nutrition target.
///
/// `NutritionGoal` had a Core Data entity, a repository write, and a read into
/// the timeline store — but no way anywhere in the app to create one, so the
/// value was permanently nil and every nutrition surface had nothing to measure
/// against. This is the missing editor.
struct NutritionGoalComposer: View {
    let existing: NutritionGoal?
    let onSave: (NutritionMacros) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var calories: Double
    @State private var protein: Double
    @State private var carbohydrate: Double
    @State private var fat: Double

    init(existing: NutritionGoal?, onSave: @escaping (NutritionMacros) -> Void) {
        self.existing = existing
        self.onSave = onSave
        // Defaults are a neutral starting point, not a recommendation — LifeBoard
        // does not give dietary advice.
        _calories = State(initialValue: existing?.targetMacros.calories ?? 2_000)
        _protein = State(initialValue: existing?.targetMacros.proteinGrams ?? 100)
        _carbohydrate = State(initialValue: existing?.targetMacros.carbohydrateGrams ?? 225)
        _fat = State(initialValue: existing?.targetMacros.fatGrams ?? 65)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily target") {
                    row("Energy", value: $calories, unit: "kcal", step: 50)
                    row("Protein", value: $protein, unit: "g", step: 5)
                    row("Carbs", value: $carbohydrate, unit: "g", step: 5)
                    row("Fat", value: $fat, unit: "g", step: 5)
                }

                Section {
                    Text("Used to show progress.")
                        .font(.footnote)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .lifeBoardFormSurface()
            .navigationTitle(existing == nil ? String(localized: "Set target") : String(localized: "Edit target"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("nutrition.goal.save")
                }
            }
        }
    }

    private func row(_ title: String, value: Binding<Double>, unit: String, step: Double) -> some View {
        Stepper(value: value, in: 0...10_000, step: step) {
            HStack {
                Text(title)
                Spacer()
                // A field as well as the stepper: reaching 2,000 kcal by
                // stepping was forty clicks on a Mac, with no way to type it.
                TextField(title, value: value, format: .number.precision(.fractionLength(0)))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .fixedSize()
                    .padKeyboard(.numberPad)
                    .accessibilityLabel("\(title) in \(unit)")
                Text(unit)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .sensoryFeedback(.selection, trigger: value.wrappedValue)
        .accessibilityIdentifier("nutrition.goal.\(title.lowercased())")
    }

    private func save() {
        guard let macros = try? NutritionMacros(
            calories: calories,
            proteinGrams: protein,
            carbohydrateGrams: carbohydrate,
            fatGrams: fat
        ) else { return }
        onSave(macros)
        dismiss()
    }
}
