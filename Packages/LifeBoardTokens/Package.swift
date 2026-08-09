// swift-tools-version: 6.0
import PackageDescription

// The bottom of the design-system graph: colour, type, spacing, corner,
// elevation, motion and the theme that resolves them.
//
// Extracted first because the build system had already proved the boundary —
// these files were compiled into the LifeBoardWidgets extension, which does not
// link the app, so they were known to be free of app dependencies before the
// package existed.
//
// Depends only on LifeBoardContracts, for the App Group identifier that
// ColorTokens reads to resolve the same palette in the widget and Watch
// processes as in the app. Anything that needs a feature model does not belong
// here.
let package = Package(
    name: "LifeBoardTokens",
    // Spelled as a version string rather than `.v26`, which requires
    // PackageDescription 6.2 and would pin the manifest to a newer toolchain
    // than the rest of the project declares.
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "LifeBoardTokens", targets: ["LifeBoardTokens"])
    ],
    dependencies: [
        .package(path: "../LifeBoardContracts")
    ],
    targets: [
        .target(
            name: "LifeBoardTokens",
            dependencies: ["LifeBoardContracts"]
        )
    ]
)
