// LGSearchBar.swift
// Search bar component with glass morphism and adaptive design
// Enhanced search experience with liquid animations and suggestions

import UIKit
import SnapKit

// MARK: - Search Bar Component
class LGSearchBar: LGBaseView {
    
    // MARK: - UI Elements
    private let searchTextField = UITextField()
    private let searchIconView = UIImageView()
    private let clearButton = UIButton()
    private let cancelButton = UIButton()
    private let suggestionsTableView = UITableView()
    private let suggestionsContainer = LGBaseView()
    
    // MARK: - Properties
    var text: String? {
        get { return searchTextField.text }
        set { 
            searchTextField.text = newValue
            updateClearButtonVisibility()
        }
    }
    
    var placeholder: String? {
        didSet {
            searchTextField.placeholder = placeholder
        }
    }
    
    var suggestions: [String] = [] {
        didSet {
            updateSuggestions()
        }
    }
    
    var showsSuggestions: Bool = true {
        didSet {
            suggestionsContainer.isHidden = !showsSuggestions
        }
    }
    
    var onTextChanged: ((String?) -> Void)?
    var onSearchButtonPressed: ((String?) -> Void)?
    var onCancelPressed: (() -> Void)?
    var onSuggestionSelected: ((String) -> Void)?
    
    private var isActive: Bool = false {
        didSet {
            updateActiveState()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSearchBar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSearchBar()
    }
    
    // MARK: - Setup
    private func setupSearchBar() {
        setupSearchBarProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
        setupSuggestions()
    }
    
    private func setupSearchBarProperties() {
        glassIntensity = 0.6
        cornerRadius = LGDevice.isIPad ? 12 : 10
        
        // Set height
        let height: CGFloat = LGDevice.isIPad ? 48 : 44
        snp.makeConstraints { make in
            make.height.equalTo(height)
        }
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.1
    }
    
    private func setupSubviews() {
        // Configure search text field
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = .clear
        searchTextField.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        searchTextField.textColor = .label
        searchTextField.tintColor = LGThemeManager.shared.accentColor
        searchTextField.placeholder = "Search tasks..."
        searchTextField.returnKeyType = .search
        searchTextField.delegate = self
        
        // Configure search icon
        searchIconView.image = UIImage(systemName: "magnifyingglass")
        searchIconView.tintColor = .secondaryLabel
        searchIconView.contentMode = .scaleAspectFit
        
        // Configure clear button
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = .secondaryLabel
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // Configure cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(LGThemeManager.shared.accentColor, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        cancelButton.isHidden = true
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Add subviews
        [searchTextField, searchIconView, clearButton, cancelButton].forEach {
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        let horizontalPadding: CGFloat = LGDevice.isIPad ? 16 : 12
        let iconSize: CGFloat = LGDevice.isIPad ? 20 : 18
        let buttonSize: CGFloat = LGDevice.isIPad ? 24 : 20
        
        // Search icon
        searchIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }
        
        // Search text field
        searchTextField.snp.makeConstraints { make in
            make.leading.equalTo(searchIconView.snp.trailing).offset(8)
            make.trailing.equalTo(clearButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        // Clear button
        clearButton.snp.makeConstraints { make in
            make.trailing.equalTo(cancelButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(buttonSize)
        }
        
        // Cancel button
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.equalTo(0) // Initially hidden
        }
    }
    
    private func setupInteractions() {
        // Text field events
        searchTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        searchTextField.addTarget(self, action: #selector(textFieldEditingBegan), for: .editingDidBegin)
        searchTextField.addTarget(self, action: #selector(textFieldEditingEnded), for: .editingDidEnd)
        
        // Tap gesture for focusing
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(searchBarTapped))
        addGestureRecognizer(tapGesture)
    }
    
    private func setupSuggestions() {
        // Configure suggestions container
        suggestionsContainer.glassIntensity = 0.8
        suggestionsContainer.cornerRadius = LGDevice.isIPad ? 12 : 10
        suggestionsContainer.isHidden = true
        
        // Configure suggestions table view
        suggestionsTableView.backgroundColor = .clear
        suggestionsTableView.separatorStyle = .none
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        suggestionsTableView.register(LGSuggestionCell.self, forCellReuseIdentifier: "SuggestionCell")
        suggestionsTableView.showsVerticalScrollIndicator = false
        
        suggestionsContainer.addSubview(suggestionsTableView)
        
        // Add suggestions container to superview when needed
        if let superview = superview {
            superview.addSubview(suggestionsContainer)
            setupSuggestionsConstraints()
        }
    }
    
    private func setupSuggestionsConstraints() {
        suggestionsContainer.snp.makeConstraints { make in
            make.top.equalTo(self.snp.bottom).offset(4)
            make.leading.trailing.equalTo(self)
            make.height.lessThanOrEqualTo(200)
        }
        
        suggestionsTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil && suggestionsContainer.superview == nil {
            setupSuggestions()
        }
    }
    
    // MARK: - State Updates
    private func updateActiveState() {
        let cancelButtonWidth: CGFloat = isActive ? (LGDevice.isIPad ? 80 : 70) : 0
        
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            
            self.cancelButton.snp.updateConstraints { make in
                make.width.equalTo(cancelButtonWidth)
            }
            
            self.cancelButton.alpha = self.isActive ? 1 : 0
            self.superview?.layoutIfNeeded()
        }
        
        cancelButton.isHidden = !isActive
        updateSuggestionsVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let shouldShow = !(searchTextField.text?.isEmpty ?? true)
        
        UIView.animate(withDuration: LGAnimationDurations.short) {
            self.clearButton.alpha = shouldShow ? 1 : 0
        }
        
        clearButton.isHidden = !shouldShow
    }
    
    private func updateSuggestions() {
        suggestionsTableView.reloadData()
        updateSuggestionsVisibility()
    }
    
    private func updateSuggestionsVisibility() {
        let shouldShow = isActive && showsSuggestions && !suggestions.isEmpty && !(searchTextField.text?.isEmpty ?? true)
        
        if shouldShow {
            // Calculate dynamic height based on suggestions count
            let maxHeight: CGFloat = 200
            let cellHeight: CGFloat = LGDevice.isIPad ? 48 : 44
            let suggestedHeight = min(CGFloat(suggestions.count) * cellHeight + 16, maxHeight)
            
            suggestionsContainer.snp.updateConstraints { make in
                make.height.equalTo(suggestedHeight)
            }
        }
        
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.suggestionsContainer.alpha = shouldShow ? 1 : 0
            self.suggestionsContainer.transform = shouldShow ? .identity : CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
        
        suggestionsContainer.isHidden = !shouldShow
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange() {
        updateClearButtonVisibility()
        onTextChanged?(searchTextField.text)
        
        // Filter suggestions based on text
        if let searchText = searchTextField.text, !searchText.isEmpty {
            // This would typically filter from a larger dataset
            // For now, we'll just show all suggestions
            updateSuggestionsVisibility()
        } else {
            updateSuggestionsVisibility()
        }
    }
    
    @objc private func textFieldEditingBegan() {
        isActive = true
        animateFocusState(true)
    }
    
    @objc private func textFieldEditingEnded() {
        // Don't immediately deactivate if suggestions are being interacted with
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.suggestionsTableView.isUserInteractionEnabled {
                self.isActive = false
                self.animateFocusState(false)
            }
        }
    }
    
    @objc private func clearButtonTapped() {
        searchTextField.text = ""
        textFieldDidChange()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @objc private func cancelButtonTapped() {
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        isActive = false
        onCancelPressed?()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @objc private func searchBarTapped() {
        searchTextField.becomeFirstResponder()
    }
    
    // MARK: - Animations
    private func animateFocusState(_ isFocused: Bool) {
        let shadowOpacity: Float = isFocused ? 0.15 : 0.1
        let borderColor = isFocused ? LGThemeManager.shared.accentColor : UIColor.clear
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.layer.shadowOpacity = shadowOpacity
            self.layer.borderColor = borderColor.cgColor
            self.layer.borderWidth = isFocused ? 1 : 0
        }
    }
    
    // MARK: - Public Methods
    @discardableResult
    func becomeFirstResponder() -> Bool {
        return searchTextField.becomeFirstResponder()
    }
    
    @discardableResult
    func resignFirstResponder() -> Bool {
        return searchTextField.resignFirstResponder()
    }
    
    func clearText() {
        clearButtonTapped()
    }
}

// MARK: - UITextFieldDelegate
extension LGSearchBar: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSearchButtonPressed?(textField.text)
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDataSource & Delegate
extension LGSearchBar: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath) as! LGSuggestionCell
        cell.configure(with: suggestions[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return LGDevice.isIPad ? 48 : 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let suggestion = suggestions[indexPath.row]
        searchTextField.text = suggestion
        onSuggestionSelected?(suggestion)
        
        searchTextField.resignFirstResponder()
        isActive = false
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Suggestion Cell
class LGSuggestionCell: UITableViewCell {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Configure icon
        iconImageView.image = UIImage(systemName: "magnifyingglass")
        iconImageView.tintColor = .secondaryLabel
        iconImageView.contentMode = .scaleAspectFit
        
        // Configure title label
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        
        // Add subviews
        [iconImageView, titleLabel].forEach {
            contentView.addSubview($0)
        }
        
        // Setup constraints
        let iconSize: CGFloat = LGDevice.isIPad ? 18 : 16
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
    }
    
    func configure(with text: String) {
        titleLabel.text = text
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.2) {
            self.backgroundColor = highlighted ? UIColor.systemGray6.withAlphaComponent(0.5) : .clear
        }
    }
}
