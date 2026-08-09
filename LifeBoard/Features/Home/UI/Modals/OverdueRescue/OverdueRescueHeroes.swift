import SwiftUI
import UIKit

// The illustrations the sheet shows, and the palette they are drawn from.

// MARK: - OverdueRescueCupHero

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueCupHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_cup")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 62, height: 62)
                .opacity(0.8)
                .offset(x: -84, y: -78)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .opacity(0.6)
                .offset(x: 86, y: -46)
        }
    }
}

// MARK: - OverdueRescuePlant

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescuePlant: View {
    var body: some View {
        Image(decorative: "rescue_decor_plant")
            .resizable()
            .scaledToFit()
    }
}

// MARK: - OverdueRescueShieldHero

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueShieldHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_shield")
                .resizable()
                .scaledToFit()
            OverdueRescuePlant()
                .frame(width: 88, height: 108)
                .offset(x: 98, y: 36)
        }
    }
}

// MARK: - OverdueRescueSunriseHero

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSunriseHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_sunrise")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .opacity(0.7)
                .offset(x: -104, y: -62)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .opacity(0.5)
                .offset(x: 106, y: -44)
            OverdueRescuePlant()
                .frame(width: 92, height: 110)
                .offset(x: 98, y: 20)
        }
    }
}

// MARK: - OverdueRescuePalette

//
//  OverdueRescuePalette.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


/// Semantic palette for the Overdue Rescue deck.
///
/// This was previously 62 raw red/green/blue colour literals describing an
/// entire parallel palette — legacy navy ink, assistant violet as a generic
/// accent, and system blue for the edit action. It was the single largest
/// token violation in the tree and the one surface guaranteed to desync
/// visually the moment the warm paper system became the default.
///
/// Every role now resolves from the canonical tokens, so the deck follows
/// appearance, Increase Contrast and any future palette change for free.
enum OverdueRescuePalette {
    static let ink = Color(LifeBoardColorTokens.inkPrimary)
    static let secondaryInk = Color(LifeBoardColorTokens.inkSecondary)

    static let backgroundTop = Color(LifeBoardColorTokens.foundationCanvas)
    static let backgroundMid = Color(LifeBoardColorTokens.foundationCanvasSoft)
    static let backgroundBottom = Color(LifeBoardColorTokens.foundationCanvasMuted)

    static let glassFill = Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.78)
    static let glassStroke = Color(LifeBoardColorTokens.foundationHairline).opacity(0.62)

    /// Front task-card surface, on the canonical raised paper.
    static let cardSurfaceTop = Color(LifeBoardColorTokens.foundationSurfaceSolid)
    static let cardSurfaceBottom = Color(LifeBoardColorTokens.foundationCanvasSoft)
    static let cardStroke = Color(LifeBoardColorTokens.foundationHairline)

    /// Body copy inside the inner "needs a decision" box.
    static let innerBody = Color(LifeBoardColorTokens.inkSecondary)
    static let softShadow = Color(LifeBoardColorTokens.foundationWarmShadow)
    static let progressTrack = Color(LifeBoardColorTokens.metricRingTrack)

    /// The deck's primary action stays in the warm system. Assistant violet is
    /// reserved for Eva context and must not become a generic accent, and this
    /// is task triage rather than an assistant surface.
    static let accentPrimary = Color.lifeboard(.actionPrimary)
    static let accentSoftFill = Color(LifeBoardColorTokens.foundationSurfaceSelected).opacity(0.82)
    static let accentSoftStroke = Color.lifeboard(.actionPrimary).opacity(0.26)
    static let accentGradient = LinearGradient(
        colors: [
            Color.lifeboard(.actionPrimary),
            Color.lifeboard(.actionPrimaryPressed)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Decision affordances. Each pairs a semantic status colour with a wash of
    // itself, so the four choices stay distinguishable by hue *and* by their
    // icon and label rather than by colour alone.
    static let keepFill = Color.lifeboard(.statusSuccess).opacity(0.14)
    static let keepForeground = Color.lifeboard(.statusSuccess)

    static let moveFill = Color.lifeboard(.statusWarning).opacity(0.14)
    static let moveForeground = Color.lifeboard(.statusWarning)

    /// Edit was system blue, the one colour the redesign explicitly removes.
    /// It becomes a neutral ink action — editing is not a status.
    static let editFill = Color(LifeBoardColorTokens.foundationSurfaceRecessed)
    static let editForeground = Color(LifeBoardColorTokens.inkPrimary)

    static let deleteFill = Color.lifeboard(.statusDanger).opacity(0.14)
    static let deleteForeground = Color.lifeboard(.statusDanger)

    /// Deck-stack back cards, drawn from the daypart layer roles so the stack
    /// reads as layered paper in whichever atmosphere is current.
    static func backCard(_ index: Int) -> Color {
        switch index {
        case 0: return Color(LifeBoardColorTokens.foundationCanvasSoft)
        case 1: return Color(LifeBoardColorTokens.foundationSurfaceRecessed)
        case 2: return Color(LifeBoardColorTokens.foundationCanvasMuted)
        default: return Color(LifeBoardColorTokens.foundationSurfaceSelected)
        }
    }
}

// MARK: - OverdueRescueVisualSpec

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueVisualSpec {
    static let screenHorizontalPadding: CGFloat = 28
    static let topButtonSize: CGFloat = 58
    static let cardCorner: CGFloat = 34
    static let innerCardCorner: CGFloat = 22
    static let largeCardCorner: CGFloat = 28
    static let primaryButtonHeight: CGFloat = 68
    static let secondaryButtonHeight: CGFloat = 62
    static let primaryButtonCorner: CGFloat = 24
    static let sheetMaxWidth: CGFloat = 390

    static func primaryButtonBackground(cornerRadius: CGFloat = primaryButtonCorner) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(OverdueRescuePalette.accentGradient)
            .shadow(color: Color(red: 0.27, green: 0.18, blue: 0.93).opacity(0.22), radius: 18, y: 10)
    }

    static func glassCard(cornerRadius: CGFloat = largeCardCorner, fill: Color = OverdueRescuePalette.glassFill) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
            )
            .shadow(color: OverdueRescuePalette.softShadow, radius: 24, y: 12)
    }
}
