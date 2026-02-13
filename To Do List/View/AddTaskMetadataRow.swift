import UIKit

// MARK: - Delegate

@MainActor
protocol AddTaskMetadataRowDelegate: AnyObject {
    func metadataRow(_ row: AddTaskMetadataRowView, didSelectDate date: Date)
    func metadataRow(_ row: AddTaskMetadataRowView, didSetReminder time: Date?)
    func metadataRow(_ row: AddTaskMetadataRowView, didToggleEvening isEvening: Bool)
}

// MARK: - Metadata Row View

@MainActor
final class AddTaskMetadataRowView: UIView {

    weak var delegate: AddTaskMetadataRowDelegate?

    // MARK: - State

    private(set) var selectedDate: Date = Date()
    private(set) var selectedReminderTime: Date?
    private(set) var isEvening: Bool = false

    // MARK: - Subviews

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let dateChip = MetadataChipButton()
    private let reminderChip = MetadataChipButton()
    private let timeOfDayChip = MetadataChipButton()

    private var timePicker: UIDatePicker?

    // MARK: - Colors shortcut

    private var colors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Public API

    func updateDate(_ date: Date) {
        selectedDate = date
        refreshDateChip()
    }

    func staggerEntrance(baseDelay: TimeInterval) {
        let chips: [UIView] = [dateChip, reminderChip, timeOfDayChip]
        for (i, chip) in chips.enumerated() {
            chip.alpha = 0
            chip.transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy, delay: baseDelay + Double(i) * TaskerAnimation.staggerInterval) {
                chip.alpha = 1
                chip.transform = .identity
            }
        }
    }

    // MARK: - Setup

    private func configure() {
        accessibilityIdentifier = "addTask.metadataRow"

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.spacing = spacing.chipSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 44),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        // Date chip
        dateChip.accessibilityIdentifier = "addTask.dateChip"
        dateChip.addTarget(self, action: #selector(dateTapped), for: .touchUpInside)
        stackView.addArrangedSubview(dateChip)

        // Reminder chip
        reminderChip.accessibilityIdentifier = "addTask.reminderChip"
        reminderChip.addTarget(self, action: #selector(reminderTapped), for: .touchUpInside)
        stackView.addArrangedSubview(reminderChip)

        // Time of day chip
        timeOfDayChip.accessibilityIdentifier = "addTask.timeOfDayChip"
        timeOfDayChip.addTarget(self, action: #selector(timeOfDayTapped), for: .touchUpInside)
        stackView.addArrangedSubview(timeOfDayChip)

        refreshAllChips()
    }

    // MARK: - Refresh

    private func refreshAllChips() {
        refreshDateChip()
        refreshReminderChip()
        refreshTimeOfDayChip()
    }

    private func refreshDateChip() {
        let text = smartDateText(for: selectedDate)
        let isActive = !Calendar.current.isDateInToday(selectedDate)
        dateChip.update(icon: "calendar", text: text, isActive: isActive, colors: colors)
    }

    private func refreshReminderChip() {
        if let time = selectedReminderTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let text = formatter.string(from: time)
            reminderChip.update(icon: "bell.fill", text: text, isActive: true, colors: colors)
        } else {
            reminderChip.update(icon: "bell", text: "Reminder", isActive: false, colors: colors)
        }
    }

    private func refreshTimeOfDayChip() {
        let icon = isEvening ? "moon.stars" : "sun.max"
        let text = isEvening ? "Evening" : "Morning"
        timeOfDayChip.update(icon: icon, text: text, isActive: isEvening, colors: colors)
    }

    // MARK: - Actions

    @objc private func dateTapped() {
        TaskerHaptic.selection()
        // Cycle: Today -> Tomorrow -> day after
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            selectedDate = tomorrow
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
                  calendar.isDate(selectedDate, inSameDayAs: tomorrow) {
            let dayAfter = calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
            selectedDate = dayAfter
        } else {
            selectedDate = Date()
        }
        refreshDateChip()
        delegate?.metadataRow(self, didSelectDate: selectedDate)
    }

    @objc private func reminderTapped() {
        TaskerHaptic.selection()
        if selectedReminderTime != nil {
            // Clear reminder
            selectedReminderTime = nil
            dismissTimePicker()
            refreshReminderChip()
            delegate?.metadataRow(self, didSetReminder: nil)
        } else {
            showTimePicker()
        }
    }

    @objc private func timeOfDayTapped() {
        TaskerHaptic.selection()
        isEvening.toggle()

        // Cross-fade icon
        UIView.transition(with: timeOfDayChip, duration: 0.25, options: .transitionCrossDissolve) {
            self.refreshTimeOfDayChip()
        }

        delegate?.metadataRow(self, didToggleEvening: isEvening)
    }

    // MARK: - Time Picker

    private func showTimePicker() {
        guard timePicker == nil else { return }

        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 5
        picker.tintColor = colors.accentPrimary
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.addTarget(self, action: #selector(timePickerChanged(_:)), for: .valueChanged)

        // Set default to 9:00 AM
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        if let defaultTime = Calendar.current.date(from: components) {
            picker.date = defaultTime
        }

        timePicker = picker

        // Insert picker below the scroll view
        addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor),
            picker.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4)
        ])

        // Animate in
        picker.alpha = 0
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            picker.alpha = 1
        }

        // Auto-set the time
        timePickerChanged(picker)
    }

    private func dismissTimePicker() {
        guard let picker = timePicker else { return }
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy, animations: {
            picker.alpha = 0
        }, completion: { _ in
            picker.removeFromSuperview()
        })
        timePicker = nil
    }

    @objc private func timePickerChanged(_ sender: UIDatePicker) {
        selectedReminderTime = sender.date
        refreshReminderChip()
        delegate?.metadataRow(self, didSetReminder: sender.date)
    }

    // MARK: - Helpers

    private func smartDateText(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Metadata Chip Button

@MainActor
private final class MetadataChipButton: UIControl {

    private let iconView = UIImageView()
    private let label = UILabel()
    private let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(icon: String, text: String, isActive: Bool, colors: TaskerColorTokens) {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        label.text = text

        if isActive {
            backgroundColor = colors.accentWash
            iconView.tintColor = colors.accentPrimary
            label.textColor = colors.accentPrimary
            layer.borderColor = colors.accentRing.cgColor
            layer.borderWidth = 1
        } else {
            backgroundColor = colors.chipUnselectedBackground
            iconView.tintColor = colors.textTertiary
            label.textColor = colors.textTertiary
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
        }
    }

    private func setup() {
        layer.cornerRadius = TaskerUIKitTokens.corner.chip
        layer.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = TaskerUIKitTokens.typography.callout
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentStack.axis = .horizontal
        contentStack.spacing = 6
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(label)

        addSubview(contentStack)

        let hPad: CGFloat = 12
        let vPad: CGFloat = 8
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: vPad),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vPad),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}
