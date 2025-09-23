// LGTaskCard.swift
// Core task card component with glass morphism effects and adaptive design
// Optimized for both iPhone and iPad with liquid animations

import UIKit
import SnapKit

// MARK: - Task Card Component
class LGTaskCard: LGAdaptiveView {
    
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let dueDateLabel = UILabel()
    private let priorityIndicator = UIView()
    private let priorityLabel = UILabel()
    private let projectPill = LGProjectPill()
    private let progressBar = LGProgressBar()
    private let checkboxButton = UIButton()
    private let actionStackView = UIStackView()
    
    // MARK: - Properties
    var task: TaskCardData? {
        didSet {
            updateContent()
        }
    }
    
    var onTaskToggle: ((Bool) -> Void)?
    var onTaskTap: (() -> Void)?
    var onProjectTap: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    // MARK: - Setup
    private func setupCard() {
        setupCardProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
        setupAnimations()
    }
    
    private func setupCardProperties() {
        // Enhanced glass effect for task cards
        glassIntensity = 0.85
        cornerRadius = LGLayoutConstants.cardCornerRadius
        
        // Add subtle shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.1
        
        // Enable user interaction
        isUserInteractionEnabled = true
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tapGesture)
    }
    
    private func setupSubviews() {
        // Configure title label
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        
        // Configure description label
        descriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 3
        
        // Configure due date label
        dueDateLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        dueDateLabel.textColor = LGThemeManager.shared.accentColor
        
        // Configure priority indicator
        priorityIndicator.layer.cornerRadius = 4
        priorityLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize - 2, weight: .medium)
        priorityLabel.textColor = .white
        priorityLabel.textAlignment = .center
        
        // Configure checkbox
        setupCheckbox()
        
        // Configure action stack
        actionStackView.axis = .horizontal
        actionStackView.spacing = 8
        actionStackView.alignment = .center
        
        // Add subviews
        [titleLabel, descriptionLabel, dueDateLabel, priorityIndicator, 
         projectPill, progressBar, checkboxButton, actionStackView].forEach {
            addSubview($0)
        }
        
        priorityIndicator.addSubview(priorityLabel)
    }
    
    private func setupCheckbox() {
        checkboxButton.setImage(UIImage(systemName: "circle"), for: .normal)
        checkboxButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkboxButton.tintColor = LGThemeManager.shared.accentColor
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        
        // Adaptive sizing
        let checkboxSize: CGFloat = LGDevice.isIPad ? 28 : 24
        checkboxButton.snp.makeConstraints { make in
            make.width.height.equalTo(checkboxSize)
        }
    }
    
    private func setupConstraints() {
        let margin = LGLayoutConstants.horizontalMargin
        let verticalSpacing: CGFloat = LGDevice.isIPad ? 12 : 8
        
        // Checkbox positioning
        checkboxButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(margin)
            make.leading.equalToSuperview().offset(margin)
        }
        
        // Title label
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(margin)
            make.leading.equalTo(checkboxButton.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-margin)
        }
        
        // Description label
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(verticalSpacing)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-margin)
        }
        
        // Project pill
        projectPill.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(verticalSpacing)
            make.leading.equalTo(titleLabel)
            make.height.equalTo(LGDevice.isIPad ? 32 : 28)
        }
        
        // Progress bar
        progressBar.snp.makeConstraints { make in
            make.top.equalTo(projectPill.snp.bottom).offset(verticalSpacing)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-margin)
            make.height.equalTo(4)
        }
        
        // Priority indicator
        priorityIndicator.snp.makeConstraints { make in
            make.top.equalTo(progressBar.snp.bottom).offset(verticalSpacing)
            make.leading.equalTo(titleLabel)
            make.height.equalTo(LGDevice.isIPad ? 24 : 20)
        }
        
        // Priority label
        priorityLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }
        
        // Due date label
        dueDateLabel.snp.makeConstraints { make in
            make.centerY.equalTo(priorityIndicator)
            make.trailing.equalToSuperview().offset(-margin)
        }
        
        // Action stack view
        actionStackView.snp.makeConstraints { make in
            make.top.equalTo(priorityIndicator.snp.bottom).offset(verticalSpacing)
            make.trailing.equalToSuperview().offset(-margin)
            make.bottom.equalToSuperview().offset(-margin)
        }
        
        // Set minimum height
        self.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(LGLayoutConstants.cardMinHeight)
        }
    }
    
    private func setupInteractions() {
        // Add long press for additional actions
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(cardLongPressed))
        longPress.minimumPressDuration = LGDevice.isIPad ? 0.3 : 0.5
        addGestureRecognizer(longPress)
        
        // Project pill tap
        projectPill.onTap = { [weak self] in
            self?.onProjectTap?()
        }
    }
    
    private func setupAnimations() {
        // Add hover effect for iPad
        if LGDevice.isIPad {
            let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(hoverChanged(_:)))
            addGestureRecognizer(hoverGesture)
        }
    }
    
    // MARK: - Content Updates
    private func updateContent() {
        guard let task = task else { return }
        
        titleLabel.text = task.title
        descriptionLabel.text = task.description
        descriptionLabel.isHidden = task.description?.isEmpty ?? true
        
        // Update checkbox state
        checkboxButton.isSelected = task.isCompleted
        
        // Update due date
        if let dueDate = task.dueDate {
            dueDateLabel.text = formatDueDate(dueDate)
            dueDateLabel.isHidden = false
        } else {
            dueDateLabel.isHidden = true
        }
        
        // Update priority
        updatePriorityIndicator(task.priority)
        
        // Update project
        if let project = task.project {
            projectPill.configure(with: project)
            projectPill.isHidden = false
        } else {
            projectPill.isHidden = true
        }
        
        // Update progress
        progressBar.setProgress(task.progress, animated: true)
        progressBar.isHidden = task.progress <= 0
        
        // Update visual state based on completion
        updateCompletionState(task.isCompleted)
    }
    
    private func updatePriorityIndicator(_ priority: TaskPriority) {
        switch priority {
        case .high:
            priorityIndicator.backgroundColor = .systemRed
            priorityLabel.text = "High"
        case .medium:
            priorityIndicator.backgroundColor = .systemOrange
            priorityLabel.text = "Medium"
        case .low:
            priorityIndicator.backgroundColor = .systemGreen
            priorityLabel.text = "Low"
        }
    }
    
    private func updateCompletionState(_ isCompleted: Bool) {
        let alpha: CGFloat = isCompleted ? 0.6 : 1.0
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.titleLabel.alpha = alpha
            self.descriptionLabel.alpha = alpha
            self.projectPill.alpha = alpha
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    @objc private func cardTapped() {
        // Add tap animation
        animateTap {
            self.onTaskTap?()
        }
    }
    
    @objc private func cardLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Show context menu or additional actions
            showContextMenu()
        }
    }
    
    @objc private func checkboxTapped() {
        let newState = !checkboxButton.isSelected
        checkboxButton.isSelected = newState
        
        // Add checkbox animation
        animateCheckbox(newState)
        
        // Update task state
        task?.isCompleted = newState
        updateCompletionState(newState)
        
        // Notify delegate
        onTaskToggle?(newState)
    }
    
    @objc private func hoverChanged(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            animateHover(true)
        case .ended, .cancelled:
            animateHover(false)
        default:
            break
        }
    }
    
    // MARK: - Animations
    private func animateTap(completion: @escaping () -> Void) {
        UIView.animate(withDuration: LGAnimationDurations.short,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: LGAnimationDurations.short) {
                self.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }
    
    private func animateCheckbox(_ isSelected: Bool) {
        UIView.animate(withDuration: LGAnimationDurations.short,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: [.allowUserInteraction]) {
            self.checkboxButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: LGAnimationDurations.short) {
                self.checkboxButton.transform = .identity
            }
        }
    }
    
    private func animateHover(_ isHovering: Bool) {
        let scale: CGFloat = isHovering ? 1.02 : 1.0
        let shadowOpacity: Float = isHovering ? 0.15 : 0.1
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.layer.shadowOpacity = shadowOpacity
        }
    }
    
    private func showContextMenu() {
        // Implementation for context menu
        // This would show additional actions like edit, delete, duplicate, etc.
    }
}

// MARK: - Task Card Data Model
struct TaskCardData {
    let id: String
    let title: String
    let description: String?
    let dueDate: Date?
    let priority: TaskPriority
    let project: ProjectData?
    let progress: Float
    var isCompleted: Bool
    
    init(id: String, title: String, description: String? = nil, dueDate: Date? = nil, 
         priority: TaskPriority = .medium, project: ProjectData? = nil, 
         progress: Float = 0.0, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.project = project
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

// MARK: - Task Priority Enum
enum TaskPriority: CaseIterable {
    case high, medium, low
    
    var displayName: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        }
    }
    
    var color: UIColor {
        switch self {
        case .high: return .systemRed
        case .medium: return .systemOrange
        case .low: return .systemGreen
        }
    }
}
