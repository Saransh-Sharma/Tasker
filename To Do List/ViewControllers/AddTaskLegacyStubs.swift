//
//  AddTaskLegacyStubs.swift
//  Tasker
//
//  Legacy UIKit stubs for AddTaskViewController compatibility.
//  These types were replaced by SwiftUI equivalents in the design-redux branch.
//  TODO: Remove this file when AddTaskViewController is fully migrated to SwiftUI.
//

import UIKit
import MaterialComponents.MaterialTextControls_FilledTextFields

// MARK: - AddTaskMetadataRowView (Legacy UIKit stub)

protocol AddTaskMetadataRowDelegate: AnyObject {
    func metadataRow(_ row: AddTaskMetadataRowView, didSelectDate date: Date)
    func metadataRow(_ row: AddTaskMetadataRowView, didSetReminder time: Date?)
    func metadataRow(_ row: AddTaskMetadataRowView, didToggleEvening isEvening: Bool)
}

final class AddTaskMetadataRowView: UIView {
    weak var delegate: AddTaskMetadataRowDelegate?

    func updateDate(_ date: Date) {
        // Stub — SwiftUI AddTaskMetadataRow handles this now
    }

    func staggerEntrance(baseDelay: TimeInterval) {
        // Stub — no-op for legacy compatibility
    }
}

// MARK: - AddTaskPriorityPickerView (Legacy UIKit stub)

protocol AddTaskPriorityPickerDelegate: AnyObject {
    func priorityPicker(_ picker: AddTaskPriorityPickerView, didSelect priority: TaskPriority)
}

final class AddTaskPriorityPickerView: UIView {
    weak var delegate: AddTaskPriorityPickerDelegate?
    var selectedPriority: TaskPriority = .none

    func staggerEntrance(baseDelay: TimeInterval) {
        // Stub — no-op for legacy compatibility
    }
}

// MARK: - Missing AddTaskViewController extensions

extension AddTaskViewController {

    /// Legacy backdrop background setup — replaced by SwiftUI AddTaskBackdropView.
    func setupBackdropBackground() {
        backdropBackgroundImageView.frame = CGRect(
            x: 0, y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        backdropBackgroundImageView.backgroundColor = UIColor.tasker.bgCanvas
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        backdropContainer.addSubview(backdropBackgroundImageView)
    }

    /// Legacy text field setup — stub for compilation.
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

    /// Token-based styling for Material filled text fields.
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

    /// Legacy gradient refresh — stub for compilation.
    func refreshBackdropGradientForCurrentTheme(deferredIfNeeded: Bool = true) {
        if backdropBackgroundImageView.superview != nil {
            backdropBackgroundImageView.backgroundColor = UIColor.tasker.bgCanvas
        }
    }

    /// Legacy appearance refresh — stub for compilation.
    func refreshBackdropAppearanceForCurrentTheme() {
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
    }

    /// Fit a subview into its superview with optional margins.
    func fitViewIntoSuperview(_ view: UIView, margins: UIEdgeInsets = .zero) {
        guard let superview = view.superview else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: margins.left),
            view.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -margins.right),
            view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
            view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom),
        ])
    }
}
