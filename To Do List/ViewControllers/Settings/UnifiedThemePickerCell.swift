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
        addBrandPalettePreview(to: contentView, theme: TaskerThemeManager.shared.currentTheme)
    }
}
