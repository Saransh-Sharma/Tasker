import UIKit

// MARK: - Delegate

@MainActor
protocol DarkModeToggleCellDelegate: AnyObject {
    func darkModeToggleCell(_ cell: DarkModeToggleCell, didToggle isDark: Bool)
}

// MARK: - Dark Mode Toggle Cell

/// Inline dark mode toggle with UISwitch — no alert confirmation needed
final class DarkModeToggleCell: UITableViewCell {
    static let reuseID = "DarkModeToggleCell"

    weak var delegate: DarkModeToggleCellDelegate?

    private let modeSwitch = UISwitch()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Public API

    func update(isDarkMode: Bool) {
        modeSwitch.isOn = isDarkMode
        updateVisuals(isDark: isDarkMode, animated: false)
    }

    // MARK: - Setup

    private func configure() {
        selectionStyle = .none
        accessibilityIdentifier = "settings.darkModeToggle"

        let colors = TaskerUIKitTokens.color

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = colors.accentPrimary
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = TaskerUIKitTokens.typography.body
        titleLabel.textColor = colors.textPrimary
        contentView.addSubview(titleLabel)

        // Switch
        modeSwitch.translatesAutoresizingMaskIntoConstraints = false
        modeSwitch.onTintColor = colors.accentPrimary
        modeSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        contentView.addSubview(modeSwitch)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            modeSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            modeSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])

        // Set initial visuals
        updateVisuals(isDark: false, animated: false)
    }

    private func updateVisuals(isDark: Bool, animated: Bool) {
        let iconName = isDark ? "moon.fill" : "sun.max.fill"
        let title = isDark ? "Dark Mode" : "Light Mode"

        if animated {
            UIView.transition(with: iconView, duration: 0.25, options: .transitionCrossDissolve) {
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                self.iconView.image = UIImage(systemName: iconName, withConfiguration: config)
            }
            UIView.transition(with: titleLabel, duration: 0.25, options: .transitionCrossDissolve) {
                self.titleLabel.text = title
            }
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            iconView.image = UIImage(systemName: iconName, withConfiguration: config)
            titleLabel.text = title
        }
    }

    // MARK: - Actions

    @objc private func switchChanged() {
        TaskerFeedback.selection()
        updateVisuals(isDark: modeSwitch.isOn, animated: true)
        delegate?.darkModeToggleCell(self, didToggle: modeSwitch.isOn)
    }
}
