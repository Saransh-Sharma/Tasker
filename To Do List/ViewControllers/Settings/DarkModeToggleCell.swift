import UIKit

// MARK: - System Appearance Cell

/// Legacy compatibility cell that now explains system appearance instead of toggling app-specific themes.
final class DarkModeToggleCell: UITableViewCell {
    static let reuseID = "DarkModeToggleCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let modeBadge = UILabel()

    /// Initializes a new instance.
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Public API

    /// Executes update.
    func update(isDarkMode: Bool) {
        updateVisuals(isDark: isDarkMode)
    }

    // MARK: - Setup

    /// Executes configure.
    private func configure() {
        selectionStyle = .none
        accessibilityIdentifier = "settings.appearance.info"

        let colors = TaskerUIKitTokens.color

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = colors.accentPrimary
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = TaskerUIKitTokens.typography.bodyStrong
        titleLabel.textColor = colors.textPrimary
        contentView.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = TaskerUIKitTokens.typography.meta
        subtitleLabel.textColor = colors.textSecondary
        subtitleLabel.numberOfLines = 2
        subtitleLabel.text = "Tasker follows your device's light or dark appearance automatically."
        contentView.addSubview(subtitleLabel)

        modeBadge.translatesAutoresizingMaskIntoConstraints = false
        modeBadge.font = TaskerUIKitTokens.typography.monoMeta
        modeBadge.textColor = colors.textInverse
        modeBadge.backgroundColor = colors.accentPrimary
        modeBadge.layer.cornerRadius = 12
        modeBadge.layer.cornerCurve = .continuous
        modeBadge.clipsToBounds = true
        modeBadge.textAlignment = .center
        contentView.addSubview(modeBadge)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            modeBadge.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            modeBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            modeBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            modeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 74),
            modeBadge.heightAnchor.constraint(equalToConstant: 24),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        // Set initial visuals
        updateVisuals(isDark: traitCollection.userInterfaceStyle == .dark)
    }

    /// Executes updateVisuals.
    private func updateVisuals(isDark: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "circle.lefthalf.filled", withConfiguration: config)
        titleLabel.text = "System Appearance"
        modeBadge.text = isDark ? "Dark" : "Light"
    }
}
