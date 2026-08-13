import SwiftUI
import UIKit

struct PlanBlockComposer: View {
    let day: PlanningDay
    let save: (String, Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start: Date
    @State private var minutes = 45.0

    init(day: PlanningDay, save: @escaping (String, Date, TimeInterval) -> Void) {
        self.day = day
        self.save = save
        let base = day.startDate() ?? Date()
        _start = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Block title", text: $title)
                    .accessibilityIdentifier("plan.block.title")
                DatePicker("Starts", selection: $start, displayedComponents: [.hourAndMinute])
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(minutes)) minutes")
                    Slider(value: $minutes, in: 15...180, step: 15)
                }
            }
            .navigationTitle("New time block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(title, start, minutes * 60); dismiss() }
                        .accessibilityIdentifier("plan.block.add")
                }
            }
        }
        .accessibilityIdentifier("plan.block.composer")
    }
}

struct PlanWorkingHoursComposer: View {
    let save: (Set<Int>, Int, Int, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var activeWeekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var bufferMinutes: Double

    init(profile: WorkingHoursProfile?, save: @escaping (Set<Int>, Int, Int, TimeInterval) -> Void) {
        self.save = save
        let intervals = profile?.intervalsByWeekday ?? [:]
        let first = intervals.values.flatMap { $0 }.first ?? WorkingHoursInterval(startMinute: 8 * 60, endMinute: 18 * 60)
        let base = Calendar.current.startOfDay(for: Date())
        _activeWeekdays = State(initialValue: Set(intervals.keys.isEmpty ? Array(2...6) : Array(intervals.keys)))
        _start = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.startMinute, to: base) ?? base)
        _end = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.endMinute, to: base) ?? base.addingTimeInterval(10 * 3_600))
        _bufferMinutes = State(initialValue: (profile?.bufferDuration ?? 30 * 60) / 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Working days") {
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                if activeWeekdays.contains(weekday) { activeWeekdays.remove(weekday) }
                                else { activeWeekdays.insert(weekday) }
                            } label: {
                                Text(weekdayLabel(weekday))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(activeWeekdays.contains(weekday) ? Color(SemanticColorTokens.foundationSurfaceSelected) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(activeWeekdays.contains(weekday) ? .isSelected : [])
                        }
                    }
                }
                Section("Daily window") {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                }
                Section("Protected buffer") {
                    Text("\(Int(bufferMinutes)) minutes remains unallocated.")
                    Slider(value: $bufferMinutes, in: 0...180, step: 15)
                }
            }
            .navigationTitle("Working hours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startMinute = Calendar.current.component(.hour, from: start) * 60 + Calendar.current.component(.minute, from: start)
                        let endMinute = Calendar.current.component(.hour, from: end) * 60 + Calendar.current.component(.minute, from: end)
                        save(activeWeekdays, startMinute, endMinute, bufferMinutes * 60)
                        dismiss()
                    }
                    .disabled(activeWeekdays.isEmpty)
                }
            }
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }
}
