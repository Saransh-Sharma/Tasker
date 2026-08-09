// swift-tools-version: 6.0
import PackageDescription

// The true bottom of the graph: values that cross a process boundary between
// the app, the widgets, the Watch app and the share extension — App Group
// identifiers, the pending-capture envelope, widget snapshots and the Live
// Activity contracts.
//
// Depends on nothing, and must not: anything here is decoded by a process that
// does not link the app.
let package = Package(
    name: "LifeBoardContracts",
    platforms: [.iOS("26.0"), .watchOS("26.0")],
    products: [
        .library(name: "LifeBoardContracts", targets: ["LifeBoardContracts"])
    ],
    targets: [
        .target(name: "LifeBoardContracts")
    ]
)
