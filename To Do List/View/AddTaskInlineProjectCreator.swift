import UIKit
import MaterialComponents.MaterialTextControls_FilledTextFields

// MARK: - Delegate

@MainActor
protocol InlineProjectCreatorDelegate: AnyObject {
    func inlineProjectCreator(_ creator: AddTaskInlineProjectCreatorView, didCreate projectName: String)
    func inlineProjectCreatorDidCancel(_ creator: AddTaskInlineProjectCreatorView)
}

// MARK: - Inline Project Creator View

@MainActor
final class AddTaskInlineProjectCreatorView: UIView, UITextFieldDelegate {

    weak var delegate: InlineProjectCreatorDelegate?

    private let containerStack = UIStackView()
    private let textField = MDCFilledTextField()
    private let createButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private var heightConstraint: NSLayoutConstraint!

    private var colors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }

    var isShowing: Bool { !isHidden }

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

    func show() {
        guard isHidden else { return }
        isHidden = false
        alpha = 0
        heightConstraint.constant = 0
        layoutIfNeeded()

        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            self.alpha = 1
            self.heightConstraint.constant = 52
            self.superview?.layoutIfNeeded()
        } completion: { _ in
            self.textField.becomeFirstResponder()
        }
    }

    func hide(success: Bool = false) {
        if success {
            // Flash success color on border
            textField.setUnderlineColor(colors.statusSuccess, for: .editing)
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy, delay: 0.2, animations: {
                self.alpha = 0
                self.heightConstraint.constant = 0
                self.superview?.layoutIfNeeded()
            }) { _ in
                self.isHidden = true
                self.reset()
            }
        } else {
            textField.resignFirstResponder()
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy, animations: {
                self.alpha = 0
                self.heightConstraint.constant = 0
                self.superview?.layoutIfNeeded()
            }) { _ in
                self.isHidden = true
                self.reset()
            }
        }
    }

    func showValidationError() {
        // Shake animation
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        textField.layer.add(animation, forKey: "shake")

        // Flash danger border
        textField.setUnderlineColor(colors.statusDanger, for: .editing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.textField.setUnderlineColor(self.colors.accentRing, for: .editing)
        }
    }

    // MARK: - Setup

    private func configure() {
        accessibilityIdentifier = "addTask.inlineProjectCreator"
        clipsToBounds = true
        isHidden = true

        // Container stack
        containerStack.axis = .horizontal
        containerStack.spacing = 8
        containerStack.alignment = .center
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStack)

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightConstraint
        ])

        // Text field
        textField.placeholder = "New project name"
        textField.label.text = ""
        textField.leadingAssistiveLabel.text = ""
        textField.font = UIFont.tasker.font(for: .callout)
        textField.containerRadius = TaskerUIKitTokens.corner.input
        textField.setFilledBackgroundColor(colors.surfaceSecondary, for: .normal)
        textField.setFilledBackgroundColor(colors.surfaceSecondary, for: .editing)
        textField.setUnderlineColor(colors.strokeHairline, for: .normal)
        textField.setUnderlineColor(colors.accentRing, for: .editing)
        textField.setTextColor(colors.textPrimary, for: .normal)
        textField.setTextColor(colors.textPrimary, for: .editing)
        textField.tintColor = colors.accentPrimary
        textField.delegate = self
        textField.returnKeyType = .done
        textField.autocapitalizationType = .words
        textField.accessibilityIdentifier = "addTask.inlineProjectName"
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerStack.addArrangedSubview(textField)

        // Create button
        createButton.setTitle("Create", for: .normal)
        createButton.titleLabel?.font = UIFont.tasker.font(for: .callout).withWeight(.semibold)
        createButton.backgroundColor = colors.accentPrimary
        createButton.setTitleColor(colors.accentOnPrimary, for: .normal)
        createButton.setTitleColor(colors.accentOnPrimary.withAlphaComponent(0.5), for: .disabled)
        createButton.layer.cornerRadius = TaskerUIKitTokens.corner.chip
        createButton.layer.cornerCurve = .continuous
        createButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        createButton.isEnabled = false
        createButton.alpha = 0.5
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        createButton.accessibilityIdentifier = "addTask.inlineProjectCreate"
        createButton.setContentHuggingPriority(.required, for: .horizontal)
        containerStack.addArrangedSubview(createButton)

        // Cancel button
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        cancelButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        cancelButton.tintColor = colors.textTertiary
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.accessibilityIdentifier = "addTask.inlineProjectCancel"
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            cancelButton.widthAnchor.constraint(equalToConstant: 28),
            cancelButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        containerStack.addArrangedSubview(cancelButton)

        // Listen for text changes
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    private func reset() {
        textField.text = ""
        createButton.isEnabled = false
        createButton.alpha = 0.5
        textField.setUnderlineColor(colors.accentRing, for: .editing)
    }

    // MARK: - Actions

    @objc private func createTapped() {
        guard let name = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            showValidationError()
            return
        }
        TaskerHaptic.success()
        delegate?.inlineProjectCreator(self, didCreate: name)
    }

    @objc private func cancelTapped() {
        TaskerHaptic.light()
        delegate?.inlineProjectCreatorDidCancel(self)
    }

    @objc private func textChanged() {
        let hasText = !(textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        createButton.isEnabled = hasText
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            self.createButton.alpha = hasText ? 1.0 : 0.5
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if createButton.isEnabled {
            createTapped()
        }
        return true
    }
}

// MARK: - UIFont weight helper (if not already defined)

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
