import UIKit

final class BootstrapFailureViewController: UIViewController {
    private let message: String
    private let onRetrySync: (() -> Void)?
    private let onRecoverFromICloud: (() -> Void)?
    private var isWorking = false

    private lazy var cardView: LifeBoardCardView = {
        let card = LifeBoardCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.elevated = true
        return card
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "LifeBoard Could Not Start"
        label.font = LifeBoardUIKitTokens.typography.screenTitle
        label.textColor = LifeBoardUIKitTokens.color.textPrimary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = LifeBoardUIKitTokens.typography.body
        label.textColor = LifeBoardUIKitTokens.color.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Retry sync or recover this device from iCloud."
        label.font = LifeBoardUIKitTokens.typography.callout
        label.textColor = LifeBoardUIKitTokens.color.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Retry Sync"
        configuration.baseBackgroundColor = LifeBoardUIKitTokens.color.actionPrimary
        configuration.baseForegroundColor = LifeBoardUIKitTokens.color.accentOnPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        button.configuration = configuration
        button.titleLabel?.font = LifeBoardUIKitTokens.typography.bodyEmphasis
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var recoverButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Recover from iCloud"
        configuration.baseBackgroundColor = LifeBoardUIKitTokens.color.surfaceSecondary
        configuration.baseForegroundColor = LifeBoardUIKitTokens.color.accentPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        button.configuration = configuration
        button.titleLabel?.font = LifeBoardUIKitTokens.typography.bodyEmphasis
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(recoverTapped), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = LifeBoardUIKitTokens.color.actionPrimary
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
        view.backgroundColor = LifeBoardUIKitTokens.color.bgCanvas

        let icon = UIImageView(
            image: UIImage(
                systemName: "exclamationmark.triangle.fill",
                withConfiguration: UIImage.SymbolConfiguration(textStyle: .largeTitle)
            )
        )
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = LifeBoardUIKitTokens.color.statusWarning
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .vertical)
        icon.accessibilityLabel = "Startup warning"

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
        stack.spacing = LifeBoardUIKitTokens.spacing.s16

        cardView.addSubview(stack)
        view.addSubview(cardView)

        let readableWidth = cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 560)
        readableWidth.priority = .required

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            cardView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            readableWidth,
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -28),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hintLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
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
