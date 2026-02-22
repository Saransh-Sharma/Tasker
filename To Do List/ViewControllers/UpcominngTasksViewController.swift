//
//  UpcominngTasksViewController.swift
//  To Do List
//
//  Legacy upcoming surface modernized and retained.
//

import UIKit

final class UpcominngTasksViewController: UIViewController {
    private let emptyStateStack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Upcoming"
        view.accessibilityIdentifier = "upcoming.view"
        configureEmptyState()
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    private func configureEmptyState() {
        emptyStateStack.axis = .vertical
        emptyStateStack.alignment = .center
        emptyStateStack.spacing = TaskerUIKitTokens.spacing.s8
        emptyStateStack.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: "calendar.badge.clock")
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: TaskerUIKitTokens.iconSize.hero,
            weight: .semibold
        )

        titleLabel.text = TaskerCopy.EmptyStates.legacyUpcomingTitle
        titleLabel.font = TaskerUIKitTokens.typography.title2
        titleLabel.textAlignment = .center

        bodyLabel.text = TaskerCopy.EmptyStates.legacyUpcomingBody
        bodyLabel.font = TaskerUIKitTokens.typography.body
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        emptyStateStack.addArrangedSubview(iconView)
        emptyStateStack.addArrangedSubview(titleLabel)
        emptyStateStack.addArrangedSubview(bodyLabel)
        view.addSubview(emptyStateStack)

        NSLayoutConstraint.activate([
            emptyStateStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            emptyStateStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
    }

    private func applyTheme() {
        let colors = TaskerUIKitTokens.color
        view.backgroundColor = colors.bgCanvas
        iconView.tintColor = colors.accentPrimary
        titleLabel.textColor = colors.textPrimary
        bodyLabel.textColor = colors.textSecondary
    }
}
