import UIKit

final class BootstrapFailureViewController: UIViewController {
    private let message: String
    private let onRetrySync: (() -> Void)?
    private let onRecoverFromICloud: (() -> Void)?
    private var isWorking = false

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Tasker Could Not Start"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Retry sync or recover this device from iCloud."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Retry Sync", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        button.configuration = .filled()
        return button
    }()

    private lazy var recoverButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Recover from iCloud", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(recoverTapped), for: .touchUpInside)
        button.configuration = .borderedProminent()
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// Initializes a new instance.
    init(
        message: String,
        onRetrySync: (() -> Void)? = nil,
        onRecoverFromICloud: (() -> Void)? = nil
    ) {
        self.message = message
        self.onRetrySync = onRetrySync
        self.onRecoverFromICloud = onRecoverFromICloud
        super.init(nibName: nil, bundle: nil)
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .systemOrange
        icon.contentMode = .scaleAspectFit

        let actionStack = UIStackView(arrangedSubviews: [retryButton, recoverButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .vertical
        actionStack.spacing = 10
        actionStack.alignment = .fill
        actionStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            icon,
            titleLabel,
            messageLabel,
            hintLabel,
            actionStack,
            activityIndicator
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16

        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hintLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.9),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            recoverButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    func setWorking(_ isWorking: Bool, hint: String? = nil) {
        self.isWorking = isWorking
        retryButton.isEnabled = !isWorking
        recoverButton.isEnabled = !isWorking
        if let hint {
            hintLabel.text = hint
        }
        if isWorking {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    @objc private func retryTapped() {
        guard isWorking == false else { return }
        setWorking(true, hint: "Retrying sync bootstrap...")
        onRetrySync?()
    }

    @objc private func recoverTapped() {
        guard isWorking == false else { return }
        setWorking(true, hint: "Recovering local cache from iCloud...")
        onRecoverFromICloud?()
    }
}
