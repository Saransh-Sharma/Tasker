import SwiftUI
import UIKit

#if canImport(EventKitUI)
import EventKit
import EventKitUI

struct EventKitCalendarChooserSheet: UIViewControllerRepresentable {
    let initialSelectedCalendarIDs: [String]
    let onCancel: () -> Void
    let onCommit: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            initialSelectedCalendarIDs: Set(initialSelectedCalendarIDs),
            onCancel: onCancel,
            onCommit: onCommit
        )
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.updateSelection()
    }

    final class Coordinator: NSObject, EKCalendarChooserDelegate {
        private let initialSelectedCalendarIDs: Set<String>
        private let onCancel: () -> Void
        private let onCommit: ([String]) -> Void
        private let eventStore = EKEventStore()
        private weak var chooser: EKCalendarChooser?

        init(
            initialSelectedCalendarIDs: Set<String>,
            onCancel: @escaping () -> Void,
            onCommit: @escaping ([String]) -> Void
        ) {
            self.initialSelectedCalendarIDs = initialSelectedCalendarIDs
            self.onCancel = onCancel
            self.onCommit = onCommit
        }

        func makeController() -> UINavigationController {
            let chooser = EKCalendarChooser(
                selectionStyle: .multiple,
                displayStyle: .allCalendars,
                entityType: .event,
                eventStore: eventStore
            )
            chooser.showsDoneButton = true
            chooser.showsCancelButton = true
            chooser.delegate = self
            chooser.title = "Calendars"
            self.chooser = chooser
            updateSelection()

            let nav = UINavigationController(rootViewController: chooser)
            return nav
        }

        func updateSelection() {
            guard let chooser else { return }
            let selectedCalendars = eventStore.calendars(for: .event)
                .filter { initialSelectedCalendarIDs.contains($0.calendarIdentifier) }
            chooser.selectedCalendars = Set(selectedCalendars)
        }

        func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
            let selectedIDs = calendarChooser.selectedCalendars.map(\.calendarIdentifier).sorted()
            onCommit(selectedIDs)
        }

        func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
            onCancel()
        }
    }
}

struct EventKitCalendarChooserContainerView: View {
    let initialSelectedCalendarIDs: [String]
    let onCommit: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EventKitCalendarChooserSheet(
            initialSelectedCalendarIDs: initialSelectedCalendarIDs,
            onCancel: {
                dismiss()
            },
            onCommit: { selectedIDs in
                onCommit(selectedIDs)
                dismiss()
            }
        )
    }
}
#else
struct EventKitCalendarChooserSheet: View {
    let initialSelectedCalendarIDs: [String]
    let onCancel: () -> Void
    let onCommit: ([String]) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Calendar selection is unavailable on this platform.")
                .font(.tasker(.body))
            Button("Close") {
                onCancel()
            }
        }
        .padding()
    }
}

struct EventKitCalendarChooserContainerView: View {
    let initialSelectedCalendarIDs: [String]
    let onCommit: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EventKitCalendarChooserSheet(
            initialSelectedCalendarIDs: initialSelectedCalendarIDs,
            onCancel: {
                dismiss()
            },
            onCommit: { selectedIDs in
                onCommit(selectedIDs)
                dismiss()
            }
        )
    }
}
#endif
