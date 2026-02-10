//
//  LGSearchBar.swift
//  Tasker
//
//  iOS 16+ Liquid Glass Search Bar with glass morphism effects
//

import UIKit

protocol LGSearchBarDelegate: AnyObject {
    func searchBar(_ searchBar: LGSearchBar, textDidChange text: String)
    func searchBarDidBeginEditing(_ searchBar: LGSearchBar)
    func searchBarDidEndEditing(_ searchBar: LGSearchBar)
    func searchBarSearchButtonTapped(_ searchBar: LGSearchBar)
    func searchBarCancelButtonTapped(_ searchBar: LGSearchBar)
}

class LGSearchBar: LGBaseView {

    // MARK: - Properties

    weak var delegate: LGSearchBarDelegate?

    // Theme support
    private var todoColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    
    private let searchIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = .label.withAlphaComponent(0.6) // Will be updated in applyTheme
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let searchTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.tasker.callout
        textField.textColor = .label // Will be updated in applyTheme
        textField.tintColor = .label // Will be updated in applyTheme
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search tasks...",
            attributes: [.foregroundColor: UIColor.label.withAlphaComponent(0.5)] // Will be updated in applyTheme
        )
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .label.withAlphaComponent(0.6) // Will be updated in applyTheme
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.label, for: .normal) // Will be updated in applyTheme
        button.titleLabel?.font = UIFont.tasker.buttonSmall
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        return button
    }()
    
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    
    var text: String {
        get { searchTextField.text ?? "" }
        set { searchTextField.text = newValue }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        cornerRadius = corners.input
        
        addSubview(searchIconImageView)
        addSubview(searchTextField)
        addSubview(clearButton)
        addSubview(cancelButton)
        
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            // Search icon
            searchIconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: spacing.s12),
            searchIconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIconImageView.widthAnchor.constraint(equalToConstant: spacing.s20),
            searchIconImageView.heightAnchor.constraint(equalToConstant: spacing.s20),
            
            // Text field
            searchTextField.leadingAnchor.constraint(equalTo: searchIconImageView.trailingAnchor, constant: spacing.s8),
            searchTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchTextField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -spacing.s8),
            
            // Clear button
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -spacing.s12),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: spacing.s20),
            clearButton.heightAnchor.constraint(equalToConstant: spacing.s20),
            
            // Cancel button
            cancelButton.leadingAnchor.constraint(equalTo: trailingAnchor, constant: spacing.s8),
            cancelButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            cancelButtonWidthConstraint!,
            
            // Height
            heightAnchor.constraint(equalToConstant: spacing.buttonHeight)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func textFieldDidChange() {
        let hasText = !(searchTextField.text?.isEmpty ?? true)
        clearButton.isHidden = !hasText
        delegate?.searchBar(self, textDidChange: searchTextField.text ?? "")
    }
    
    @objc private func clearButtonTapped() {
        searchTextField.text = ""
        clearButton.isHidden = true
        delegate?.searchBar(self, textDidChange: "")
    }
    
    @objc private func cancelButtonTapped() {
        searchTextField.resignFirstResponder()
        searchTextField.text = ""
        clearButton.isHidden = true
        delegate?.searchBarCancelButtonTapped(self)
    }
    
    // MARK: - Public Methods
    
    override func becomeFirstResponder() -> Bool {
        return searchTextField.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        return searchTextField.resignFirstResponder()
    }
    
    private func showCancelButton() {
        cancelButtonWidthConstraint?.constant = 70
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.cancelButton.alpha = 1
            self.layoutIfNeeded()
        }
    }
    
    private func hideCancelButton() {
        cancelButtonWidthConstraint?.constant = 0

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.cancelButton.alpha = 0
            self.layoutIfNeeded()
        }
    }

    // MARK: - Theme Application

    func applyTheme() {
        // Update search icon color
        searchIconImageView.tintColor = todoColors.textPrimary.withAlphaComponent(0.6)

        // Update text field colors
        searchTextField.textColor = todoColors.textPrimary
        searchTextField.tintColor = todoColors.textPrimary

        // Update placeholder with theme color
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search tasks...",
            attributes: [.foregroundColor: todoColors.textPrimary.withAlphaComponent(0.5)]
        )

        // Update button colors
        clearButton.tintColor = todoColors.textPrimary.withAlphaComponent(0.6)
        cancelButton.setTitleColor(todoColors.textPrimary, for: .normal)
    }
}

// MARK: - UITextFieldDelegate

extension LGSearchBar: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        showCancelButton()
        delegate?.searchBarDidBeginEditing(self)

        // Animate focus with theme colors
        UIView.animate(withDuration: 0.2) {
            self.borderColor = self.todoColors.accentRing
            self.borderWidth = 1.0
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        hideCancelButton()
        delegate?.searchBarDidEndEditing(self)

        // Animate unfocus with theme colors
        UIView.animate(withDuration: 0.2) {
            self.borderColor = self.todoColors.strokeHairline
            self.borderWidth = 0.5
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.searchBarSearchButtonTapped(self)
        return true
    }
}
