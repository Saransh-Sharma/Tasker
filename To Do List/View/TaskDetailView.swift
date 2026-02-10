import UIKit

class TaskDetailView: UIView {
    // MARK: – Subviews
    private let card = UIView()
    private let titleField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter title"
        tf.font = .tasker.bodyEmphasis
        return tf
    }()
    private let descriptionField: UITextView = {
        let tv = UITextView()
        tv.isScrollEnabled = true
        return tv
    }()
    private let dueDatePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .dateAndTime
        return dp
    }()
    private let priorityControl: UISegmentedControl = UISegmentedControl(items: ["Low","Medium","High"])
    private let projectDropdownField: UITextField = {
        let tf = UITextField()
        let picker = UIPickerView()
        tf.inputView = picker
        return tf
    }()
    private let stackView = UIStackView()

    // MARK: – Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: – Setup
    private func setupView() {
        // Card styling
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .tasker.surfacePrimary
        card.layer.cornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.r2
        card.applyTaskerElevation(.e1)
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Stack layout inside card
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20)
        ])

        // Configure fields
        priorityControl.selectedSegmentIndex = 1

        // Add to stack
        [titleField,
         descriptionField,
         dueDatePicker,
         priorityControl,
         projectDropdownField].forEach { stackView.addArrangedSubview($0) }
    }

    // MARK: – Configuration
    func configure(title: String,
                   description: String,
                   dueDate: String,
                   priority: String,
                   project: String) {
        titleField.text = title
        descriptionField.text = description

        // You may want to parse `dueDate` string into a Date

        if let idx = ["Low","Medium","High"].firstIndex(of: priority) {
            priorityControl.selectedSegmentIndex = idx
        }
    }
}
