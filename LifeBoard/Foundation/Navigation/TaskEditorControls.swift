import SwiftUI
import UIKit

/// The controls every section of the task editor shares.
///
/// Static rather than a `View`: these are one-line wrappers whose whole value
/// is that the three editor sections spell an optional date the same way.
@MainActor
enum TaskEditorControls {
    static func optionalDate(
        _ title: String,
        value: Binding<Date?>,
        components: DatePickerComponents = .date
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: Binding(
                get: { value.wrappedValue != nil },
                set: { value.wrappedValue = $0 ? (value.wrappedValue ?? Date()) : nil }
            ))
            if value.wrappedValue != nil {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { value.wrappedValue ?? Date() },
                        set: { value.wrappedValue = $0 }
                    ),
                    displayedComponents: components
                )
                .labelsHidden()
            }
        }
    }

    static func optionalPlanningDay(
        _ title: String,
        value: Binding<PlanningDay?>
    ) -> some View {
        optionalDate(
            title,
            value: Binding(
                get: { value.wrappedValue?.startDate() },
                set: { date in
                    value.wrappedValue = date.map { PlanningDay(date: $0) }
                }
            )
        )
    }

    static func header(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }}
