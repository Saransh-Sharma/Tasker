import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Welcome and the first question, on one screen.
///
/// There used to be a promise screen with nothing to do on it, then this
/// question on its own screen with a subtitle under every option and an
/// optional "what gets in the way?" question tucked beneath. The greeting now
/// does the welcoming, the title is the question, and each option is a label a
/// person can take in at a glance.
struct LifeWeaveIntentStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @State private var titleLight = 0

    private var greeting: String {
        LifeWeaveCopy.Welcome.greeting(Self.daypartGreeting(at: Date()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greeting)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(LifeWeaveCopy.Welcome.title)
                    .lifeboardFont(.screenTitle)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    // DESIGN.md sanctions first light for onboarding arrival.
                    // One sweep when the screen appears, then nothing.
                    .lifeboardFirstLight(trigger: titleLight, tint: Color.lifeboard(.accentPrimary))
            }

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(LifeWeaveIntent.allCases.enumerated()), id: \.element.id) { index, intent in
                    LifeMapChoiceRow(
                        title: LifeWeaveCopy.Intent.title(intent),
                        symbol: intent.symbol,
                        isSelected: model.draft.intent == intent
                    ) {
                        model.selectIntent(intent)
                    }
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.intent(intent.id))
                    .modifier(LifeWeaveStaggeredEntrance(index: index))
                }
            }

            // One text run rather than an icon beside a label: in an HStack the
            // glyph takes its intrinsic width first and, at accessibility sizes,
            // the half of the sentence that carries the promise was truncated.
            Text("\(Image(systemName: "lock.fill")) \(LifeWeaveCopy.Welcome.privacy)")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { titleLight &+= 1 }
    }

    /// A greeting that matches the sky, without the exclamation mark
    /// `ResolvedDaypart.greeting` carries for Home.
    ///
    /// Night says "Good evening": "Good night" is a goodbye, and this is the
    /// first thing the app ever says.
    static func daypartGreeting(at date: Date, calendar: Calendar = .current) -> String {
        switch DaypartResolver.resolve(at: date, calendar: calendar) {
        case .morning: String(localized: "Good morning")
        case .afternoon: String(localized: "Good afternoon")
        case .evening, .night: String(localized: "Good evening")
        }
    }
}

/// The user's own structure.
///
/// Pick order is the ranking: the first area picked carries a ① and leads.
/// That retired a second question — "which one needs the clearest path
/// first?" — which asked for the same information in words nobody uses.
struct LifeWeaveLifeAreasStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        // Two tiles a row fit all seven on a phone without scrolling. At
        // accessibility sizes a name would wrap letter by letter in half the
        // width, so the grid gives way to one column rather than shrinking type.
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: count)
    }

    private var isAtLimit: Bool {
        model.draft.orderedLifeAreaTemplateIDs.count >= LifeWeaveDraft.maximumLifeAreas
    }

    var body: some View {
        LifeMapQuestionScaffold(
            title: LifeWeaveCopy.Areas.title,
            support: LifeWeaveCopy.Areas.support
        ) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(Array(StarterWorkspaceCatalog.allLifeAreas.enumerated()), id: \.element.id) { index, template in
                    let position = model.draft.orderedLifeAreaTemplateIDs.firstIndex(of: template.id).map { $0 + 1 }
                    LifeWeaveAreaTile(
                        template: template,
                        pickPosition: position,
                        isDisabled: position == nil && isAtLimit
                    ) {
                        model.toggleLifeArea(template)
                    }
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.lifeArea(template.id))
                    .modifier(LifeWeaveStaggeredEntrance(index: index))
                }
            }
        }
    }
}

/// One life area as a tile: its symbol, its name, and — once picked — where it
/// falls in the order.
///
/// Selection is carried by the badge, the rim, and the fill together, never by
/// colour alone, so it survives grayscale and colour-vision differences.
struct LifeWeaveAreaTile: View {
    let template: StarterLifeAreaTemplate
    let pickPosition: Int?
    let isDisabled: Bool
    let action: () -> Void

    private var isSelected: Bool { pickPosition != nil }

    private var accent: Color {
        if let role = LifeAreaAccentRole(lifeAreaTemplateID: template.id) {
            return Color.lifeboardArea(role)
        }
        return Color.lifeboard(.accentPrimary)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: template.icon)
                        .lifeboardFont(.title3)
                        .foregroundStyle(isSelected ? accent : Color.lifeboard(.textSecondary))
                        .symbolEffect(.bounce, value: isSelected)
                        .frame(width: 28, height: 28, alignment: .leading)
                    Spacer(minLength: 0)
                    badge
                }
                Text(template.name)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .lifeBoardClaySurface(
                isSelected ? .raised : .resting,
                cornerRadius: Radius.card,
                fill: isSelected ? Color.lifeboard(.accentWash) : nil
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.lifeboard(.accentPrimary), lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .lifeBoardMotion(.selection, value: pickPosition)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(template.name)
        .accessibilityValue(pickPosition.map(LifeWeaveCopy.Areas.badgeLabel) ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isDisabled ? LifeWeaveCopy.Areas.atLimitHint : "")
    }

    @ViewBuilder
    private var badge: some View {
        if let pickPosition {
            Text("\(pickPosition)")
                .lifeboardFont(.caption1)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(pickPosition)))
                .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                .frame(minWidth: 24, minHeight: 24)
                .background(Color.lifeboard(.accentPrimary), in: Circle())
                .transition(.scale.combined(with: .opacity))
        } else {
            Circle()
                .stroke(Color.lifeboard(.textQuaternary), lineWidth: 1.5)
                .frame(width: 24, height: 24)
        }
    }
}

/// Rows arrive one after another the first time a screen appears, and then
/// never move again.
///
/// Opacity-only under Reduce Motion (after the Full Motion override), and no
/// motion at all under `-UI_TESTING`, via `MotionProfile.animation`.
struct LifeWeaveStaggeredEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var appeared = false

    private var reduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .onAppear {
                let delay = Double(min(index, LifeBoardAnimation.entranceStaggerCap)) * LifeBoardAnimation.staggerInterval
                if let animation = MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion) {
                    withAnimation(animation.delay(delay)) { appeared = true }
                } else {
                    appeared = true
                }
            }
    }
}
