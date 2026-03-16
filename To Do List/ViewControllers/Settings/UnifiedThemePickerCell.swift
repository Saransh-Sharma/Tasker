import UIKit

final class UnifiedThemePickerCell: UITableViewCell {
    static let reuseID = "UnifiedThemePickerCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        configure()
    }

    private func configure() {
        let preview = BrandPalettePreviewView(theme: TaskerThemeManager.shared.currentTheme)
        contentView.addSubview(preview)

        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            preview.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            preview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
