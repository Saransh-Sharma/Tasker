import UIKit

class TaskDetailView: UIView {
  
  // MARK: – UI Subviews
  private let titleLabel = UILabel()
  private let descriptionLabel = UILabel()
  private let dueDateLabel = UILabel()
  private let priorityLabel = UILabel()
  private let projectLabel = UILabel()
  private let stack = UIStackView()
  
  // MARK: – Init
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  
  private func setupView() {
    backgroundColor = .white
    layer.cornerRadius = 12
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.1
    layer.shadowRadius = 8
    
    // Configure labels
    [titleLabel, descriptionLabel, dueDateLabel, priorityLabel, projectLabel].forEach {
      $0.numberOfLines = 0
      $0.textColor = .darkText
      $0.font = UIFont.systemFont(ofSize: 16)
    }
    titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
    
    // Stack setup
    stack.axis = .vertical
    stack.spacing = 12
    stack.alignment = .leading
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    
    [titleLabel, descriptionLabel, dueDateLabel, priorityLabel, projectLabel].forEach {
      stack.addArrangedSubview($0)
    }
    
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
    ])
  }
  
  // MARK: – Configuration
  func configure(title: String,
                 description: String,
                 dueDate: String,
                 priority: String,
                 project: String) {
    titleLabel.text = title
    descriptionLabel.text = description
    dueDateLabel.text = "Due: " + dueDate
    priorityLabel.text = "Priority: " + priority
    projectLabel.text = "Project: " + project
  }
}
