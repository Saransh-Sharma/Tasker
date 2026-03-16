import UIKit

final class ThemeSelectionViewController: UIViewController {
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Brand Palette"
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        configureStack()
    }

    private func configureStack() {
        let spacing = TaskerThemeManager.shared.currentTheme.tokens.spacing
        let colors = TaskerThemeManager.shared.currentTheme

        stackView.axis = .vertical
        stackView.spacing = spacing.s16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.font = UIFont.tasker.screenTitle
        header.textColor = TaskerUIKitTokens.color.textPrimary
        header.text = "Tasker now uses one rooted Sarvam-inspired brand across every screen."
        header.numberOfLines = 0

        let preview = BrandPalettePreviewView(theme: colors)
        let footnote = UILabel()
        footnote.font = UIFont.tasker.meta
        footnote.textColor = TaskerUIKitTokens.color.textSecondary
        footnote.text = "Light and dark appearance follow your system settings automatically."
        footnote.numberOfLines = 0

        stackView.addArrangedSubview(header)
        stackView.addArrangedSubview(preview)
        stackView.addArrangedSubview(footnote)
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: spacing.screenHorizontal),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -spacing.screenHorizontal),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: spacing.s24)
        ])
    }
}

final class ThemeDebugSwatchesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Brand QA"
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas

        let preview = BrandPalettePreviewView(theme: TaskerThemeManager.shared.currentTheme)
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preview)

        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }
}

final class BrandPalettePreviewView: UIView {
    init(theme: TaskerTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TaskerUIKitTokens.color.surfacePrimary
        layer.cornerRadius = TaskerUIKitTokens.corner.card
        layer.cornerCurve = .continuous
        applyTaskerElevation(.e1)

        let titleLabel = UILabel()
        titleLabel.font = UIFont.tasker.eyebrow
        titleLabel.textColor = TaskerUIKitTokens.color.textTertiary
        titleLabel.text = "SARVAM-INSPIRED PALETTE"

        let swatchStack = UIStackView()
        swatchStack.axis = .horizontal
        swatchStack.distribution = .fillEqually
        swatchStack.spacing = 10

        let swatches: [(String, UIColor)] = [
            ("Emerald", theme.palette.brandEmerald),
            ("Magenta", theme.palette.brandMagenta),
            ("Marigold", theme.palette.brandMarigold),
            ("Red", theme.palette.brandRed),
            ("Sandstone", theme.palette.brandSandstone)
        ]

        swatches.forEach { swatch in
            swatchStack.addArrangedSubview(makeSwatch(name: swatch.0, color: swatch.1))
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, swatchStack])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            swatchStack.heightAnchor.constraint(equalToConstant: 86)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeSwatch(name: String, color: UIColor) -> UIView {
        let container = UIView()

        let swatch = UIView()
        swatch.backgroundColor = color
        swatch.layer.cornerRadius = 14
        swatch.layer.cornerCurve = .continuous
        swatch.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = UIFont.tasker.caption2
        label.textColor = TaskerUIKitTokens.color.textSecondary
        label.textAlignment = .center
        label.text = name
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(swatch)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            swatch.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            swatch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            swatch.topAnchor.constraint(equalTo: container.topAnchor),
            swatch.heightAnchor.constraint(equalToConstant: 56),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: swatch.bottomAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }
}
