import UIKit

// MARK: - Delegate

@MainActor
protocol AddTaskPriorityPickerDelegate: AnyObject {
    func priorityPicker(_ picker: AddTaskPriorityPickerView, didSelect priority: TaskPriority)
}

// MARK: - Priority Picker View

@MainActor
final class AddTaskPriorityPickerView: UIView {

    weak var delegate: AddTaskPriorityPickerDelegate?

    var selectedPriority: TaskPriority = .low {
        didSet { refreshButtons() }
    }

    private let stackView = UIStackView()
    private var buttons: [PriorityPillButton] = []

    private var colors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Setup

    private func configure() {
        accessibilityIdentifier = "addTask.priorityPicker"

        stackView.axis = .horizontal
        stackView.spacing = TaskerUIKitTokens.spacing.s8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40)
        ])

        let priorities = TaskPriority.uiOrder
        for priority in priorities {
            let button = PriorityPillButton(priority: priority)
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        refreshButtons()
    }

    // MARK: - Refresh

    private func refreshButtons() {
        for button in buttons {
            let isSelected = button.priority == selectedPriority
            button.applyState(isSelected: isSelected, colors: colors)
        }
    }

    // MARK: - Actions

    @objc private func buttonTapped(_ sender: PriorityPillButton) {
        guard sender.priority != selectedPriority else { return }
        TaskerHaptic.selection()
        selectedPriority = sender.priority

        // Spring pulse animation
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            sender.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        } completion: { _ in
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
                sender.transform = .identity
            }
        }

        delegate?.priorityPicker(self, didSelect: sender.priority)
    }

    // MARK: - Stagger entrance

    func staggerEntrance(baseDelay: TimeInterval) {
        for (i, button) in buttons.enumerated() {
            button.alpha = 0
            button.transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy, delay: baseDelay + Double(i) * TaskerAnimation.staggerInterval) {
                button.alpha = 1
                button.transform = .identity
            }
        }
    }
}

// MARK: - Priority Pill Button

@MainActor
private final class PriorityPillButton: UIControl {

    let priority: TaskPriority
    private let dotView = UIView()
    private let label = UILabel()
    private let contentStack = UIStackView()

    init(priority: TaskPriority) {
        self.priority = priority
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyState(isSelected: Bool, colors: TaskerColorTokens) {
        let jewelColor = priorityColor(for: priority, colors: colors)

        dotView.backgroundColor = jewelColor

        if isSelected {
            backgroundColor = jewelColor.withAlphaComponent(0.12)
            label.textColor = jewelColor
            label.font = UIFont.tasker.font(for: .callout).withWeight(.semibold)
            layer.borderColor = jewelColor.cgColor
            layer.borderWidth = 1.5

            // Glow on dot
            dotView.layer.shadowColor = jewelColor.cgColor
            dotView.layer.shadowOffset = .zero
            dotView.layer.shadowRadius = 4
            dotView.layer.shadowOpacity = 0.4
        } else {
            backgroundColor = colors.surfaceTertiary
            label.textColor = colors.textSecondary
            label.font = UIFont.tasker.font(for: .callout)
            layer.borderColor = colors.strokeHairline.cgColor
            layer.borderWidth = 1

            dotView.layer.shadowOpacity = 0
        }
    }

    private func setup() {
        layer.cornerRadius = TaskerUIKitTokens.corner.chip
        layer.cornerCurve = .continuous

        accessibilityIdentifier = "addTask.priority.\(priority.displayName.lowercased())"

        // Dot
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.layer.cornerRadius = 5
        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10)
        ])

        // Label
        label.text = priority.displayName
        label.font = TaskerUIKitTokens.typography.callout
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Stack
        contentStack.axis = .horizontal
        contentStack.spacing = 6
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(dotView)
        contentStack.addArrangedSubview(label)

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func priorityColor(for priority: TaskPriority, colors: TaskerColorTokens) -> UIColor {
        switch priority {
        case .none: return colors.priorityNone
        case .low: return colors.priorityLow
        case .high: return colors.priorityHigh
        case .max: return colors.priorityMax
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }
    }
}

// MARK: - UIFont weight helper

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
