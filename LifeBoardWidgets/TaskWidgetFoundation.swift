import SwiftUI
import WidgetKit

extension Color {
    init?(widgetHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let intValue = Int(value, radix: 16) else {
            return nil
        }
        let red = Double((intValue >> 16) & 0xFF) / 255.0
        let green = Double((intValue >> 8) & 0xFF) / 255.0
        let blue = Double(intValue & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

@MainActor
enum TaskWidgetTypography {
    static let eyebrow = LifeBoardTheme.Typography.eyebrow
    static let caption = LifeBoardTheme.Typography.caption
    static let captionStrong = LifeBoardTheme.Typography.captionSemibold
    static let meta = LifeBoardTheme.Typography.meta
    static let support = LifeBoardTheme.Typography.support
    static let body = LifeBoardTheme.Typography.body
    static let bodyStrong = LifeBoardTheme.Typography.bodyStrong
    static let title = LifeBoardTheme.Typography.title3
    static let titleLarge = LifeBoardTheme.Typography.title2
    static let metric = LifeBoardTheme.Typography.metric
    static let display = LifeBoardTheme.Typography.display
    static let mono = LifeBoardTheme.Typography.monoMeta
}

struct TaskWidgetViewContext {
    let family: WidgetFamily
    let renderingMode: WidgetRenderingMode
    let showsContainerBackground: Bool
    let contrast: ColorSchemeContrast
    let reduceMotion: Bool
    let dynamicTypeSize: DynamicTypeSize
    let isStandByLike: Bool

    var isAccented: Bool {
        renderingMode == .accented
    }

    var isAccessory: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            return true
        default:
            return false
        }
    }

    var isBackgroundRemoved: Bool {
        showsContainerBackground == false
    }

    var isHighContrast: Bool {
        contrast == .increased
    }

    var outerPadding: CGFloat {
        if isStandByLike {
            return 14
        }

        switch family {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 10
        case .systemSmall:
            return 9
        case .accessoryInline:
            return 0
        case .accessoryCircular:
            return 2
        case .accessoryRectangular:
            return 4
        default:
            return 6
        }
    }

    var sectionSpacing: CGFloat {
        if isStandByLike {
            return 12
        }

        switch family {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 9
        case .systemSmall:
            return 7
        case .accessoryInline, .accessoryCircular:
            return 4
        case .accessoryRectangular:
            return 5
        default:
            return 7
        }
    }

    var panelSpacing: CGFloat {
        if isStandByLike {
            return 10
        }

        switch family {
        case .systemLarge:
            return 9
        case .systemMedium:
            return 7
        default:
            return 5
        }
    }

    var borderOpacity: Double {
        isHighContrast ? 0.76 : 0.36
    }

    var leadRatio: CGFloat {
        if isStandByLike {
            return 0.68
        }

        switch family {
        case .systemMedium:
            return 0.66
        case .systemLarge:
            return 0.64
        case .accessoryRectangular:
            return 0.56
        default:
            return 0.5
        }
    }

    var supportRatio: CGFloat {
        max(0.01, 1 - leadRatio)
    }

    var supportListLimit: Int {
        switch family {
        case .systemLarge:
            return 3
        case .systemMedium:
            return 2
        case .systemSmall, .accessoryRectangular:
            return 2
        default:
            return 3
        }
    }

    var heroMinHeight: CGFloat {
        if isStandByLike {
            return 92
        }

        switch family {
        case .systemSmall:
            return 88
        case .systemMedium:
            return 96
        case .systemLarge:
            return 104
        default:
            return 0
        }
    }

    var actionBandHeight: CGFloat {
        switch family {
        case .systemSmall:
            return 42
        case .systemMedium, .systemLarge:
            return 40
        default:
            return 34
        }
    }

    var chartHeight: CGFloat {
        if isStandByLike {
            return 118
        }

        switch family {
        case .systemSmall:
            return 70
        case .systemMedium:
            return 108
        case .systemLarge:
            return 132
        default:
            return 56
        }
    }

    var prefersStackedZones: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
}

struct TaskWidgetScene<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var alignment: Alignment = .topLeading
    var isStandByLike: Bool = false
    @ViewBuilder let content: (TaskWidgetViewContext) -> Content

    var body: some View {
        let context = TaskWidgetViewContext(
            family: family,
            renderingMode: renderingMode,
            showsContainerBackground: showsContainerBackground,
            contrast: contrast,
            reduceMotion: reduceMotion,
            dynamicTypeSize: dynamicTypeSize,
            isStandByLike: isStandByLike
        )

        content(context)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(context.outerPadding)
    }
}

struct TaskWidgetContainerBackgroundModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .tint(WidgetBrand.actionPrimary)
                .containerBackground(for: .widget) {
                    WidgetBrand.canvas
                }
        } else {
            content
        }
    }
}

enum TaskWidgetPanelStyle {
    case flush
    case softSection
    case accentWash
    case contained
    case standard
    case quiet
    case accent
    case backgroundRemoved
}

struct TaskWidgetPanel<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    @Environment(\.colorSchemeContrast) private var contrast

    var accent: Color? = nil
    var style: TaskWidgetPanelStyle = .flush
    var padding: CGFloat = 10
    @ViewBuilder let content: () -> Content

    private var resolvedCornerRadius: CGFloat {
        LifeBoardTheme.CornerRadius.card
    }

    private var effectiveAccent: Color {
        accent ?? WidgetBrand.actionPrimary
    }

    private var resolvedStyle: TaskWidgetPanelStyle {
        switch style {
        case .standard:
            return .flush
        case .quiet:
            return .softSection
        case .accent:
            return .accentWash
        case .backgroundRemoved:
            return .contained
        default:
            return style
        }
    }

    private var strokeColor: Color? {
        switch resolvedStyle {
        case .flush:
            return nil
        case .softSection:
            return WidgetBrand.lineStrong.opacity(contrast == .increased ? 0.44 : 0.22)
        case .accentWash:
            return effectiveAccent.opacity(contrast == .increased ? 0.26 : 0.18)
        case .contained:
            return WidgetBrand.lineStrong.opacity(contrast == .increased ? 0.68 : 0.34)
        default:
            return nil
        }
    }

    private var fillColor: Color? {
        if showsContainerBackground == false && renderingMode == .accented {
            switch resolvedStyle {
            case .flush:
                return nil
            case .softSection:
                return effectiveAccent.opacity(contrast == .increased ? 0.16 : 0.12)
            case .accentWash:
                return effectiveAccent.opacity(contrast == .increased ? 0.20 : 0.16)
            case .contained:
                return effectiveAccent.opacity(contrast == .increased ? 0.24 : 0.18)
            default:
                return nil
            }
        }

        switch resolvedStyle {
        case .flush:
            return nil
        case .softSection:
            return WidgetBrand.canvasSecondary.opacity(showsContainerBackground ? 0.78 : 0.94)
        case .accentWash:
            return effectiveAccent.opacity(contrast == .increased ? 0.12 : 0.09)
        case .contained:
            return showsContainerBackground ? WidgetBrand.canvasElevated : WidgetBrand.canvasSecondary
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(padding)
        .background {
            if let fillColor {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(fillColor)
            }
        }
        .overlay {
            if let strokeColor {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: contrast == .increased ? 1.2 : 1)
            }
        }
    }
}

struct TaskWidgetSectionHeader: View {
    @Environment(\.widgetFamily) private var family

    let eyebrow: String?
    let title: String
    let detail: String?
    var accent: Color = WidgetBrand.textPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(TaskWidgetTypography.eyebrow)
                        .foregroundStyle(WidgetBrand.textSecondary)
                }
                Text(title)
                    .font(TaskWidgetTypography.title)
                    .foregroundStyle(accent)
                    .lineLimit(family == .systemSmall ? 2 : 1)
            }
            Spacer(minLength: 6)
            if let detail {
                Text(detail)
                    .font(TaskWidgetTypography.meta)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TaskWidgetHeroMetric: View {
    let eyebrow: String
    let value: String
    var numericValue: Double? = nil
    let supporting: String
    var accent: Color = WidgetBrand.actionPrimary
    var alignment: HorizontalAlignment = .leading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(TaskWidgetTypography.eyebrow)
                .foregroundStyle(WidgetBrand.textSecondary)

            metricText
                .foregroundStyle(numericValue == nil ? WidgetBrand.textPrimary : accent)

            Text(supporting)
                .font(TaskWidgetTypography.support)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([eyebrow, value, supporting].joined(separator: ". "))
    }

    @ViewBuilder
    private var metricText: some View {
        let text = Text(value)
            .font(TaskWidgetTypography.display)
            .taskWidgetNumericTransition(numericValue, reduceMotion: reduceMotion)
            .taskWidgetAccentable(if: numericValue != nil)

        if reduceMotion {
            text
        } else {
            text.animation(LifeBoardAnimation.heroReveal, value: value)
        }
    }
}

struct TaskWidgetSummaryPill: View {
    let title: String
    let value: String
    var numericValue: Double? = nil
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(TaskWidgetTypography.eyebrow)
                .foregroundStyle(WidgetBrand.textSecondary)
            Text(value)
                .font(TaskWidgetTypography.metric)
                .foregroundStyle(tint)
                .taskWidgetNumericTransition(numericValue, reduceMotion: reduceMotion)
                .taskWidgetAccentable(if: numericValue != nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value)")
    }
}

struct TaskWidgetStatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

struct TaskWidgetStatStrip: View {
    let items: [TaskWidgetStatItem]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.uppercased())
                        .font(TaskWidgetTypography.eyebrow)
                        .foregroundStyle(WidgetBrand.textSecondary)
                    Text(item.value)
                        .font(TaskWidgetTypography.bodyStrong)
                        .foregroundStyle(item.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TaskWidgetInlineMetadata: View {
    let items: [String]

    private var filteredItems: [String] {
        items.filter { $0.isEmpty == false }
    }

    var body: some View {
        if filteredItems.isEmpty == false {
            Text(filteredItems.joined(separator: " • "))
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(1)
        }
    }
}

struct TaskWidgetEditorialDivider: View {
    var body: some View {
        Capsule()
            .fill(WidgetBrand.line.opacity(0.5))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct TaskWidgetActionBandLabel: View {
    let title: String
    var accent: Color = WidgetBrand.actionPrimary

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(title)
                .font(TaskWidgetTypography.bodyStrong)
                .foregroundStyle(WidgetBrand.textInverse)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 14)
        .background(accent, in: RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous))
    }
}

struct TaskWidgetTaskLine: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var trailingTint: Color = WidgetBrand.textSecondary
    var destination: URL? = nil
    var emphasize: Bool = false
    var titleLineLimit: Int? = nil
    var accessibilitySummary: String? = nil

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let destination {
                Link(destination: destination) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummaryText)
    }

    private var resolvedTitleLineLimit: Int {
        if let titleLineLimit {
            return titleLineLimit
        }

        switch family {
        case .systemSmall, .accessoryRectangular:
            return 2
        default:
            return emphasize ? 2 : 1
        }
    }

    private var label: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(emphasize ? TaskWidgetTypography.bodyStrong : TaskWidgetTypography.body)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(resolvedTitleLineLimit)
                if let subtitle {
                    Text(subtitle)
                        .font(TaskWidgetTypography.caption)
                        .foregroundStyle(WidgetBrand.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(TaskWidgetTypography.captionStrong)
                    .foregroundStyle(trailingTint)
                    .lineLimit(1)
            }
        }
    }

    private var accessibilitySummaryText: String {
        if let accessibilitySummary {
            return accessibilitySummary
        }

        return [title, subtitle, trailing]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
    }
}

struct TaskWidgetTaskList: View {
    let tasks: [TaskListWidgetTask]
    var limit: Int
    var subtitle: (TaskListWidgetTask) -> String?
    var trailing: (TaskListWidgetTask) -> String?
    var trailingTint: (TaskListWidgetTask) -> Color

    init(
        tasks: [TaskListWidgetTask],
        limit: Int,
        subtitle: @escaping (TaskListWidgetTask) -> String? = { _ in nil },
        trailing: @escaping (TaskListWidgetTask) -> String? = { _ in nil },
        trailingTint: @escaping (TaskListWidgetTask) -> Color = { _ in Color(uiColor: .secondaryLabel) }
    ) {
        self.tasks = tasks
        self.limit = limit
        self.subtitle = subtitle
        self.trailing = trailing
        self.trailingTint = trailingTint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(tasks.prefix(limit))) { task in
                TaskWidgetTaskLine(
                    title: task.title,
                    subtitle: subtitle(task),
                    trailing: trailing(task),
                    trailingTint: trailingTint(task),
                    destination: TaskWidgetRoutes.task(task.id),
                    accessibilitySummary: [task.title, subtitle(task), trailing(task)]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: ", ")
                )
            }
        }
    }
}

struct TaskWidgetEmptyState: View {
    let title: String
    var symbol: String
    var accent: Color = WidgetBrand.textSecondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .widgetAccentedRenderingMode(.accented)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text(title)
                .font(TaskWidgetTypography.support)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

struct TaskWidgetProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = max(8, geometry.size.width * max(0, min(progress, 1)))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetBrand.line.opacity(0.42))
                Capsule()
                    .fill(tint)
                    .frame(width: width)
                    .widgetAccentable()
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

struct TaskWidgetRing: View {
    let progress: CGFloat
    let lineWidth: CGFloat
    let accent: Color
    let track: Color
    let centerText: String
    var numericValue: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
                .accessibilityHidden(true)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(centerText)
                .font(TaskWidgetTypography.metric)
                .foregroundStyle(WidgetBrand.textPrimary)
                .taskWidgetNumericTransition(numericValue, reduceMotion: reduceMotion)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(centerText)
    }
}

struct TaskWidgetColumn: View {
    let title: String
    let accent: Color
    let tasks: [TaskListWidgetTask]
    let fallback: String

    var body: some View {
        TaskWidgetPanel(accent: accent, style: .quiet, padding: 10) {
            Text(title.uppercased())
                .font(TaskWidgetTypography.eyebrow)
                .foregroundStyle(accent)

            if tasks.isEmpty {
                TaskWidgetEmptyState(title: fallback, symbol: "circle.dashed", accent: WidgetBrand.textSecondary)
            } else {
                TaskWidgetTaskList(
                    tasks: tasks,
                    limit: 3,
                    subtitle: { $0.shortDueLabel },
                    trailing: { $0.priorityCode },
                    trailingTint: { WidgetBrand.priority($0.priorityCode) }
                )
            }
        }
    }
}

struct TaskWidgetTwoZone<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let spacing: CGFloat
    var leadingWeight: CGFloat = 0.6
    var trailingWeight: CGFloat = 0.4
    var stackedSpacing: CGFloat? = nil
    var compactWidthThreshold: CGFloat = 310
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = max(0, proxy.size.width - spacing)
            let combined = max(0.01, leadingWeight + trailingWeight)
            let leadWidth = totalWidth * (leadingWeight / combined)
            let trailingWidth = max(0, totalWidth - leadWidth)
            let shouldStack = dynamicTypeSize.isAccessibilitySize || proxy.size.width < compactWidthThreshold

            Group {
                if shouldStack {
                    VStack(alignment: .leading, spacing: stackedSpacing ?? spacing) {
                        leading()
                        trailing()
                    }
                } else {
                    HStack(alignment: .top, spacing: spacing) {
                        leading()
                            .frame(width: leadWidth, alignment: .topLeading)
                        trailing()
                            .frame(width: trailingWidth, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

extension View {
    @ViewBuilder
    func taskWidgetAccentable(if enabled: Bool) -> some View {
        if enabled {
            self.widgetAccentable()
        } else {
            self
        }
    }

    @ViewBuilder
    func taskWidgetNumericTransition(_ value: Double?, reduceMotion: Bool) -> some View {
        if let value {
            self
                .contentTransition(reduceMotion ? .identity : .numericText(value: value))
                .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: value)
        } else {
            self
        }
    }
}
