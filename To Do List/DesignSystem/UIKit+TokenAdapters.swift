import UIKit

@MainActor
public enum TaskerUIKitTokens {
    public static var color: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    public static var typography: TaskerTypographyTokens {
        TaskerThemeManager.shared.currentTheme.tokens.typography
    }

    public static var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.currentTheme.tokens.spacing
    }

    public static var elevation: TaskerElevationTokens {
        TaskerThemeManager.shared.currentTheme.tokens.elevation
    }

    public static var corner: TaskerCornerTokens {
        TaskerThemeManager.shared.currentTheme.tokens.corner
    }
}

@MainActor
public extension UIColor {
    static var tasker: TaskerColorTokens {
        TaskerUIKitTokens.color
    }

    static func tasker(_ role: TaskerColorRole) -> UIColor {
        TaskerUIKitTokens.color.color(for: role)
    }
}

@MainActor
public extension UIFont {
    static var tasker: TaskerTypographyTokens {
        TaskerUIKitTokens.typography
    }
}

public extension UIView {
    @MainActor
    func applyTaskerElevation(_ level: TaskerElevationLevel) {
        let style = TaskerUIKitTokens.elevation.style(for: level)
        layer.shadowColor = style.shadowColor.cgColor
        layer.shadowOpacity = style.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: style.shadowOffsetY)
        layer.shadowRadius = style.shadowBlur / 2
        layer.borderWidth = style.borderWidth
        layer.borderColor = style.borderColor.cgColor
        layer.masksToBounds = false
    }

    @MainActor
    func applyTaskerCorner(_ token: TaskerCornerToken) {
        let value = TaskerUIKitTokens.corner.value(for: token, height: bounds.height)
        layer.cornerRadius = value
        layer.cornerCurve = .continuous
    }
}

@MainActor
public struct TaskerNavButtonStyle {
    public static let minimumHitTarget = CGSize(width: 44, height: 44)
    public static let pressedAlpha: CGFloat = 0.6
    public static let pressedDuration: TimeInterval = 0.12

    public static func titleColor(
        context: TaskerNavButtonContext,
        emphasis: TaskerNavButtonEmphasis,
        enabled: Bool = true
    ) -> UIColor {
        let colors = TaskerUIKitTokens.color
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

    public static func attributes(
        context: TaskerNavButtonContext,
        emphasis: TaskerNavButtonEmphasis,
        enabled: Bool = true
    ) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: titleColor(context: context, emphasis: emphasis, enabled: enabled),
            .font: TaskerUIKitTokens.typography.bodyEmphasis
        ]
    }

    public static func apply(
        to item: UIBarButtonItem,
        context: TaskerNavButtonContext,
        emphasis: TaskerNavButtonEmphasis
    ) {
        item.setTitleTextAttributes(attributes(context: context, emphasis: emphasis, enabled: true), for: .normal)
        item.setTitleTextAttributes(
            [
                .foregroundColor: titleColor(context: context, emphasis: emphasis, enabled: true).withAlphaComponent(pressedAlpha),
                .font: TaskerUIKitTokens.typography.bodyEmphasis
            ],
            for: .highlighted
        )
        item.setTitleTextAttributes(attributes(context: context, emphasis: emphasis, enabled: false), for: .disabled)
    }
}

@MainActor
public struct TaskerTextFieldTokens {
    public static let singleLineHeight: CGFloat = 48
    public static let multilineMinHeight: CGFloat = 96
    public static let multilineMaxHeight: CGFloat = 120
}

@MainActor
public final class TaskerTextField: UITextField {
    public enum Kind {
        case singleLine
        case multiline
    }

    public let kind: Kind
    private let colors = TaskerUIKitTokens.color
    private let corners = TaskerUIKitTokens.corner

    public init(kind: Kind = .singleLine) {
        self.kind = kind
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        self.kind = .singleLine
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        font = TaskerUIKitTokens.typography.body
        textColor = colors.textPrimary
        tintColor = colors.accentPrimary
        backgroundColor = colors.surfaceSecondary
        layer.cornerRadius = corners.r2
        layer.cornerCurve = .continuous
        layer.borderColor = colors.strokeHairline.cgColor
        layer.borderWidth = 1
        clearButtonMode = .whileEditing
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)

        let targetHeight: CGFloat = kind == .singleLine
            ? TaskerTextFieldTokens.singleLineHeight
            : TaskerTextFieldTokens.multilineMinHeight
        heightAnchor.constraint(greaterThanOrEqualToConstant: targetHeight).isActive = true
    }

    public func setTaskerPlaceholder(_ text: String) {
        attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: colors.textQuaternary,
                .font: TaskerUIKitTokens.typography.body
            ]
        )
    }

    @objc private func editingDidBegin() {
        layer.borderColor = colors.accentRing.cgColor
        layer.borderWidth = 2
    }

    @objc private func editingDidEnd() {
        layer.borderColor = colors.strokeHairline.cgColor
        layer.borderWidth = 1
    }
}

@MainActor
public final class TaskerChipView: UIControl {
    public let titleLabel = UILabel()
    public var selectedStyle: TaskerChipSelectionStyle = .tinted {
        didSet { refreshAppearance() }
    }

    public override var isSelected: Bool {
        didSet { refreshAppearance() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public func setTitle(_ text: String) {
        titleLabel.text = text
    }

    private func configure() {
        let spacing = TaskerUIKitTokens.spacing
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = TaskerUIKitTokens.typography.callout
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

        layer.cornerRadius = TaskerUIKitTokens.corner.chip
        layer.cornerCurve = .continuous
        refreshAppearance()
    }

    private func refreshAppearance() {
        let colors = TaskerUIKitTokens.color
        if isSelected {
            switch selectedStyle {
            case .tinted:
                backgroundColor = colors.accentMuted
                titleLabel.textColor = colors.accentPrimary
                layer.borderColor = colors.accentRing.cgColor
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
public final class TaskerCardView: UIView {
    public var highlighted = false {
        didSet { applyStyle() }
    }

    public var elevated = false {
        didSet { applyStyle() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        applyStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyStyle()
    }

    private func applyStyle() {
        let colors = TaskerUIKitTokens.color
        backgroundColor = colors.surfacePrimary
        layer.cornerRadius = TaskerUIKitTokens.corner.r3
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = (highlighted ? colors.strokeStrong : colors.strokeHairline).cgColor
        applyTaskerElevation(elevated ? .e2 : .e1)
    }
}

public extension TaskPriorityConfig.Priority {
    var color: UIColor {
        switch self {
        case .none:
            return UIColor.taskerDynamic(lightHex: "#7B808A", darkHex: "#9AA1AD")
        case .low:
            return UIColor(taskerHex: "#34C759")
        case .high:
            return UIColor(taskerHex: "#FF9F0A")
        case .max:
            return UIColor(taskerHex: "#FF3B30")
        }
    }
}

public extension ProjectColor {
    var uiColor: UIColor {
        UIColor(taskerHex: hexString)
    }
}

public extension ProjectHealth {
    var color: UIColor {
        UIColor(taskerHex: colorHex)
    }
}
