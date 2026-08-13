import SwiftUI
import LifeBoardTokens
import LifeBoardUI

#if canImport(EventKitUI)
import UIKit
import EventKit
import EventKitUI

@MainActor
public struct EventKitEventDetailView: UIViewControllerRepresentable {
    public let eventID: String
    public let onDismiss: () -> Void
    public var showsCloseButton: Bool
    public var onHideFromTimeline: (() -> Void)?

    public init(
        eventID: String,
        onDismiss: @escaping () -> Void,
        showsCloseButton: Bool = true,
        onHideFromTimeline: (() -> Void)? = nil
    ) {
        self.eventID = eventID
        self.onDismiss = onDismiss
        self.showsCloseButton = showsCloseButton
        self.onHideFromTimeline = onHideFromTimeline
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            eventID: eventID,
            onDismiss: onDismiss,
            showsCloseButton: showsCloseButton,
            onHideFromTimeline: onHideFromTimeline
        )
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeController()
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.update(
            eventID: eventID,
            showsCloseButton: showsCloseButton,
            onHideFromTimeline: onHideFromTimeline
        )
    }

    @MainActor
    public final class Coordinator: NSObject, @preconcurrency EKEventViewDelegate {
        private let store = EKEventStore()
        private let onDismiss: () -> Void
        private var showsCloseButton: Bool
        private var onHideFromTimeline: (() -> Void)?
        private var eventID: String
        private weak var eventViewController: EKEventViewController?
        private weak var unavailableLabel: UILabel?

        init(
            eventID: String,
            onDismiss: @escaping () -> Void,
            showsCloseButton: Bool,
            onHideFromTimeline: (() -> Void)?
        ) {
            self.eventID = eventID
            self.onDismiss = onDismiss
            self.showsCloseButton = showsCloseButton
            self.onHideFromTimeline = onHideFromTimeline
        }

        func makeController() -> UINavigationController {
            let eventViewController = EKEventViewController()
            eventViewController.allowsEditing = false
            eventViewController.delegate = self

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
            applyCloseButtonIfNeeded()
            applyHideButtonIfNeeded()

            let navigationController = UINavigationController(rootViewController: eventViewController)
            navigationController.view.accessibilityIdentifier = "schedule.detail.sheet"
            return navigationController
        }

        func update(
            eventID: String,
            showsCloseButton: Bool,
            onHideFromTimeline: (() -> Void)?
        ) {
            self.eventID = eventID
            self.showsCloseButton = showsCloseButton
            self.onHideFromTimeline = onHideFromTimeline
            applyCurrentEvent()
            applyCloseButtonIfNeeded()
            applyHideButtonIfNeeded()
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

        private func applyCloseButtonIfNeeded() {
            guard showsCloseButton else {
                eventViewController?.navigationItem.leftBarButtonItem = nil
                return
            }
            let closeItem = UIBarButtonItem(
                title: String(localized: "Close"),
                style: .plain,
                target: self,
                action: #selector(closeTapped)
            )
            closeItem.accessibilityLabel = String(localized: "Close")
            closeItem.accessibilityIdentifier = "schedule.detail.close"
            eventViewController?.navigationItem.leftBarButtonItem = closeItem
        }

        private func applyHideButtonIfNeeded() {
            guard onHideFromTimeline != nil else {
                eventViewController?.navigationItem.rightBarButtonItem = nil
                return
            }
            let hideItem = UIBarButtonItem(
                image: UIImage(systemName: "eye.slash"),
                style: .plain,
                target: self,
                action: #selector(hideFromTimelineTapped)
            )
            hideItem.accessibilityLabel = String(localized: "Hide from Timeline")
            hideItem.accessibilityHint = String(localized: "Hides this event from the Home timeline for this day.")
            hideItem.accessibilityIdentifier = "schedule.detail.hideFromTimeline"
            eventViewController?.navigationItem.rightBarButtonItem = hideItem
        }

        @objc private func hideFromTimelineTapped() {
            onHideFromTimeline?()
        }

        public func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            _ = action
            onDismiss()
        }
    }
}
#else
public struct EventKitEventDetailView: View {
    public let eventID: String
    public let onDismiss: () -> Void
    public var showsCloseButton: Bool
    public var onHideFromTimeline: (() -> Void)?

    public init(
        eventID: String,
        onDismiss: @escaping () -> Void,
        showsCloseButton: Bool = true,
        onHideFromTimeline: (() -> Void)? = nil
    ) {
        self.eventID = eventID
        self.onDismiss = onDismiss
        self.showsCloseButton = showsCloseButton
        self.onHideFromTimeline = onHideFromTimeline
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(String(localized: "Event unavailable on this platform."))
                .font(.lifeboard(.body))
            Text(eventID)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textSecondary)
            if showsCloseButton {
                Button(String(localized: "Close"), action: onDismiss)
                    .accessibilityIdentifier("schedule.detail.close")
            }
            if let onHideFromTimeline {
                Button(action: onHideFromTimeline) {
                    Label(String(localized: "Hide from Timeline"), systemImage: "eye.slash")
                }
                .accessibilityHint(String(localized: "Hides this event from the Home timeline for this day."))
                .accessibilityIdentifier("schedule.detail.hideFromTimeline")
            }
        }
        .padding()
    }
}
#endif
