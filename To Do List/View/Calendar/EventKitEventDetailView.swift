import SwiftUI
import UIKit

#if canImport(EventKitUI)
import EventKit
import EventKitUI

struct EventKitEventDetailView: UIViewControllerRepresentable {
    let eventID: String
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(eventID: eventID, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.update(eventID: eventID)
    }

    final class Coordinator: NSObject, EKEventViewDelegate {
        private let store = EKEventStore()
        private let onDismiss: () -> Void
        private var eventID: String
        private weak var eventViewController: EKEventViewController?
        private weak var unavailableLabel: UILabel?

        init(eventID: String, onDismiss: @escaping () -> Void) {
            self.eventID = eventID
            self.onDismiss = onDismiss
        }

        func makeController() -> UINavigationController {
            let eventViewController = EKEventViewController()
            eventViewController.allowsEditing = false
            eventViewController.delegate = self

            let closeControl = UIButton(type: .system)
            closeControl.setTitle(String(localized: "Close"), for: .normal)
            closeControl.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            closeControl.isAccessibilityElement = true
            closeControl.accessibilityLabel = String(localized: "Close")
            closeControl.accessibilityIdentifier = "schedule.detail.close"
            closeControl.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            eventViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeControl)

            let unavailableLabel = UILabel()
            unavailableLabel.translatesAutoresizingMaskIntoConstraints = false
            unavailableLabel.text = String(localized: "This event is no longer available.")
            unavailableLabel.font = UIFont.preferredFont(forTextStyle: .body)
            unavailableLabel.textColor = .secondaryLabel
            unavailableLabel.numberOfLines = 0
            unavailableLabel.textAlignment = .center
            unavailableLabel.isHidden = true
            unavailableLabel.accessibilityIdentifier = "schedule.detail.unavailable"
            eventViewController.view.addSubview(unavailableLabel)
            NSLayoutConstraint.activate([
                unavailableLabel.centerXAnchor.constraint(equalTo: eventViewController.view.centerXAnchor),
                unavailableLabel.centerYAnchor.constraint(equalTo: eventViewController.view.centerYAnchor),
                unavailableLabel.leadingAnchor.constraint(greaterThanOrEqualTo: eventViewController.view.leadingAnchor, constant: 24),
                unavailableLabel.trailingAnchor.constraint(lessThanOrEqualTo: eventViewController.view.trailingAnchor, constant: -24)
            ])

            self.eventViewController = eventViewController
            self.unavailableLabel = unavailableLabel
            applyCurrentEvent()

            let navigationController = UINavigationController(rootViewController: eventViewController)
            navigationController.view.accessibilityIdentifier = "schedule.detail.sheet"
            return navigationController
        }

        func update(eventID: String) {
            self.eventID = eventID
            applyCurrentEvent()
        }

        private func applyCurrentEvent() {
            guard let eventViewController else { return }

            if let event = store.event(withIdentifier: eventID) {
                eventViewController.event = event
                let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                eventViewController.title = title?.isEmpty == false ? title : String(localized: "Untitled Event")
                unavailableLabel?.isHidden = true
            } else {
                eventViewController.event = nil
                eventViewController.title = String(localized: "Event unavailable")
                unavailableLabel?.isHidden = false
            }
        }

        @objc private func closeTapped() {
            onDismiss()
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            _ = action
            onDismiss()
        }
    }
}
#else
struct EventKitEventDetailView: View {
    let eventID: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(String(localized: "Event unavailable on this platform."))
                .font(.tasker(.body))
            Text(eventID)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
            Button(String(localized: "Close"), action: onDismiss)
        }
        .padding()
    }
}
#endif
