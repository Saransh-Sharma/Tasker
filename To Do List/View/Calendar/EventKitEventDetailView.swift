import SwiftUI
import UIKit

#if canImport(EventKitUI)
import EventKit
import EventKitUI

struct EventKitEventDetailView: UIViewControllerRepresentable {
    let eventID: String

    func makeCoordinator() -> Coordinator {
        Coordinator(eventID: eventID)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.update(eventID: eventID)
    }

    final class Coordinator: NSObject, EKEventViewDelegate {
        private let store = EKEventStore()
        private var eventID: String
        private weak var eventViewController: EKEventViewController?

        init(eventID: String) {
            self.eventID = eventID
        }

        func makeController() -> UINavigationController {
            let eventViewController = EKEventViewController()
            eventViewController.allowsEditing = false
            eventViewController.delegate = self
            eventViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
            self.eventViewController = eventViewController
            applyCurrentEvent()
            return UINavigationController(rootViewController: eventViewController)
        }

        func update(eventID: String) {
            self.eventID = eventID
            applyCurrentEvent()
        }

        private func applyCurrentEvent() {
            guard let eventViewController else { return }
            if let event = store.event(withIdentifier: eventID) {
                eventViewController.event = event
                eventViewController.title = event.title
            } else {
                eventViewController.event = nil
                eventViewController.title = "Event"
            }
        }

        @objc private func closeTapped() {
            eventViewController?.presentingViewController?.dismiss(animated: true)
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            _ = action
            controller.presentingViewController?.dismiss(animated: true)
        }
    }
}
#else
struct EventKitEventDetailView: View {
    let eventID: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Event details are unavailable on this platform.")
                .font(.tasker(.body))
            Text(eventID)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding()
    }
}
#endif
