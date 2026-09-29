struct LifeMapSceneNode: Identifiable, Equatable {
    enum Kind: Equatable { case root, lifeArea }

    let id: String
    let title: String
    let symbol: String
    let colorHex: String?
    let kind: Kind
    let emphasis: Double
}

struct LifeMapSceneModel: Equatable {
    static let roots: [LifeMapSceneNode] = [
        .init(id: "home", title: "Home", symbol: "house.fill", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "plan", title: "Plan", symbol: "calendar", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "track", title: "Track", symbol: "chart.bar.fill", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "insights", title: "Insights", symbol: "sparkles", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "eva", title: "Eva", symbol: "wand.and.stars", colorHex: nil, kind: .root, emphasis: 1)
    ]

    var roots = Self.roots
    var lifeAreas: [LifeMapSceneNode]
    var capacityFraction: Double
    var centerPromise: String
    var captureTitle: String?
}
