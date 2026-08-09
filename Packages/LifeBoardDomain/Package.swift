// swift-tools-version: 6.0
import PackageDescription

// The domain layer: entities, value types, domain services and the repository
// ports the app implements against.
//
// This package is the acceptance test for the whole reorganization. It compiles
// with no dependency on any other LifeBoard module, which is only true because
// four separate upward references were removed first: seven typealiases into
// `State/`, eight domain types filed under Presentation/UseCases, a
// presentation mapping function, and three unused imports.
//
// Nothing here may import SwiftUI, UIKit or CoreData. Persistence is a detail of
// the adapters; this package only declares the ports.
let package = Package(
    name: "LifeBoardDomain",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "LifeBoardDomain", targets: ["LifeBoardDomain"])
    ],
    targets: [
        .target(name: "LifeBoardDomain")
    ]
)
