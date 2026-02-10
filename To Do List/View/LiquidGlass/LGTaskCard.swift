//
//  LGTaskCard.swift
//  Tasker
//
//  iOS 16+ Liquid Glass Task Card with glass morphism effects
//

import UIKit
import CoreData

class LGTaskCard: LGBaseView {

    // MARK: - Properties

    var task: NTask? {
        didSet { updateUI() }
    }

    var onTap: ((NTask) -> Void)?

    // Theme support
    private var todoColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    
    private let checkboxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.tasker.bodyEmphasis
        label.textColor = .label // Will be updated in updateUI with theme colors
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.tasker.callout
        label.textColor = .label.withAlphaComponent(0.7) // Will be updated in updateUI with theme colors
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let priorityIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 3
        return view
    }()

    private let projectLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.tasker.caption1
        label.textColor = .label.withAlphaComponent(0.8) // Will be updated in updateUI with theme colors
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        cornerRadius = corners.card
        elevationLevel = .e1
        
        addSubview(checkboxButton)
        addSubview(titleLabel)
        addSubview(detailsLabel)
        addSubview(priorityIndicator)
        addSubview(projectLabel)
        
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tapGesture)
        
        NSLayoutConstraint.activate([
            // Checkbox
            checkboxButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: spacing.cardPadding),
            checkboxButton.topAnchor.constraint(equalTo: topAnchor, constant: spacing.cardPadding),
            checkboxButton.widthAnchor.constraint(equalToConstant: spacing.s24),
            checkboxButton.heightAnchor.constraint(equalToConstant: spacing.s24),
            
            // Priority indicator
            priorityIndicator.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: spacing.cardStackVertical),
            priorityIndicator.centerYAnchor.constraint(equalTo: checkboxButton.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: spacing.s4),
            priorityIndicator.heightAnchor.constraint(equalToConstant: spacing.s24),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: spacing.cardStackVertical),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -spacing.cardPadding),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: spacing.cardPadding),
            
            // Details
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: spacing.titleSubtitleGap),
            
            // Project
            projectLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            projectLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            projectLabel.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: spacing.s8),
            projectLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -spacing.cardPadding)
        ])
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        guard let task = task else { return }

        // Title
        titleLabel.text = task.name ?? "Untitled Task"
        titleLabel.textColor = todoColors.textPrimary

        // Checkbox
        let checkboxImage = task.isComplete ?
            UIImage(systemName: "checkmark.circle.fill") :
            UIImage(systemName: "circle")
        checkboxButton.setImage(checkboxImage, for: .normal)
        checkboxButton.tintColor = todoColors.textPrimary

        // Details (due date)
        if let dueDate = task.dueDate as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            detailsLabel.text = "Due: \(formatter.string(from: dueDate))"
        } else {
            detailsLabel.text = "No due date"
        }
        detailsLabel.textColor = todoColors.textPrimary.withAlphaComponent(0.7)

        // Priority indicator - using TaskPriorityConfig for consistency
        let priority = TaskPriorityConfig.Priority(rawValue: task.taskPriority)
        priorityIndicator.backgroundColor = priority.color

        // Project
        projectLabel.text = task.project ?? "Inbox"
        projectLabel.textColor = todoColors.textPrimary.withAlphaComponent(0.8)

        // Strike through if completed
        if task.isComplete {
            titleLabel.attributedText = NSAttributedString(
                string: task.name ?? "Untitled Task",
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            titleLabel.alpha = 0.6
        } else {
            titleLabel.attributedText = nil
            titleLabel.text = task.name ?? "Untitled Task"
            titleLabel.alpha = 1.0
        }

        // Update card background to match theme
        self.backgroundColor = todoColors.surfacePrimary.withAlphaComponent(0.82)
        self.borderColor = todoColors.strokeHairline
    }
    
    // MARK: - Actions
    
    @objc private func checkboxTapped() {
        guard let task = task else { return }
        
        // Toggle completion
        task.isComplete.toggle()
        
        // Save context
        if let context = task.managedObjectContext, context.hasChanges {
            try? context.save()
        }
        
        // Animate
        UIView.animate(withDuration: 0.3) {
            self.updateUI()
        }
        
        // Post notification
        NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
    }
    
    @objc private func cardTapped() {
        guard let task = task else { return }
        
        // Animate tap
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        
        onTap?(task)
    }
}
