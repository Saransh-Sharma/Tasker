import UIKit

final class ThemeSelectionViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Brand Palette"
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        configureStack()
    }

    private func configureStack() {
        let spacing = LifeBoardThemeManager.shared.currentTheme.tokens.spacing
        let colors = LifeBoardThemeManager.shared.currentTheme

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = spacing.s16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.font = UIFont.lifeboard.screenTitle
        header.textColor = LifeBoardUIKitTokens.color.textPrimary
        header.text = "LifeBoard now uses one rooted Sarvam-inspired brand across every screen."
        header.numberOfLines = 0

        let preview = BrandPalettePreviewView(theme: colors)
        let footnote = UILabel()
        footnote.font = UIFont.lifeboard.meta
        footnote.textColor = LifeBoardUIKitTokens.color.textSecondary
        footnote.text = "Light and dark appearance follow your system settings automatically."
        footnote.numberOfLines = 0

        stackView.addArrangedSubview(header)
        stackView.addArrangedSubview(preview)
        stackView.addArrangedSubview(footnote)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: spacing.screenHorizontal),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -spacing.screenHorizontal),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: spacing.s24),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -spacing.s24),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
}

#if DEBUG
final class ThemeDebugSwatchesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Brand QA"
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        let preview = BrandPalettePreviewView(theme: LifeBoardThemeManager.shared.currentTheme)
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preview)

        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }
}
#endif

final class BrandPalettePreviewView: UIView {
    init(theme: LifeBoardTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = LifeBoardUIKitTokens.color.surfacePrimary
        layer.cornerRadius = LifeBoardUIKitTokens.corner.card
        layer.cornerCurve = .continuous
        applyLifeBoardElevation(.e1)

        let titleLabel = UILabel()
        titleLabel.font = UIFont.lifeboard.eyebrow
        titleLabel.textColor = LifeBoardUIKitTokens.color.textTertiary
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
        label.font = UIFont.lifeboard.caption2
        label.textColor = LifeBoardUIKitTokens.color.textSecondary
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
