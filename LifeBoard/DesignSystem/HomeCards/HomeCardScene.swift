import SwiftUI

/// Ambient paint fills an existing surface and never participates in its sizing.
struct HomeCardScene: View {
    let style: HomeCardPresentationStyle
    var assetName: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var direction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.homeCardGeometryRecorder) private var recorder
    @State private var loaded: UIImage?
    @State private var loadedKey: String?

    private var dark: Bool { colorScheme == .dark }
    private var key: String { HomeSceneImageCache.shared.key(kind: style.kind, dark: dark, assetName: assetName) }
    private var visible: Bool { !dynamicTypeSize.isAccessibilitySize && !reduceTransparency && contrast != .increased }

    var body: some View {
        GeometryReader { geometry in
            let image = recorder?.preparedScene ?? HomeSceneImageCache.shared.cached(kind: style.kind, dark: dark, assetName: assetName) ?? (loadedKey == key ? loaded : nil)
            let _ = record(geometry.size)
            if visible, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    .clipped()
                    .mask {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.08), location: 0),
                            .init(color: .black.opacity(0.20), location: 0.35),
                            .init(color: .black, location: 1)
                        ], startPoint: direction == .leftToRight ? .leading : .trailing,
                           endPoint: direction == .leftToRight ? .trailing : .leading)
                    }
                    .opacity(style.preset == .compact ? 0.18 : (dark ? 0.28 : 0.24))
            }
        }
        .task(id: visible ? key : "hidden") {
            guard visible else { loaded = nil; loadedKey = nil; return }
            let requestedKey = key
            let image = await HomeSceneImageCache.shared.load(kind: style.kind, dark: dark, assetName: assetName)
            guard !Task.isCancelled else { return }
            loaded = image
            loadedKey = requestedKey
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func record(_ size: CGSize) {
        recorder?.content = CGRect(origin: .zero, size: size)
        recorder?.scene = CGRect(origin: .zero, size: size)
    }
}
