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
    
    private let searchIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = .white.withAlphaComponent(0.6)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let searchTextField: UITextField = {
        let textField = UITextField()
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        textField.textColor = .white
        textField.tintColor = .white
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search tasks...",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white.withAlphaComponent(0.6)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
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
        cornerRadius = 12
        
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
            searchIconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchIconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIconImageView.widthAnchor.constraint(equalToConstant: 20),
            searchIconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Text field
            searchTextField.leadingAnchor.constraint(equalTo: searchIconImageView.trailingAnchor, constant: 8),
            searchTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchTextField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            
            // Clear button
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Cancel button
            cancelButton.leadingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            cancelButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            cancelButtonWidthConstraint!,
            
            // Height
            heightAnchor.constraint(equalToConstant: 44)
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
}

// MARK: - UITextFieldDelegate

extension LGSearchBar: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        showCancelButton()
        delegate?.searchBarDidBeginEditing(self)
        
        // Animate focus
        UIView.animate(withDuration: 0.2) {
            self.borderColor = .white.withAlphaComponent(0.4)
            self.borderWidth = 1.0
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        hideCancelButton()
        delegate?.searchBarDidEndEditing(self)
        
        // Animate unfocus
        UIView.animate(withDuration: 0.2) {
            self.borderColor = .white.withAlphaComponent(0.2)
            self.borderWidth = 0.5
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.searchBarSearchButtonTapped(self)
        return true
    }
}
