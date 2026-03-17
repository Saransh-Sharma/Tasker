import SwiftUI
import UIKit

enum TaskerCTABezelStyle {
    case primaryWide
    case fab
    case pill
    case summaryPrimary

    var baseLineWidth: CGFloat {
        switch self {
        case .primaryWide:
            return 3.2
        case .fab:
            return 3.0
        case .pill:
            return 2.5
        case .summaryPrimary:
            return 2.9
        }
    }

    var bezelOutset: CGFloat {
        switch self {
        case .primaryWide:
            return 3.0
        case .fab:
            return 2.5
        case .pill:
            return 2.75
        case .summaryPrimary:
            return 2.6
        }
    }

    var shellLineWidth: CGFloat {
        switch self {
        case .primaryWide:
            return 6.8
        case .fab:
            return 6.1
        case .pill:
            return 5.0
        case .summaryPrimary:
            return 5.8
        }
    }

    var topHighlightHeight: CGFloat {
        switch self {
        case .primaryWide:
            return 16
        case .fab:
            return 18
        case .pill:
            return 12
        case .summaryPrimary:
            return 14
        }
    }

    var supportsReadyPulse: Bool {
        switch self {
        case .fab:
            return false
        case .primaryWide, .pill, .summaryPrimary:
            return true
        }
    }
}

enum TaskerCTABezelPalette {
    case titanium
    case roseGold
    case copper

    var staticGradientColors: [Color] {
        switch self {
        case .titanium:
            return [
                Color.white.opacity(0.98),
                Color(red: 0.90, green: 0.92, blue: 0.97),
                Color(red: 0.62, green: 0.67, blue: 0.74),
                Color(red: 0.93, green: 0.95, blue: 0.99),
                Color.white.opacity(0.98)
            ]
        case .roseGold:
            return [
                Color(red: 0.99, green: 0.94, blue: 0.93),
                Color(red: 0.96, green: 0.82, blue: 0.80),
                Color(red: 0.78, green: 0.55, blue: 0.54),
                Color(red: 0.95, green: 0.79, blue: 0.77),
                Color(red: 0.99, green: 0.93, blue: 0.90)
            ]
        case .copper:
            return [
                Color(red: 0.99, green: 0.90, blue: 0.82),
                Color(red: 0.89, green: 0.60, blue: 0.43),
                Color(red: 0.63, green: 0.34, blue: 0.22),
                Color(red: 0.86, green: 0.52, blue: 0.34),
                Color(red: 0.99, green: 0.88, blue: 0.78)
            ]
        }
    }

    var shaderIndex: Float {
        switch self {
        case .titanium:
            return 0
        case .roseGold:
            return 1
        case .copper:
            return 2
        }
    }

    var crispHighlightColor: Color {
        switch self {
        case .titanium:
            return .white
        case .roseGold:
            return Color(red: 0.99, green: 0.92, blue: 0.90)
        case .copper:
            return Color(red: 0.99, green: 0.90, blue: 0.82)
        }
    }
}

enum TaskerCTABezelIdleMotion {
    case staticIdle
    case slowLoop

    var loops: Bool {
        switch self {
        case .staticIdle:
            return false
        case .slowLoop:
            return true
        }
    }

    var timeScale: Double {
        switch self {
        case .staticIdle:
            return 0
        case .slowLoop:
            return 0.042
        }
    }
}

enum TaskerCTABezelBehavior: Equatable {
    case inactive
    case idle
    case introSweep
    case readyPulse
    case pressed
    case disabled

    var usesTimeline: Bool {
        switch self {
        case .idle, .introSweep, .readyPulse:
            return true
        case .inactive, .pressed, .disabled:
            return false
        }
    }
}

enum TaskerCTABezelResolver {
    static func highlightedOnboardingTemplateID(
        primarySuggestionIDs: [String],
        taskTemplateStates: [String: OnboardingTaskTemplateState]
    ) -> String? {
        for templateID in primarySuggestionIDs {
            switch taskTemplateStates[templateID] ?? .idle {
            case .created:
                continue
            case .idle, .creating, .failed:
                return templateID
            }
        }
        return nil
    }

    static func dailySummaryPrimaryCTAIdentifier(for summary: DailySummaryModalData) -> String {
        switch summary {
        case .morning:
            return "home.dailySummary.cta.startToday"
        case .nightly:
            return "home.dailySummary.cta.planTomorrow"
        }
    }
}

private struct TaskerCTABezelShape: Shape {
    let style: TaskerCTABezelStyle

    func path(in rect: CGRect) -> Path {
        switch style {
        case .primaryWide:
            let radius = min(24, max(18, rect.height * 0.38))
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        case .fab, .pill, .summaryPrimary:
            return Capsule(style: .continuous).path(in: rect)
        }
    }
}

private struct TaskerCTABezelModifier: ViewModifier {
    let style: TaskerCTABezelStyle
    let palette: TaskerCTABezelPalette
    let idleMotion: TaskerCTABezelIdleMotion
    let isEnabled: Bool
    let isBusy: Bool
    let isPrimarySuggestion: Bool
    let isPressed: Bool
    let showsWhenDisabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var animationBehavior: TaskerCTABezelBehavior?
    @State private var animationStartDate = Date.distantPast
    @State private var idleLoopStartDate = Date()
    @State private var hasAppeared = false

    private var isFlagEnabled: Bool {
        V2FeatureFlags.liquidMetalCTAEnabled
    }

    private var isEligibleForBezel: Bool {
        switch style {
        case .pill:
            return isPrimarySuggestion
        case .primaryWide, .fab, .summaryPrimary:
            return true
        }
    }

    private var currentBehavior: TaskerCTABezelBehavior {
        guard isFlagEnabled, isEligibleForBezel else { return .inactive }
        guard isEnabled else { return showsWhenDisabled ? .disabled : .inactive }
        if isBusy {
            return .disabled
        }
        if isPressed {
            return .pressed
        }

        guard let animationBehavior else {
            return .idle
        }

        let elapsed = Date().timeIntervalSince(animationStartDate)
        if elapsed < duration(for: animationBehavior) {
            return animationBehavior
        }
        return .idle
    }

    func body(content: Content) -> some View {
        let behavior = currentBehavior

        content
            .overlay {
                if isFlagEnabled, isEligibleForBezel, showsWhenDisabled || behavior != .inactive {
                    TaskerCTABezelOverlay(
                        style: style,
                        palette: palette,
                        idleMotion: idleMotion,
                        behavior: behavior,
                        animationStartDate: animationStartDate,
                        idleLoopStartDate: idleLoopStartDate,
                        highContrast: colorSchemeContrast == .increased,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .onAppear {
                guard hasAppeared == false else { return }
                hasAppeared = true
                resetIdleLoopAnchor()
                guard isEligibleForBezel, isEnabled, isBusy == false else { return }
                fire(.introSweep)
            }
            .onChange(of: isEnabled) { oldValue, newValue in
                guard isEligibleForBezel, oldValue == false, newValue, isBusy == false, style.supportsReadyPulse else { return }
                resetIdleLoopAnchor()
                fire(.readyPulse)
            }
            .onChange(of: isPrimarySuggestion) { oldValue, newValue in
                guard oldValue == false, newValue, isEligibleForBezel, isEnabled, isBusy == false, style.supportsReadyPulse else { return }
                resetIdleLoopAnchor()
                fire(.readyPulse)
            }
            .onChange(of: isBusy) { oldValue, newValue in
                guard oldValue, newValue == false, isEligibleForBezel, isEnabled, style.supportsReadyPulse else { return }
                resetIdleLoopAnchor()
                fire(.readyPulse)
            }
    }

    private func fire(_ behavior: TaskerCTABezelBehavior) {
        animationBehavior = behavior
        animationStartDate = Date()
    }

    private func resetIdleLoopAnchor() {
        idleLoopStartDate = Date()
    }

    private func duration(for behavior: TaskerCTABezelBehavior) -> TimeInterval {
        switch behavior {
        case .introSweep:
            return 1.35
        case .readyPulse:
            return 1.05
        case .inactive, .idle, .pressed, .disabled:
            return 0
        }
    }
}

private struct TaskerCTABezelOverlay: View {
    let style: TaskerCTABezelStyle
    let palette: TaskerCTABezelPalette
    let idleMotion: TaskerCTABezelIdleMotion
    let behavior: TaskerCTABezelBehavior
    let animationStartDate: Date
    let idleLoopStartDate: Date
    let highContrast: Bool
    let reduceMotion: Bool

    private var reduceTransparency: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }

    private var timelineAnimationEnabled: Bool {
        guard reduceMotion == false else { return false }
        switch behavior {
        case .introSweep, .readyPulse:
            return true
        case .idle:
            return idleMotion.loops
        case .inactive, .pressed, .disabled:
            return false
        }
    }

    private func lineWidth(for behavior: TaskerCTABezelBehavior) -> CGFloat {
        let base = style.baseLineWidth
        if highContrast {
            return base + 0.9
        }
        if behavior == .pressed {
            return base + 0.45
        }
        return base
    }

    private func shellLineWidth(for behavior: TaskerCTABezelBehavior) -> CGFloat {
        let base = style.shellLineWidth
        if highContrast {
            return base + 0.9
        }
        if behavior == .pressed {
            return base + 0.5
        }
        return base
    }

    private func baseOpacity(for behavior: TaskerCTABezelBehavior) -> Double {
        switch behavior {
        case .disabled:
            return highContrast ? 0.6 : 0.48
        case .inactive:
            return 0.18
        case .idle:
            return highContrast ? 0.94 : 0.82
        case .introSweep:
            return highContrast ? 1.0 : 0.96
        case .readyPulse:
            return highContrast ? 1.0 : 0.98
        case .pressed:
            return 1.0
        }
    }

    private func shellOpacity(for behavior: TaskerCTABezelBehavior) -> Double {
        switch behavior {
        case .disabled:
            return highContrast ? 0.38 : 0.28
        case .inactive:
            return 0.1
        case .idle:
            return highContrast ? 0.72 : 0.54
        case .introSweep:
            return highContrast ? 0.84 : 0.68
        case .readyPulse:
            return highContrast ? 0.9 : 0.74
        case .pressed:
            return highContrast ? 0.96 : 0.82
        }
    }

    private func glowOpacity(for behavior: TaskerCTABezelBehavior) -> Double {
        switch behavior {
        case .disabled:
            return 0.05
        case .inactive:
            return 0.02
        case .idle:
            return 0.16
        case .introSweep:
            return 0.22
        case .readyPulse:
            return 0.28
        case .pressed:
            return 0.3
        }
    }

    private func topHighlightOpacity(for behavior: TaskerCTABezelBehavior) -> Double {
        if highContrast {
            return 0.7
        }

        switch behavior {
        case .disabled:
            return 0.18
        case .inactive:
            return 0.12
        case .idle:
            return 0.42
        case .introSweep, .readyPulse:
            return 0.52
        case .pressed:
            return 0.56
        }
    }

    private func innerCrispOpacity(for behavior: TaskerCTABezelBehavior) -> Double {
        switch behavior {
        case .disabled:
            return highContrast ? 0.34 : 0.26
        case .inactive:
            return 0.1
        case .idle:
            return highContrast ? 0.72 : 0.52
        case .introSweep:
            return highContrast ? 0.86 : 0.68
        case .readyPulse:
            return highContrast ? 0.9 : 0.74
        case .pressed:
            return highContrast ? 0.94 : 0.82
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if reduceMotion == false, behavior == .idle, idleMotion.loops {
                TimelineView(.periodic(from: idleLoopStartDate, by: 1.0 / 30.0)) { context in
                    render(
                        behavior: behavior,
                        shaderTime: shaderTime(at: context.date),
                        size: proxy.size
                    )
                }
            } else if timelineAnimationEnabled {
                TimelineView(.animation) { context in
                    render(
                        behavior: resolvedBehavior(at: context.date),
                        shaderTime: shaderTime(at: context.date),
                        size: proxy.size
                    )
                }
            } else {
                render(
                    behavior: behavior,
                    shaderTime: staticShaderTime(for: behavior),
                    size: proxy.size
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func render(behavior: TaskerCTABezelBehavior, shaderTime: Float, size: CGSize) -> some View {
        ZStack {
            outerGlow(behavior: behavior)
                .opacity(glowOpacity(for: behavior))

            ringLayer(shaderTime: shaderTime, behavior: behavior, size: size)

            topHighlight(behavior: behavior)
                .opacity(topHighlightOpacity(for: behavior))
        }
        .frame(width: size.width, height: size.height)
    }

    private func shaderTime(at date: Date) -> Float {
        switch behavior {
        case .introSweep, .readyPulse:
            return Float(max(0, min(animationDuration, date.timeIntervalSince(animationStartDate))))
        case .idle:
            return Float(max(0, date.timeIntervalSince(idleLoopStartDate)) * idleMotion.timeScale)
        case .pressed:
            return 0.48
        case .disabled:
            return 0.18
        case .inactive:
            return 0.08
        }
    }

    private func staticShaderTime(for behavior: TaskerCTABezelBehavior) -> Float {
        switch behavior {
        case .pressed:
            return 0.48
        case .disabled:
            return 0.18
        case .inactive:
            return 0.08
        case .idle:
            return 0.22
        case .introSweep, .readyPulse:
            return 0.34
        }
    }

    private var animationDuration: TimeInterval {
        switch behavior {
        case .introSweep:
            return 1.35
        case .readyPulse:
            return 1.05
        case .inactive, .idle, .pressed, .disabled:
            return 0
        }
    }

    private func resolvedBehavior(at date: Date) -> TaskerCTABezelBehavior {
        switch behavior {
        case .introSweep, .readyPulse:
            return date.timeIntervalSince(animationStartDate) >= animationDuration ? .idle : behavior
        case .inactive, .idle, .pressed, .disabled:
            return behavior
        }
    }

    @ViewBuilder
    private func ringLayer(shaderTime: Float, behavior: TaskerCTABezelBehavior, size: CGSize) -> some View {
        let ringShape = TaskerCTABezelShape(style: style)
        let shellStroke = ringShape
            .stroke(
                LinearGradient(
                    colors: palette.staticGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(
                    lineWidth: shellLineWidth(for: behavior),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .padding(-style.bezelOutset)
            .opacity(shellOpacity(for: behavior))

        let shaderStroke = ringShape
            .stroke(.white, lineWidth: lineWidth(for: behavior))
            .padding(-style.bezelOutset)
            .opacity(baseOpacity(for: behavior))

        ZStack {
            shellStroke

            if reduceTransparency == false {
                let shader = Shader(
                    function: ShaderFunction(library: .default, name: "TaskerLiquidMetalBezel"),
                    arguments: [
                        .float2(
                            Float(max(size.width + (style.bezelOutset * 2), 1)),
                            Float(max(size.height + (style.bezelOutset * 2), 1))
                        ),
                        .float(shaderTime),
                        .float(Float(baseOpacity(for: behavior))),
                        .float(highContrast ? 0.01 : 0.026),
                        .float(behavior == .pressed ? 0.82 : 0.7),
                        .float(palette.shaderIndex),
                        .float(
                            behavior == .idle ? 0.18 :
                                behavior == .pressed ? 0.22 :
                                behavior == .disabled ? 0.1 : 0.2
                        )
                    ]
                )

                shaderStroke
                    .colorEffect(shader)
                    .overlay {
                        if #available(iOS 26.0, *) {
                            ringShape
                                .fill(.clear)
                                .padding(-style.bezelOutset)
                                .glassEffect(.regular, in: ringShape)
                                .mask(
                                    ringShape
                                        .stroke(
                                            .white,
                                            lineWidth: lineWidth(for: behavior) + 1.3
                                        )
                                        .padding(-style.bezelOutset)
                                )
                                .opacity(highContrast ? 0.18 : 0.24)
                        }
                    }
            } else {
                shaderStroke
                    .foregroundStyle(
                        LinearGradient(
                            colors: palette.staticGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            ringShape
                .stroke(
                    palette.crispHighlightColor.opacity(innerCrispOpacity(for: behavior)),
                    lineWidth: max(1.1, lineWidth(for: behavior) * 0.36)
                )
                .padding(-style.bezelOutset)
        }
    }

    private func outerGlow(behavior: TaskerCTABezelBehavior) -> some View {
        TaskerCTABezelShape(style: style)
            .stroke(Color.white.opacity(highContrast ? 0.34 : 0.18), lineWidth: shellLineWidth(for: behavior) + 2.2)
            .padding(-style.bezelOutset)
            .blur(radius: style == .pill ? 4.5 : 6.0)
    }

    private func topHighlight(behavior: TaskerCTABezelBehavior) -> some View {
        TaskerCTABezelShape(style: style)
            .fill(
                LinearGradient(
                    colors: [
                        palette.crispHighlightColor.opacity(highContrast ? 0.82 : 0.62),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(-style.bezelOutset)
            .mask(alignment: .top) {
                Capsule(style: .continuous)
                    .frame(height: style.topHighlightHeight)
                    .padding(.horizontal, style == .fab ? 10 : 16)
                    .blur(radius: 1.1)
            }
    }
}

extension View {
    @MainActor
    func taskerCTABezel(
        style: TaskerCTABezelStyle,
        palette: TaskerCTABezelPalette = .titanium,
        idleMotion: TaskerCTABezelIdleMotion = .staticIdle,
        isEnabled: Bool = true,
        isBusy: Bool = false,
        isPrimarySuggestion: Bool = false,
        isPressed: Bool = false,
        showsWhenDisabled: Bool = true
    ) -> some View {
        modifier(
            TaskerCTABezelModifier(
                style: style,
                palette: palette,
                idleMotion: idleMotion,
                isEnabled: isEnabled,
                isBusy: isBusy,
                isPrimarySuggestion: isPrimarySuggestion,
                isPressed: isPressed,
                showsWhenDisabled: showsWhenDisabled
            )
        )
    }
}

private struct TaskerNoisyGradientLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.black
                .layerEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "TaskerNoisyGradient"),
                        arguments: [
                            .boundingRect,
                            .float(0)
                        ]
                    ),
                    maxSampleOffset: .zero
                )
        } else {
            TimelineView(.animation) { context in
                let time = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100))
                Color.black
                    .layerEffect(
                        Shader(
                            function: ShaderFunction(library: .default, name: "TaskerNoisyGradient"),
                            arguments: [
                                .boundingRect,
                                .float(time)
                            ]
                        ),
                        maxSampleOffset: .zero
                    )
            }
        }
    }
}

struct TaskerNoisyGradientBackdrop: View {
    let opacity: Double

    init(opacity: Double = 1.0) {
        self.opacity = opacity
    }

    var body: some View {
        TaskerNoisyGradientLayer()
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
