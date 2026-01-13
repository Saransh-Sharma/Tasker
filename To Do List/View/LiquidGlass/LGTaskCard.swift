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
    private let todoColors = ToDoColors()
    
    private let checkboxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label // Will be updated in updateUI with theme colors
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
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
        label.font = .systemFont(ofSize: 12, weight: .medium)
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
        cornerRadius = 16
        
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
            checkboxButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            checkboxButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            checkboxButton.widthAnchor.constraint(equalToConstant: 24),
            checkboxButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Priority indicator
            priorityIndicator.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 12),
            priorityIndicator.centerYAnchor.constraint(equalTo: checkboxButton.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 6),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            
            // Details
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            // Project
            projectLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            projectLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            projectLabel.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 8),
            projectLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        guard let task = task else { return }

        // Title
        titleLabel.text = task.name ?? "Untitled Task"
        titleLabel.textColor = todoColors.primaryTextColor

        // Checkbox
        let checkboxImage = task.isComplete ?
            UIImage(systemName: "checkmark.circle.fill") :
            UIImage(systemName: "circle")
        checkboxButton.setImage(checkboxImage, for: .normal)
        checkboxButton.tintColor = todoColors.primaryTextColor

        // Details (due date)
        if let dueDate = task.dueDate as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            detailsLabel.text = "Due: \(formatter.string(from: dueDate))"
        } else {
            detailsLabel.text = "No due date"
        }
        detailsLabel.textColor = todoColors.primaryTextColor.withAlphaComponent(0.7)

        // Priority indicator - using TaskPriorityConfig for consistency
        let priority = TaskPriorityConfig.Priority(rawValue: task.taskPriority)
        priorityIndicator.backgroundColor = priority.color

        // Project
        projectLabel.text = task.project ?? "Inbox"
        projectLabel.textColor = todoColors.primaryTextColor.withAlphaComponent(0.8)

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
        self.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.08)
        self.borderColor = todoColors.primaryColor.withAlphaComponent(0.2)
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
