// LGTextField.swift
// Text field component with glass morphism effects and adaptive design
// Enhanced input experience with liquid animations for iPhone and iPad

import UIKit
import SnapKit

// MARK: - Text Field Component
class LGTextField: LGBaseView {
    
    // MARK: - Text Field Style
    enum Style {
        case standard
        case outlined
        case filled
        
        var glassIntensity: CGFloat {
            switch self {
            case .standard: return 0.3
            case .outlined: return 0.5
            case .filled: return 0.7
            }
        }
    }
    
    // MARK: - UI Elements
    private let textField = UITextField()
    private let placeholderLabel = UILabel()
    private let iconImageView = UIImageView()
    private let clearButton = UIButton()
    private let underlineView = UIView()
    private let errorLabel = UILabel()
    private let characterCountLabel = UILabel()
    
    // MARK: - Properties
    var text: String? {
        get { return textField.text }
        set { 
            textField.text = newValue
            updatePlaceholderState()
            updateCharacterCount()
        }
    }
    
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            textField.placeholder = style == .standard ? placeholder : nil
        }
    }
    
    var style: Style = .standard {
        didSet {
            updateAppearance()
        }
    }
    
    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
            iconImageView.isHidden = icon == nil
            updateLayout()
        }
    }
    
    var errorMessage: String? {
        didSet {
            errorLabel.text = errorMessage
            errorLabel.isHidden = errorMessage?.isEmpty ?? true
            updateErrorState()
        }
    }
    
    var maxCharacterCount: Int? {
        didSet {
            characterCountLabel.isHidden = maxCharacterCount == nil
            updateCharacterCount()
        }
    }
    
    var isSecure: Bool = false {
        didSet {
            textField.isSecureTextEntry = isSecure
            updateSecureTextButton()
        }
    }
    
    var keyboardType: UIKeyboardType = .default {
        didSet {
            textField.keyboardType = keyboardType
        }
    }
    
    var returnKeyType: UIReturnKeyType = .default {
        didSet {
            textField.returnKeyType = returnKeyType
        }
    }
    
    var onTextChanged: ((String?) -> Void)?
    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?
    var onReturnPressed: (() -> Void)?
    
    private var isFloatingPlaceholder: Bool {
        return style != .standard && !(text?.isEmpty ?? true)
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    // MARK: - Setup
    private func setupTextField() {
        setupTextFieldProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
        updateAppearance()
    }
    
    private func setupTextFieldProperties() {
        glassIntensity = style.glassIntensity
        cornerRadius = LGDevice.isIPad ? 12 : 10
        
        // Set height
        let height: CGFloat = LGDevice.isIPad ? 56 : 48
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(height)
        }
    }
    
    private func setupSubviews() {
        // Configure text field
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        textField.textColor = .label
        textField.tintColor = LGThemeManager.shared.accentColor
        textField.delegate = self
        
        // Configure floating placeholder
        placeholderLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.backgroundColor = .clear
        
        // Configure icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .secondaryLabel
        iconImageView.isHidden = true
        
        // Configure clear button
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = .secondaryLabel
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // Configure underline (for standard style)
        underlineView.backgroundColor = .separator
        underlineView.isHidden = style != .standard
        
        // Configure error label
        errorLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        
        // Configure character count label
        characterCountLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        characterCountLabel.textColor = .secondaryLabel
        characterCountLabel.textAlignment = .right
        characterCountLabel.isHidden = true
        
        // Add subviews
        [textField, placeholderLabel, iconImageView, clearButton, 
         underlineView, errorLabel, characterCountLabel].forEach {
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        updateLayout()
        
        // Error label
        errorLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(LGDevice.isIPad ? 64 : 56)
            make.leading.trailing.equalToSuperview().inset(4)
        }
        
        // Character count label
        characterCountLabel.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        // Underline view
        underlineView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-2)
            make.height.equalTo(1)
        }
    }
    
    private func updateLayout() {
        let horizontalPadding: CGFloat = LGDevice.isIPad ? 16 : 12
        let iconSize: CGFloat = LGDevice.isIPad ? 24 : 20
        let clearButtonSize: CGFloat = LGDevice.isIPad ? 24 : 20
        
        if icon != nil {
            // With icon layout
            iconImageView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(horizontalPadding)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(iconSize)
            }
            
            textField.snp.remakeConstraints { make in
                make.leading.equalTo(iconImageView.snp.trailing).offset(12)
                make.trailing.equalTo(clearButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
            }
            
            placeholderLabel.snp.remakeConstraints { make in
                make.leading.equalTo(textField)
                make.trailing.equalTo(textField)
                make.centerY.equalToSuperview()
            }
        } else {
            // Without icon layout
            textField.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(horizontalPadding)
                make.trailing.equalTo(clearButton.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
            }
            
            placeholderLabel.snp.remakeConstraints { make in
                make.leading.equalTo(textField)
                make.trailing.equalTo(textField)
                make.centerY.equalToSuperview()
            }
        }
        
        // Clear button
        clearButton.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().offset(-horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(clearButtonSize)
        }
    }
    
    private func setupInteractions() {
        // Text field events
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.addTarget(self, action: #selector(textFieldEditingBegan), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(textFieldEditingEnded), for: .editingDidEnd)
        
        // Tap gesture for focusing
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Appearance Updates
    private func updateAppearance() {
        glassIntensity = style.glassIntensity
        
        switch style {
        case .standard:
            layer.borderWidth = 0
            underlineView.isHidden = false
            textField.placeholder = placeholder
            
        case .outlined:
            layer.borderWidth = 1
            layer.borderColor = UIColor.separator.cgColor
            underlineView.isHidden = true
            textField.placeholder = nil
            
        case .filled:
            layer.borderWidth = 0
            backgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
            underlineView.isHidden = true
            textField.placeholder = nil
        }
        
        updatePlaceholderState()
    }
    
    private func updatePlaceholderState() {
        let shouldFloat = isFloatingPlaceholder || textField.isFirstResponder
        
        if style == .standard {
            placeholderLabel.isHidden = true
            return
        }
        
        placeholderLabel.isHidden = false
        
        let targetTransform: CGAffineTransform
        let targetFont: UIFont
        let targetColor: UIColor
        
        if shouldFloat {
            targetTransform = CGAffineTransform(translationX: 0, y: -20)
            targetFont = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
            targetColor = textField.isFirstResponder ? LGThemeManager.shared.accentColor : .secondaryLabel
        } else {
            targetTransform = .identity
            targetFont = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
            targetColor = .secondaryLabel
        }
        
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.placeholderLabel.transform = targetTransform
            self.placeholderLabel.font = targetFont
            self.placeholderLabel.textColor = targetColor
        }
    }
    
    private func updateErrorState() {
        let hasError = !(errorMessage?.isEmpty ?? true)
        let borderColor = hasError ? UIColor.systemRed : UIColor.separator
        let underlineColor = hasError ? UIColor.systemRed : LGThemeManager.shared.accentColor
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            if self.style == .outlined {
                self.layer.borderColor = borderColor.cgColor
            }
            self.underlineView.backgroundColor = underlineColor
        }
    }
    
    private func updateCharacterCount() {
        guard let maxCount = maxCharacterCount else { return }
        
        let currentCount = text?.count ?? 0
        characterCountLabel.text = "\(currentCount)/\(maxCount)"
        
        let isOverLimit = currentCount > maxCount
        characterCountLabel.textColor = isOverLimit ? .systemRed : .secondaryLabel
    }
    
    private func updateSecureTextButton() {
        if isSecure {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "eye"), for: .normal)
            button.setImage(UIImage(systemName: "eye.slash"), for: .selected)
            button.tintColor = .secondaryLabel
            button.addTarget(self, action: #selector(toggleSecureText), for: .touchUpInside)
            
            textField.rightView = button
            textField.rightViewMode = .always
        } else {
            textField.rightView = nil
        }
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange() {
        updatePlaceholderState()
        updateCharacterCount()
        updateClearButtonVisibility()
        onTextChanged?(textField.text)
    }
    
    @objc private func textFieldEditingBegan() {
        animateFocusState(true)
        updatePlaceholderState()
        onEditingBegan?()
    }
    
    @objc private func textFieldEditingEnded() {
        animateFocusState(false)
        updatePlaceholderState()
        onEditingEnded?()
    }
    
    @objc private func clearButtonTapped() {
        textField.text = ""
        textFieldDidChange()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @objc private func toggleSecureText(_ sender: UIButton) {
        sender.isSelected.toggle()
        textField.isSecureTextEntry = !sender.isSelected
        
        // Maintain cursor position
        if let existingText = textField.text, textField.isSecureTextEntry {
            textField.deleteBackward()
            textField.insertText(String(existingText.last ?? Character("")))
        }
    }
    
    @objc private func viewTapped() {
        textField.becomeFirstResponder()
    }
    
    private func updateClearButtonVisibility() {
        let shouldShow = !(textField.text?.isEmpty ?? true) && textField.isFirstResponder
        
        UIView.animate(withDuration: LGAnimationDurations.short) {
            self.clearButton.alpha = shouldShow ? 1 : 0
        }
        
        clearButton.isHidden = !shouldShow
    }
    
    // MARK: - Animations
    private func animateFocusState(_ isFocused: Bool) {
        let borderColor = isFocused ? LGThemeManager.shared.accentColor : UIColor.separator
        let underlineColor = isFocused ? LGThemeManager.shared.accentColor : UIColor.separator
        let shadowOpacity: Float = isFocused ? 0.15 : 0.1
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            if self.style == .outlined {
                self.layer.borderColor = borderColor.cgColor
            }
            self.underlineView.backgroundColor = underlineColor
            self.layer.shadowOpacity = shadowOpacity
        }
        
        updateClearButtonVisibility()
    }
    
    // MARK: - Public Methods
    @discardableResult
    func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    @discardableResult
    func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
    
    var isFirstResponder: Bool {
        return textField.isFirstResponder
    }
}

// MARK: - UITextFieldDelegate
extension LGTextField: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturnPressed?()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maxCount = maxCharacterCount else { return true }
        
        let currentText = textField.text ?? ""
        let newLength = currentText.count + string.count - range.length
        
        return newLength <= maxCount
    }
}

// MARK: - Convenience Initializers
extension LGTextField {
    
    convenience init(placeholder: String, style: Style = .standard) {
        self.init(frame: .zero)
        self.placeholder = placeholder
        self.style = style
        updateAppearance()
    }
    
    convenience init(placeholder: String, icon: UIImage, style: Style = .standard) {
        self.init(frame: .zero)
        self.placeholder = placeholder
        self.icon = icon
        self.style = style
        updateAppearance()
    }
}
