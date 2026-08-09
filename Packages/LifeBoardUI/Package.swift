// swift-tools-version: 6.0
import PackageDescription

// The shared visual layer: the primitives every feature draws with, and nothing
// that knows what a feature is.
//
// Admission is eligibility-based, not directory-based. Moving all of
// `DesignSystem/` here would drag Home's card models and Track's composer
// receipt down into the UI package and create a cycle back to the app. A file
// belongs here only if it accepts framework types, token types and primitives —
// no feature model, no feature state — and looks up no `Bundle.main` asset.
//
// Deliberately excluded, with the type that disqualifies each:
//   LifeBoardHomeCardBodies   → HomeCardArchetype, HomeCardSnapshot, HomeQueueItem
//   LifeBoardCardPrimitives   → HomeCardSnapshot, HomeDayState, HomeMetricValue
//   ComposerScaffold → TrackComposerReceipt
//   LiquidLevel      → AppRoute (the app router; features never import it)
//   UIKit+TokenAdapters       → TaskPriorityConfig
let package = Package(
    name: "LifeBoardUI",
    // Spelled as a version string rather than `.v26`, which requires
    // PackageDescription 6.2 and would pin the manifest to a newer toolchain
    // than the rest of the project declares.
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "LifeBoardUI", targets: ["LifeBoardUI"])
    ],
    dependencies: [
        .package(path: "../LifeBoardTokens"),
        .package(path: "../LifeBoardContracts")
    ],
    targets: [
        .target(
            name: "LifeBoardUI",
            dependencies: ["LifeBoardTokens", "LifeBoardContracts"]
        )
    ]
)
