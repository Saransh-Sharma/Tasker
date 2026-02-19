import UIKit
import MaterialComponents.MaterialTextControls_FilledTextFields

enum PillButtonStyle {
    case primary
}

struct PillButtonBarItem {
    let title: String
}

protocol PillButtonBarDelegate: AnyObject {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int)
}

final class PillButtonBar: UIView {
    weak var barDelegate: PillButtonBarDelegate?
    var centerAligned: Bool = false {
        didSet { stack.alignment = centerAligned ? .center : .fill }
    }
    var items: [PillButtonBarItem] = [] {
        didSet { reloadItems() }
    }

    private var selectedIndex: Int?
    private let stack = UIStackView()

    init(pillButtonStyle: PillButtonStyle) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func selectItem(atIndex index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        selectedIndex = index
        updateSelectionState()
        barDelegate?.pillBar(self, didSelectItem: items[index], atIndex: index)
        return true
    }

    private func reloadItems() {
        stack.arrangedSubviews.forEach { subview in
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.layer.cornerRadius = 12
            button.layer.cornerCurve = .continuous
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            button.tag = index
            button.addTarget(self, action: #selector(didTapItem(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        updateSelectionState()
    }

    @objc private func didTapItem(_ sender: UIButton) {
        _ = selectItem(atIndex: sender.tag)
    }

    private func updateSelectionState() {
        for case let button as UIButton in stack.arrangedSubviews {
            let isSelected = button.tag == selectedIndex
            button.backgroundColor = isSelected ? UIColor.tasker.accentPrimary : UIColor.tasker.surfaceSecondary
            button.setTitleColor(isSelected ? UIColor.tasker.accentOnPrimary : UIColor.tasker.textPrimary, for: .normal)
        }
    }
}

protocol AddTaskMetadataRowDelegate: AnyObject {
    func metadataRow(_ row: AddTaskMetadataRowView, didSelectDate date: Date)
    func metadataRow(_ row: AddTaskMetadataRowView, didSetReminder time: Date?)
    func metadataRow(_ row: AddTaskMetadataRowView, didToggleEvening isEvening: Bool)
}

final class AddTaskMetadataRowView: UIView {
    weak var delegate: AddTaskMetadataRowDelegate?

    func updateDate(_ date: Date) {
        // UIKit AddTask screen currently stores date state in controller.
    }

    func staggerEntrance(baseDelay: TimeInterval) {
        // Compatibility no-op while UIKit screen is still present.
    }
}

protocol AddTaskPriorityPickerDelegate: AnyObject {
    func priorityPicker(_ picker: AddTaskPriorityPickerView, didSelect priority: TaskPriority)
}

final class AddTaskPriorityPickerView: UIView {
    weak var delegate: AddTaskPriorityPickerDelegate?
    var selectedPriority: TaskPriority = .none

    func staggerEntrance(baseDelay: TimeInterval) {
        // Compatibility no-op while UIKit screen is still present.
    }
}

extension AddTaskViewController {
    func setupBackdropBackground() {
        backdropBackgroundImageView.frame = CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        backdropBackgroundImageView.backgroundColor = UIColor.tasker.bgCanvas
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        backdropContainer.addSubview(backdropBackgroundImageView)
    }

    func setupAddTaskTextField() {
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        addTaskTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        addTaskTextBox_Material.label.text = "Task name"
        addTaskTextBox_Material.placeholder = "What do you need to do?"
        addTaskTextBox_Material.accessibilityIdentifier = "addTask.titleField"
        addTaskTextBox_Material.sizeToFit()
        addTaskTextBox_Material.delegate = self
        addTaskTextBox_Material.clearButtonMode = .whileEditing
        styleFilledTextField(addTaskTextBox_Material)
    }

    func styleFilledTextField(_ textField: MDCFilledTextField) {
        textField.setFilledBackgroundColor(UIColor.tasker.surfaceSecondary, for: .normal)
        textField.setFilledBackgroundColor(UIColor.tasker.surfaceSecondary, for: .editing)
        textField.setNormalLabelColor(UIColor.tasker.textTertiary, for: .normal)
        textField.setFloatingLabelColor(UIColor.tasker.accentPrimary, for: .editing)
        textField.setTextColor(UIColor.tasker.textPrimary, for: .normal)
        textField.setTextColor(UIColor.tasker.textPrimary, for: .editing)
        textField.setUnderlineColor(.clear, for: .normal)
        textField.setUnderlineColor(UIColor.tasker.accentPrimary, for: .editing)
    }

    func refreshBackdropGradientForCurrentTheme(deferredIfNeeded: Bool = true) {
        if backdropBackgroundImageView.superview != nil {
            backdropBackgroundImageView.backgroundColor = UIColor.tasker.bgCanvas
        }
    }

    func refreshBackdropAppearanceForCurrentTheme() {
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
    }

    func fitViewIntoSuperview(_ view: UIView, margins: UIEdgeInsets = .zero) {
        guard let superview = view.superview else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: margins.left),
            view.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -margins.right),
            view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
            view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom)
        ])
    }
}
