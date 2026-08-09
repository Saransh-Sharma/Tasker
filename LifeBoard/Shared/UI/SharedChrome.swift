import SwiftUI
import UIKit

// Four small pieces of chrome no single feature owns: a notch probe, a pill
// background, a cover-flip transition, and a segmented control.
//
// Merged because the anti-shrapnel floor is a real rule, not an accounting one —
// each was 17-44 lines in its own file, which is four files to open to
// understand one row of chrome.

// MARK: - Device+Notch
// Device+Notch.swift
// Provides a shared UIDevice extension for notch detection


extension UIDevice {
    /// `true` on iPhone X-style (notched) devices
    var hasNotch: Bool {
        guard #available(iOS 11.0, *) else { return false }
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = windowScene?.windows.first(where: \.isKeyWindow) ?? windowScene?.windows.first
        let topInset = window?.safeAreaInsets.top ?? 0
        return topInset > 20
    }
}

// MARK: - ColoredPillBackgroundView
/// A tiny enum to pick one of two nav-bar background colors.
enum ColoredPillBackgroundStyle {
    /// neutral “surface” background
    case neutralNavBar
    /// brand-themed background
    case brandNavBar
}

/// A wrapper view that picks a backgroundColor based on the style.
final class ColoredPillBackgroundView: UIView {
    /// Initializes a new instance.
    init(style: ColoredPillBackgroundStyle) {
        super.init(frame: .zero)
        let colors = ThemeStore.shared.currentTheme.tokens.color
        switch style {
        case .neutralNavBar:
            backgroundColor = colors.surfaceSecondary
        case .brandNavBar:
            backgroundColor = colors.actionPrimary
        }
    }
    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - CoverFlipTransition
@preconcurrency import SwiftUI

/// Reusable cover-style 3D flip for swapping two surfaces.
struct CoverFlipTransition: @preconcurrency AnimatableModifier {
    var progress: Double
    var isInsertion: Bool
    var blurStrength: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angle = isInsertion ? (180 - 180 * progress) : (0 - 180 * progress)
        let normalized = min(abs(angle) / 90, 1)
        let blur = CGFloat(normalized) * blurStrength

        return content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .blur(radius: blur)
            .opacity(abs(angle) > 90 ? 0 : 1)
    }
}

extension AnyTransition {
    static func coverFlip(blurStrength: CGFloat = 3.5) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CoverFlipTransition(progress: 0, isInsertion: true, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 1, isInsertion: true, blurStrength: blurStrength)
            ),
            removal: .modifier(
                active: CoverFlipTransition(progress: 1, isInsertion: false, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 0, isInsertion: false, blurStrength: blurStrength)
            )
        )
    }
}

// MARK: - SegmentedControl
struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let accessibilityIdentifier: (Option) -> String
    let action: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    action(option)
                } label: {
                    Text(title(option))
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(selection == option ? ClayColorTokens.violetDeep : ClayColorTokens.navyMuted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(ClayColorTokens.glassStrong)
                                    .shadow(color: ClayColorTokens.elevationShadow, radius: 12, x: 0, y: 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityValue(selection == option ? "selected" : "not selected")
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier(accessibilityIdentifier(option))
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(ClayColorTokens.glass.opacity(0.66))
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
                .overlay(Capsule().stroke(ClayColorTokens.hairline.opacity(0.42), lineWidth: 1))
        }
    }
}
