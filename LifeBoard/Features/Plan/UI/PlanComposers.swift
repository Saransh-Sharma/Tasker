import SwiftUI
import UIKit

/// One set of defaults for a new time block, shared by Plan's block composer
/// and the capture tray's time-block host. They had drifted: one started at
/// 9:00 AM even when that was hours ago, one allowed 3 hours and the other 4,
/// and only one of them refused an empty title.
enum TimeBlockDraft {
    static let minuteRange: ClosedRange<Double> = 15...240
    static let minuteStep: Double = 15
    static let defaultMinutes: Double = 45

    /// Today: the next quarter hour. Any other day: 9 AM.
    static func defaultStart(on day: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        TaskWhenSelection.defaultStart(on: day, now: now, calendar: calendar)
    }

    static func isValid(title: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    static func durationLabel(minutes: Double) -> String {
        LifeBoardDuration.text(minutes: Int(minutes))
    }
}

/// The duration row both block composers share.
struct TimeBlockDurationField: View {
    @Binding var minutes: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Duration", value: TimeBlockDraft.durationLabel(minutes: minutes))
            Slider(value: $minutes, in: TimeBlockDraft.minuteRange, step: TimeBlockDraft.minuteStep)
                .accessibilityLabel("Duration")
                .accessibilityValue(TimeBlockDraft.durationLabel(minutes: minutes))
        }
    }
}

struct PlanBlockComposer: View {
    let day: PlanningDay
    let save: (String, Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start: Date
    @State private var minutes = TimeBlockDraft.defaultMinutes

    init(day: PlanningDay, save: @escaping (String, Date, TimeInterval) -> Void) {
        self.day = day
        self.save = save
        let base = day.startDate() ?? Date()
        _start = State(initialValue: TimeBlockDraft.defaultStart(on: base))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Block title", text: $title, prompt: Text("Block title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .accessibilityIdentifier("plan.block.title")
                DatePicker("Starts", selection: $start, displayedComponents: [.hourAndMinute])
                TimeBlockDurationField(minutes: $minutes)
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .navigationTitle("New time block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(title, start, minutes * 60); dismiss() }
                        .disabled(TimeBlockDraft.isValid(title: title) == false)
                        .accessibilityIdentifier("plan.block.add")
                }
            }
        }
        .escapeCancels { dismiss() }
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
                Section("Daily hours") {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                }
                Section("Buffer") {
                    Text(bufferMinutes < 1
                         ? String(localized: "No buffer")
                         : String(localized: "\(LifeBoardDuration.text(minutes: Int(bufferMinutes))) free each day"))
                    Slider(value: $bufferMinutes, in: 0...180, step: 15)
                        .accessibilityLabel("Buffer")
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .navigationTitle("Working hours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
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
        .escapeCancels { dismiss() }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }
}
