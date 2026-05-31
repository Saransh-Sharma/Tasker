//
//  RescheduleViewController.swift
//  LifeBoard
//

import UIKit

final class RescheduleViewController: UIViewController {
    private let taskTitle: String
    private let onDateSelected: (Date) -> Void
    private let datePicker = UIDatePicker()

    /// Initializes a new instance.
    init(taskTitle: String, currentDueDate: Date?, onDateSelected: @escaping (Date) -> Void) {
        self.taskTitle = taskTitle
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
        datePicker.date = currentDueDate ?? Date()
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        title = "Reschedule"

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        view.addSubview(datePicker)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )

        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        onDateSelected(datePicker.date)
        dismiss(animated: true)
    }
}
