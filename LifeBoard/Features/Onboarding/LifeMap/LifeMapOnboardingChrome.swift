import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Shared chrome for the first-run flow.
///
/// Every one of these is a `struct … : View` with stored properties rather than
/// a computed `some View` on the root. That is not a style preference:
/// `check_file_size_guardrails.rb` counts `extension Foo { }` as its own
/// top-level span, so moving step bodies into extensions would satisfy the
/// line-count gate while leaving the real problem — Debug inlining every
/// computed `some View` into the root's stack frame — completely untouched.

// MARK: - Question scaffold

/// One question, one support line, one content block.
///
/// `DESIGN.md` layout budget: "one hero decision or active state … one visually
/// dominant primary action". The scaffold exists so no step can quietly grow a
/// second heading level.
struct LifeMapQuestionScaffold<Content: View>: View {
    let title: String
    let support: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text(support)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

// MARK: - Choice row

/// The single selection affordance for desired change, friction, and modules.
///
/// Raised clay, per `DESIGN.md`: "Clay is the material of content and glass is
/// the material of decision and control." A selection row is content the user
/// is picking among, not the screen's one decision surface — the dock is.
struct LifeMapChoiceRow: View {
    let title: String
    var subtitle: String?
    let symbol: String
    let isSelected: Bool
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm + 1) {
                Image(systemName: symbol)
                    .lifeboardFont(.title3)
                    .foregroundStyle(Color.lifeboard(isSelected ? .accentPrimary : .textSecondary))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.symbolEffect(.replace))
                    .lifeboardFont(.title3)
                    .foregroundStyle(Color.lifeboard(isSelected ? .accentPrimary : .textQuaternary))
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(
                isSelected ? .raised : .resting,
                                fill: isSelected ? Color.lifeboard(.accentWash) : nil
            )
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isDisabled ? Text("Deselect another choice first") : Text(""))
    }
}

// MARK: - Bottom dock

/// Floating chrome, not the hero.
///
/// `DESIGN.md` plane 5 allots Regular Liquid Glass to "navigation, capture, lens
/// rails, compact menus, and approved toolbar controls". The dock is one of
/// those, so it takes glass *without* claiming the screen's single hero slot —
/// which stays free for the actual dominant object on each step.
struct LifeMapBottomDock: View {
    let primaryTitle: String
    let secondaryTitle: String?
    let isPrimaryDisabled: Bool
    let clayTrigger: Int
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    var primaryAccessibilityID = LifeMapAccessibilityID.primaryAction
    var secondaryAccessibilityID = LifeMapAccessibilityID.secondaryAction

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let secondaryTitle {
                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(LifeMapSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(secondaryAccessibilityID)
            }
            Button(primaryTitle, action: onPrimary)
                .buttonStyle(LifeMapPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isPrimaryDisabled)
                .accessibilityIdentifier(primaryAccessibilityID)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .lifeBoardSystemGlass(.regular, in: Capsule(style: .continuous), interactive: true)
        .lifeboardClayPressBloom(trigger: clayTrigger, tint: Color.lifeboard(.accentPrimary))
    }
}

// MARK: - Button styles

struct LifeMapPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .lifeBoardMotion(.press, value: configuration.isPressed)
    }
}

/// Onboarding's primary action, which is the app's primary action.
///
/// This drew a flat `Capsule` fill — the same defect the canonical
/// `PrimaryActionStyle` had: the most important control on the screen was the
/// flattest object on it, in a system whose premise is tactile material. It was
/// also 52pt tall against the contract's 48 and faded to `.opacity(0.45)` when
/// disabled, which drags the label under the contrast floor.
///
/// It delegates now, so onboarding's CTA and the rest of the app's are the same
/// object rather than two things that happen to look similar.
struct LifeMapPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryActionStyle().makeBody(configuration: configuration)
    }
}

struct LifeMapSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeboardFont(.button)
            .foregroundStyle(Color.lifeboard(.textPrimary))
            // Was 52pt tall at `cornerRadius: 26` — a radius the shape
            // vocabulary does not contain, on a control that is visibly a
            // capsule.
            .frame(minHeight: 48)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .lifeBoardClaySurface(.resting, cornerRadius: Radius.pill, isPressed: configuration.isPressed)
            .lifeBoardMotion(.press, value: configuration.isPressed)
    }
}
