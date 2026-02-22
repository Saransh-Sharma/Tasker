//
//  WeeklyViewController.swift
//  To Do List
//
//  Legacy storyboard weekly surface modernized with Tasker tokens.
//

import UIKit

final class WeeklyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var weeklyTableView: UITableView!

    private let weeklyItems: [(day: String, summary: String)] = [
        ("Monday", "Plan top 3 priorities"),
        ("Tuesday", "Deep work block"),
        ("Wednesday", "Project checkpoint"),
        ("Thursday", "Follow-ups and clean-up"),
        ("Friday", "Weekly reflection")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Week"
        view.accessibilityIdentifier = "weekly.view"
        configureTableView()
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    private func configureTableView() {
        weeklyTableView.delegate = self
        weeklyTableView.dataSource = self
        weeklyTableView.separatorStyle = .none
        weeklyTableView.rowHeight = UITableView.automaticDimension
        weeklyTableView.estimatedRowHeight = 72
        weeklyTableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
        weeklyTableView.register(UITableViewCell.self, forCellReuseIdentifier: "WeeklyTaskCellModern")
    }

    private func applyTheme() {
        let colors = TaskerUIKitTokens.color
        view.backgroundColor = colors.bgCanvas
        weeklyTableView.backgroundColor = colors.bgCanvas
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        weeklyItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WeeklyTaskCellModern", for: indexPath)
        let item = weeklyItems[indexPath.row]
        let colors = TaskerUIKitTokens.color

        var content = cell.defaultContentConfiguration()
        content.text = item.day
        content.secondaryText = item.summary
        content.textProperties.font = TaskerUIKitTokens.typography.bodyEmphasis
        content.textProperties.color = colors.textPrimary
        content.secondaryTextProperties.font = TaskerUIKitTokens.typography.callout
        content.secondaryTextProperties.color = colors.textSecondary
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        cell.contentConfiguration = content

        cell.backgroundColor = colors.surfacePrimary
        cell.layer.cornerRadius = TaskerUIKitTokens.corner.r2
        cell.layer.cornerCurve = .continuous
        cell.layer.borderWidth = 1
        cell.layer.borderColor = colors.strokeHairline.cgColor
        cell.selectionStyle = .none
        return cell
    }
}
