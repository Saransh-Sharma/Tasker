// swift-tools-version: 6.0
import PackageDescription

/// LifeBoard's compiler-enforced module spine.
///
/// All in-repository products live in this manifest so target adjacency has one
/// source of truth. Feature products are added only when their complete source
/// set has crossed the boundary; an empty facade is not considered extraction.
let package = Package(
    name: "LifeBoardModules",
    platforms: [
        .iOS("26.0"),
        .watchOS("26.0")
    ],
    products: [
        .library(name: "LifeBoardContracts", targets: ["LifeBoardContracts"]),
        .library(name: "LifeBoardTokens", targets: ["LifeBoardTokens"]),
        .library(name: "LifeBoardUI", targets: ["LifeBoardUI"]),
        .library(name: "LifeBoardDomain", targets: ["LifeBoardDomain"]),
        .library(name: "LifeBoardPersistence", targets: ["LifeBoardPersistence"]),
        .library(name: "LifeBoardCalendar", targets: ["LifeBoardCalendar"]),
        .library(name: "LifeBoardTranscription", targets: ["LifeBoardTranscription"])
    ],
    targets: [
        .target(
            name: "LifeBoardContracts",
            path: "Packages/LifeBoardContracts/Sources/LifeBoardContracts"
        ),
        .target(
            name: "LifeBoardTokens",
            dependencies: ["LifeBoardContracts"],
            path: "Packages/LifeBoardTokens/Sources/LifeBoardTokens"
        ),
        .target(
            name: "LifeBoardUI",
            dependencies: ["LifeBoardContracts", "LifeBoardTokens"],
            path: "Packages/LifeBoardUI/Sources/LifeBoardUI"
        ),
        .target(
            name: "LifeBoardDomain",
            dependencies: ["LifeBoardContracts"],
            path: "Packages/LifeBoardDomain/Sources/LifeBoardDomain"
        ),
        .target(
            name: "LifeBoardPersistence",
            dependencies: ["LifeBoardContracts", "LifeBoardDomain"],
            path: "LifeBoard/Persistence",
            resources: [.process("Resources")]
        ),
        .target(
            name: "LifeBoardCalendar",
            dependencies: ["LifeBoardDomain"],
            path: "Packages/LifeBoardCalendar/Sources/LifeBoardCalendar"
        ),
        .target(
            name: "LifeBoardTranscription",
            dependencies: ["LifeBoardContracts"],
            path: "Packages/LifeBoardTranscription/Sources/LifeBoardTranscription"
        )
    ]
)
