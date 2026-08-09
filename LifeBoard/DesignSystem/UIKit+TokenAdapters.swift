import UIKit

@MainActor
public enum UIKitTokens {
    public static var color: LifeBoardColorTokens {
        ThemeStore.shared.currentTheme.tokens.color
    }

    public static var typography: LifeBoardTypographyTokens {
        ThemeStore.shared.currentTheme.tokens.typography
    }

    public static var spacing: LifeBoardSpacingTokens {
        ThemeStore.shared.currentTheme.tokens.spacing
    }

    public static var elevation: ElevationTokens {
        ThemeStore.shared.currentTheme.tokens.elevation
    }

    public static var corner: CornerTokens {
        ThemeStore.shared.currentTheme.tokens.corner
    }
}

@MainActor
public extension UIColor {
    static var lifeboard: LifeBoardColorTokens {
        UIKitTokens.color
    }
}

public extension UIColor {
    static func lifeboard(_ role: ColorRole) -> UIColor {
        ThreadSafeTokenResolver.color(for: role)
    }
}

@MainActor
public extension UIFont {
    static var lifeboard: LifeBoardTypographyTokens {
        UIKitTokens.typography
    }
}

public extension UIView {
    /// Executes applyLifeBoardElevation.
    @MainActor
    func applyLifeBoardElevation(_ level: ElevationLevel) {
        let style = UIKitTokens.elevation.style(for: level)
        layer.shadowColor = style.shadowColor.cgColor
        layer.shadowOpacity = style.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: style.shadowOffsetY)
        layer.shadowRadius = style.shadowBlur / 2
        layer.borderWidth = style.borderWidth
        layer.borderColor = style.borderColor.cgColor
        layer.masksToBounds = false
    }

    /// Executes applyLifeBoardCorner.
    @MainActor
    func applyLifeBoardCorner(_ token: CornerToken) {
        let value = UIKitTokens.corner.value(for: token, height: bounds.height)
        layer.cornerRadius = value
        layer.cornerCurve = .continuous
    }
}

@MainActor
public struct NavButtonStyle {
    public static let minimumHitTarget = CGSize(width: 44, height: 44)
    public static let pressedAlpha: CGFloat = 0.6
    public static let pressedDuration: TimeInterval = 0.12

    /// Executes titleColor.
    public static func titleColor(
        context: NavButtonContext,
        emphasis: NavButtonEmphasis,
        enabled: Bool = true
    ) -> UIColor {
        let colors = UIKitTokens.color
        let base: UIColor

        switch (context, emphasis) {
        case (.onGradient, .filled):
            base = colors.accentOnPrimary
        case (.onGradient, .normal), (.onGradient, .done):
            base = colors.textInverse
        case (.onSurface, .normal):
            base = colors.textSecondary
        case (.onSurface, .done):
            base = colors.accentPrimary
        case (.onSurface, .filled):
            base = colors.accentOnPrimary
        }

        return enabled ? base : base.withAlphaComponent(0.3)
    }

    /// Executes attributes.
    public static func attributes(
        context: NavButtonContext,
        emphasis: NavButtonEmphasis,
        enabled: Bool = true
    ) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: titleColor(context: context, emphasis: emphasis, enabled: enabled),
            .font: UIKitTokens.typography.bodyEmphasis
        ]
    }

    /// Executes apply.
    public static func apply(
        to item: UIBarButtonItem,
        context: NavButtonContext,
        emphasis: NavButtonEmphasis
    ) {
        item.setTitleTextAttributes(attributes(context: context, emphasis: emphasis, enabled: true), for: .normal)
        item.setTitleTextAttributes(
            [
                .foregroundColor: titleColor(context: context, emphasis: emphasis, enabled: true).withAlphaComponent(pressedAlpha),
                .font: UIKitTokens.typography.bodyEmphasis
            ],
            for: .highlighted
        )
        item.setTitleTextAttributes(attributes(context: context, emphasis: emphasis, enabled: false), for: .disabled)
    }
}

@MainActor
public final class LifeBoardTextField: UITextField {
    public enum Kind {
        case singleLine
        case multiline
    }

    public let kind: Kind
    private let colors = UIKitTokens.color
    private let corners = UIKitTokens.corner

    /// Initializes a new instance.
    public init(kind: Kind = .singleLine) {
        self.kind = kind
        super.init(frame: .zero)
        configure()
    }

    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        self.kind = .singleLine
        super.init(coder: coder)
        configure()
    }

    /// Executes configure.
    private func configure() {
        font = UIKitTokens.typography.body
        textColor = colors.textPrimary
        tintColor = colors.actionPrimary
        backgroundColor = colors.surfaceSecondary
        layer.cornerRadius = corners.r2
        layer.cornerCurve = .continuous
        layer.borderColor = colors.borderDefault.cgColor
        layer.borderWidth = 1
        clearButtonMode = .whileEditing
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)

        let targetHeight: CGFloat = kind == .singleLine
            ? TextFieldTokens.singleLineHeight
            : TextFieldTokens.multilineMinHeight
        heightAnchor.constraint(greaterThanOrEqualToConstant: targetHeight).isActive = true
    }

    /// Executes setLifeBoardPlaceholder.
    public func setLifeBoardPlaceholder(_ text: String) {
        attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: colors.textQuaternary,
                .font: UIKitTokens.typography.body
            ]
        )
    }

    @objc private func editingDidBegin() {
        layer.borderColor = colors.actionFocus.cgColor
        layer.borderWidth = 2
    }

    @objc private func editingDidEnd() {
        layer.borderColor = colors.borderDefault.cgColor
        layer.borderWidth = 1
    }
}

@MainActor
public final class ChipView: UIControl {
    public let titleLabel = UILabel()
    public var selectedStyle: ChipSelectionStyle = .tinted {
        didSet { refreshAppearance() }
    }

    public override var isSelected: Bool {
        didSet { refreshAppearance() }
    }

    /// Initializes a new instance.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Executes setTitle.
    public func setTitle(_ text: String) {
        titleLabel.text = text
    }

    /// Executes configure.
    private func configure() {
        let spacing = UIKitTokens.spacing
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIKitTokens.typography.callout
        titleLabel.textAlignment = .center
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: spacing.s12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -spacing.s12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: spacing.s8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -spacing.s8),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        layer.cornerRadius = UIKitTokens.corner.chip
        layer.cornerCurve = .continuous
        refreshAppearance()
    }

    /// Executes refreshAppearance.
    private func refreshAppearance() {
        let colors = UIKitTokens.color
        if isSelected {
            switch selectedStyle {
            case .tinted:
                backgroundColor = colors.accentWash
                titleLabel.textColor = colors.actionPrimary
                layer.borderColor = colors.actionFocus.cgColor
                layer.borderWidth = 1
            case .filled:
                backgroundColor = colors.chipSelectedBackground
                titleLabel.textColor = colors.accentOnPrimary
                layer.borderColor = UIColor.clear.cgColor
                layer.borderWidth = 0
            }
        } else {
            backgroundColor = colors.chipUnselectedBackground
            titleLabel.textColor = colors.textSecondary
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
        }
    }
}

@MainActor
public final class CardView: UIView {
    public var highlighted = false {
        didSet { applyStyle() }
    }

    public var elevated = false {
        didSet { applyStyle() }
    }

    /// Initializes a new instance.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        applyStyle()
    }

    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyStyle()
    }

    /// Executes applyStyle.
    private func applyStyle() {
        let colors = UIKitTokens.color
        backgroundColor = colors.surfacePrimary
        layer.cornerRadius = UIKitTokens.corner.r3
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = (highlighted ? colors.borderStrong : colors.borderDefault).cgColor
        applyLifeBoardElevation(elevated ? .e2 : .e1)
    }
}

public extension TaskPriorityConfig.Priority {
    @MainActor
    var color: UIColor {
        let colors = UIKitTokens.color
        switch self {
        case .none: return colors.priorityNone
        case .low:  return colors.priorityLow
        case .high: return colors.priorityHigh
        case .max:  return colors.priorityMax
        }
    }
}

public extension ProjectColor {
    var uiColor: UIColor {
        UIColor(lifeboardHex: hexString)
    }
}

public extension ProjectHealth {
    var color: UIColor {
        UIColor(lifeboardHex: colorHex)
    }
}
