// LGTaskDetailCards.swift
// Task detail card components with glass morphism effects - Phase 4 Implementation
// Specialized cards for displaying task information with interactive elements

import UIKit
import SnapKit

// MARK: - LGTaskHeaderCard

class LGTaskHeaderCard: LGBaseView {
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let statusBadge = LGBadge()
    private let priorityIndicator = LGPriorityIndicator()
    private let progressView = LGProgressBar()
    private let dueDateLabel = UILabel()
    private let overdueWarning = LGWarningBadge()
    
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
        glassIntensity = 0.4
        cornerRadius = LGDevice.isIPad ? 16 : 12
        enableGlassBorder = true
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        titleLabel.numberOfLines = 0
        
        dueDateLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        dueDateLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        progressView.style = .info
        progressView.cornerRadius = 4
        
        overdueWarning.isHidden = true
        
        addSubview(titleLabel)
        addSubview(statusBadge)
        addSubview(priorityIndicator)
        addSubview(progressView)
        addSubview(dueDateLabel)
        addSubview(overdueWarning)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(statusBadge.snp.leading).offset(-12)
        }
        
        statusBadge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(80)
            make.height.equalTo(28)
        }
        
        priorityIndicator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalTo(titleLabel)
            make.width.equalTo(100)
            make.height.equalTo(24)
        }
        
        progressView.snp.makeConstraints { make in
            make.top.equalTo(priorityIndicator.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(8)
        }
        
        dueDateLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        overdueWarning.snp.makeConstraints { make in
            make.centerY.equalTo(dueDateLabel)
            make.leading.equalTo(dueDateLabel.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(120)
        }
    }
    
    // MARK: - Configuration
    
    func configure(with task: NTask) {
        titleLabel.text = task.taskName ?? "Untitled Task"
        
        // Status badge
        statusBadge.configure(
            text: task.isComplete ? "Complete" : "Pending",
            style: task.isComplete ? .success : .info
        )
        
        // Priority indicator
        let priority = TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium
        priorityIndicator.configure(priority: priority)
        
        // Progress
        let progress: Float = task.isComplete ? 1.0 : 0.0
        progressView.setProgressWithMorphing(progress, morphState: .liquidWave, animated: true)
        
        // Due date
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            dueDateLabel.text = "Due: \(formatter.string(from: dueDate))"
            
            // Check if overdue
            let isOverdue = !task.isComplete && dueDate < Date()
            overdueWarning.isHidden = !isOverdue
            if isOverdue {
                overdueWarning.configure(text: "Overdue", style: .error)
            }
        } else {
            dueDateLabel.text = "No due date"
            overdueWarning.isHidden = true
        }
    }
}

// MARK: - LGTaskDetailsCard

class LGTaskDetailsCard: LGBaseView {
    
    // MARK: - UI Components
    private let sectionTitleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let emptyStateLabel = UILabel()
    
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
        glassIntensity = 0.3
        cornerRadius = LGDevice.isIPad ? 16 : 12
        enableGlassBorder = true
        
        sectionTitleLabel.text = "Description"
        sectionTitleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        sectionTitleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        descriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        descriptionLabel.textColor = LGThemeManager.shared.primaryTextColor
        descriptionLabel.numberOfLines = 0
        
        emptyStateLabel.text = "No description provided"
        emptyStateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        emptyStateLabel.textColor = LGThemeManager.shared.tertiaryTextColor
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = true
        
        addSubview(sectionTitleLabel)
        addSubview(descriptionLabel)
        addSubview(emptyStateLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        sectionTitleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(40)
        }
    }
    
    // MARK: - Configuration
    
    func configure(with task: NTask) {
        let description = task.taskDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if description.isEmpty {
            descriptionLabel.isHidden = true
            emptyStateLabel.isHidden = false
        } else {
            descriptionLabel.text = description
            descriptionLabel.isHidden = false
            emptyStateLabel.isHidden = true
        }
    }
}

// MARK: - LGTaskMetadataCard

class LGTaskMetadataCard: LGBaseView {
    
    // MARK: - UI Components
    private let sectionTitleLabel = UILabel()
    private let metadataStackView = UIStackView()
    
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
        glassIntensity = 0.3
        cornerRadius = LGDevice.isIPad ? 16 : 12
        enableGlassBorder = true
        
        sectionTitleLabel.text = "Details"
        sectionTitleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        sectionTitleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        metadataStackView.axis = .vertical
        metadataStackView.spacing = 12
        metadataStackView.alignment = .fill
        
        addSubview(sectionTitleLabel)
        addSubview(metadataStackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        sectionTitleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        
        metadataStackView.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
    // MARK: - Configuration
    
    func configure(with task: NTask) {
        // Clear existing metadata
        metadataStackView.arrangedSubviews.forEach { view in
            metadataStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Project
        if let project = task.taskProject {
            let projectRow = createMetadataRow(
                icon: "folder.fill",
                title: "Project",
                value: project.projectName ?? "Untitled Project",
                color: UIColor(named: project.projectColor ?? "systemBlue") ?? .systemBlue
            )
            metadataStackView.addArrangedSubview(projectRow)
        }
        
        // Creation date
        if let creationDate = task.dateCreated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let creationRow = createMetadataRow(
                icon: "calendar.badge.plus",
                title: "Created",
                value: formatter.string(from: creationDate)
            )
            metadataStackView.addArrangedSubview(creationRow)
        }
        
        // Completion date
        if let completionDate = task.dateCompleted {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let completionRow = createMetadataRow(
                icon: "checkmark.circle.fill",
                title: "Completed",
                value: formatter.string(from: completionDate),
                color: .systemGreen
            )
            metadataStackView.addArrangedSubview(completionRow)
        }
        
        // Reminder
        if let reminderDate = task.reminderDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let reminderRow = createMetadataRow(
                icon: "bell.fill",
                title: "Reminder",
                value: formatter.string(from: reminderDate),
                color: .systemOrange
            )
            metadataStackView.addArrangedSubview(reminderRow)
        }
    }
    
    private func createMetadataRow(icon: String, title: String, value: String, color: UIColor = .systemGray) -> UIView {
        let container = UIView()
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = color
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        valueLabel.textColor = LGThemeManager.shared.primaryTextColor
        valueLabel.numberOfLines = 0
        
        container.addSubview(iconImageView)
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.equalToSuperview()
            make.width.equalTo(80)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
        
        container.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(24)
        }
        
        return container
    }
}

// MARK: - LGTaskActionsCard

class LGTaskActionsCard: LGBaseView {
    
    // MARK: - UI Components
    private let sectionTitleLabel = UILabel()
    private let actionsStackView = UIStackView()
    private let deleteButton = LGButton(style: .destructive, size: .medium)
    private let duplicateButton = LGButton(style: .secondary, size: .medium)
    private let shareButton = LGButton(style: .secondary, size: .medium)
    
    // MARK: - Callbacks
    var onDeleteTapped: (() -> Void)?
    var onDuplicateTapped: (() -> Void)?
    var onShareTapped: (() -> Void)?
    
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
        glassIntensity = 0.3
        cornerRadius = LGDevice.isIPad ? 16 : 12
        enableGlassBorder = true
        
        sectionTitleLabel.text = "Actions"
        sectionTitleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        sectionTitleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 12
        actionsStackView.alignment = .fill
        actionsStackView.distribution = .fillEqually
        
        // Configure buttons
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.icon = UIImage(systemName: "trash")
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        duplicateButton.setTitle("Duplicate", for: .normal)
        duplicateButton.icon = UIImage(systemName: "doc.on.doc")
        duplicateButton.addTarget(self, action: #selector(duplicateButtonTapped), for: .touchUpInside)
        
        shareButton.setTitle("Share", for: .normal)
        shareButton.icon = UIImage(systemName: "square.and.arrow.up")
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        actionsStackView.addArrangedSubview(duplicateButton)
        actionsStackView.addArrangedSubview(shareButton)
        actionsStackView.addArrangedSubview(deleteButton)
        
        addSubview(sectionTitleLabel)
        addSubview(actionsStackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        sectionTitleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        
        actionsStackView.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(44)
        }
    }
    
    // MARK: - Actions
    
    @objc private func deleteButtonTapped() {
        deleteButton.morphButton(to: .pressed) {
            self.deleteButton.morphButton(to: .idle)
        }
        onDeleteTapped?()
    }
    
    @objc private func duplicateButtonTapped() {
        duplicateButton.morphButton(to: .pressed) {
            self.duplicateButton.morphButton(to: .idle)
        }
        onDuplicateTapped?()
    }
    
    @objc private func shareButtonTapped() {
        shareButton.morphButton(to: .pressed) {
            self.shareButton.morphButton(to: .idle)
        }
        onShareTapped?()
    }
    
    // MARK: - Configuration
    
    func configure(with task: NTask) {
        // Update button states based on task
        deleteButton.isEnabled = true
        duplicateButton.isEnabled = true
        shareButton.isEnabled = true
    }
}

// MARK: - Supporting Components

class LGBadge: UIView {
    
    enum Style {
        case info, success, warning, error
        
        var backgroundColor: UIColor {
            switch self {
            case .info: return .systemBlue
            case .success: return .systemGreen
            case .warning: return .systemOrange
            case .error: return .systemRed
            }
        }
    }
    
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        layer.cornerRadius = 14
        
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }
    
    func configure(text: String, style: Style) {
        label.text = text
        backgroundColor = style.backgroundColor
    }
}

class LGPriorityIndicator: UIView {
    
    private let iconImageView = UIImageView()
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        iconImageView.contentMode = .scaleAspectFit
        
        label.font = .systemFont(ofSize: 14, weight: .medium)
        
        addSubview(iconImageView)
        addSubview(label)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(6)
            make.trailing.centerY.equalToSuperview()
        }
    }
    
    func configure(priority: TaskPriority) {
        iconImageView.image = UIImage(systemName: priority.iconName)
        iconImageView.tintColor = priority.color
        label.text = priority.displayName
        label.textColor = priority.color
    }
}

class LGWarningBadge: UIView {
    
    private let iconImageView = UIImageView()
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemRed
        iconImageView.contentMode = .scaleAspectFit
        
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .systemRed
        
        addSubview(iconImageView)
        addSubview(label)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }
        
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(4)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        
        snp.makeConstraints { make in
            make.height.equalTo(24)
        }
    }
    
    func configure(text: String, style: LGBadge.Style) {
        label.text = text
        
        switch style {
        case .error:
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
            iconImageView.tintColor = .systemRed
            label.textColor = .systemRed
        case .warning:
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
            layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
            iconImageView.tintColor = .systemOrange
            label.textColor = .systemOrange
        default:
            break
        }
    }
}
