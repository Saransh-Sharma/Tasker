//
//  InboxViewController.swift
//  To Do List
//
//  Legacy storyboard surface modernized with Tasker tokens.
//

import UIKit

final class InboxViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var inboxTableView: UITableView!

    private let items: [String] = []
    private let emptyStateView = UIStackView()
    private let emptyStateIconView = UIImageView()
    private let emptyStateTitleLabel = UILabel()
    private let emptyStateBodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inbox"
        view.accessibilityIdentifier = "inbox.view"
        configureTableView()
        configureEmptyState()
        applyTheme()
        updateEmptyStateVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    private func configureTableView() {
        inboxTableView.delegate = self
        inboxTableView.dataSource = self
        inboxTableView.separatorStyle = .none
        inboxTableView.estimatedRowHeight = 64
        inboxTableView.rowHeight = UITableView.automaticDimension
        inboxTableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
        inboxTableView.register(UITableViewCell.self, forCellReuseIdentifier: "InboxCell")
    }

    private func configureEmptyState() {
        emptyStateView.axis = .vertical
        emptyStateView.alignment = .center
        emptyStateView.spacing = TaskerUIKitTokens.spacing.s8
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateIconView.image = UIImage(systemName: "tray")
        emptyStateIconView.tintColor = TaskerUIKitTokens.color.accentPrimary
        emptyStateIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: TaskerUIKitTokens.iconSize.hero,
            weight: .semibold
        )

        emptyStateTitleLabel.text = TaskerCopy.EmptyStates.legacyInboxTitle
        emptyStateTitleLabel.font = TaskerUIKitTokens.typography.title2
        emptyStateTitleLabel.textAlignment = .center

        emptyStateBodyLabel.text = TaskerCopy.EmptyStates.legacyInboxBody
        emptyStateBodyLabel.font = TaskerUIKitTokens.typography.body
        emptyStateBodyLabel.numberOfLines = 0
        emptyStateBodyLabel.textAlignment = .center

        emptyStateView.addArrangedSubview(emptyStateIconView)
        emptyStateView.addArrangedSubview(emptyStateTitleLabel)
        emptyStateView.addArrangedSubview(emptyStateBodyLabel)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
    }

    private func updateEmptyStateVisibility() {
        let showEmpty = items.isEmpty
        emptyStateView.isHidden = !showEmpty
        inboxTableView.isHidden = showEmpty
    }

    private func applyTheme() {
        let colors = TaskerUIKitTokens.color
        view.backgroundColor = colors.bgCanvas
        inboxTableView.backgroundColor = colors.bgCanvas
        emptyStateTitleLabel.textColor = colors.textPrimary
        emptyStateBodyLabel.textColor = colors.textSecondary
        emptyStateIconView.tintColor = colors.accentPrimary
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InboxCell", for: indexPath)
        let colors = TaskerUIKitTokens.color
        var content = cell.defaultContentConfiguration()
        content.text = items[indexPath.row]
        content.textProperties.font = TaskerUIKitTokens.typography.body
        content.textProperties.color = colors.textPrimary

        cell.contentConfiguration = content
        cell.backgroundColor = colors.surfacePrimary
        cell.layer.cornerRadius = TaskerUIKitTokens.corner.r2
        cell.layer.cornerCurve = .continuous
        cell.layer.masksToBounds = true
        cell.selectionStyle = .none
        return cell
    }
}
