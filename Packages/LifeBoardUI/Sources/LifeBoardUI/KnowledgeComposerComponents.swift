import LifeBoardTokens
import SwiftUI
import UIKit

// MARK: - Pushed page

/// The same clay entry surface for an editor that was **pushed**, not presented.
///
/// `ComposerScaffold` owns a `NavigationStack` and sheet presentation,
/// which a pushed destination must not do — it would nest a navigation stack
/// inside the one that pushed it and strand the back button. This is the same
/// canvas, scroll geometry and commit inset with the navigation left alone, so
/// the host's title and back affordance keep working.
@MainActor
public struct ComposerPage<Content: View, Commit: View>: View {
    private let subtitle: String?
    private let isPrivacySensitive: Bool
    private let identifier: String?
    private let content: Content
    private let commit: Commit

    public init(
        subtitle: String? = nil,
        isPrivacySensitive: Bool = false,
        identifier: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder commit: () -> Commit
    ) {
        self.subtitle = subtitle
        self.isPrivacySensitive = isPrivacySensitive
        self.identifier = identifier
        self.content = content()
        self.commit = commit()
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let subtitle {
                    Text(subtitle)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .modifier(ComposerPrivacy(isSensitive: isPrivacySensitive))
            .modifier(ComposerIdentity(identifier: identifier))
        }
        .scrollIndicators(.hidden)
        .background { ComposerCanvas() }
        .safeAreaInset(edge: .bottom, spacing: 0) { commit }
    }
}

// MARK: - Canvas

/// The composer's paper.
///
/// Grain sits **behind** content and never over it. It is a cached, deterministic
/// tile rather than a full-screen Metal `layerEffect`: the live effect joined the
/// keyboard's safe-area relayout and could keep a composer TextField in an
/// unbounded SwiftUI layout pass. The tile preserves the paper tooth without a
/// geometry reader, an offscreen render surface, or per-frame shader work.
private struct ComposerCanvas: View {
    var body: some View {
        GrainedCanvas(intensity: 0.42)
    }
}

/// Warm paper with its tooth, as one named view.
///
/// Every surface that wants grain uses this named view rather than rebuilding a
/// texture or introducing its own geometry reader. The tile is generated once
/// per process and repeated by UIKit's pattern-color renderer.
public struct GrainedCanvas: View {
    private let intensity: Double

    public init(intensity: Double = 0.30) {
        self.intensity = intensity
    }

    public var body: some View {
        Color(SemanticColorTokens.foundationCanvas)
            .lifeBoardPackagePaperGrain(intensity: intensity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ComposerPrivacy: ViewModifier {
    let isSensitive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSensitive {
            content.privacySensitive()
        } else {
            content
        }
    }
}

private struct ComposerIdentity: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

// MARK: - Section

/// A grouped clay section: prose on the canvas, controls on clay.
///
/// DESIGN.md is explicit that a card is justified only when its contents form
/// one independent decision, and that wrapping every section in a card is a
/// failure mode rather than a style. So the header, the explanatory detail and
/// the footnote all stay on open canvas where they read as writing, and only the
/// controls themselves take a surface. `Form` cannot express that distinction at
/// all — everything it contains becomes a row on the same grouped slab.
public struct ComposerSection<Content: View>: View {
    private let header: String?
    private let detail: String?
    private let footer: String?
    private let depth: ClayDepth
    private let cornerRadius: CGFloat
    private let spacing: CGFloat
    private let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ header: String? = nil,
        detail: String? = nil,
        footer: String? = nil,
        depth: ClayDepth = .resting,
        cornerRadius: CGFloat = 20,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.detail = detail
        self.footer = footer
        self.depth = depth
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if header != nil || detail != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let header {
                        Text(header)
                            .font(Typography.sectionTitle())
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    }
                    if let detail {
                        Text(detail)
                            .font(.lifeboard(.support))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .lifeBoardClaySurface(depth, cornerRadius: cornerRadius)

            if let footer {
                Text(footer)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .modifier(ComposerSectionLabel(header: header))
    }
}

private struct ComposerSectionLabel: ViewModifier {
    let header: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let header {
            content.accessibilityLabel(Text(header))
        } else {
            content
        }
    }
}

import SwiftUI

/// Paper tooth for package-side surfaces.
///
/// Grain is texture rather than motion, so it gates on contrast and transparency
/// — not on Reduce Motion, which has no opinion about a static surface. The
/// shared readiness verdict remains part of the contract so Calm, Low Power,
/// thermal pressure, and the signature-effects feature flag keep their existing
/// behavior even though this particular effect no longer needs Metal.
private struct PackagePaperGrain: ViewModifier {
    let intensity: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let appearanceFixture = VisualAppearanceFixture.active
        if reduceTransparency
            || appearanceFixture?.usesReducedTransparency == true
            || contrast == .increased
            || appearanceFixture?.usesHighContrast == true
            || ShaderReadiness.allowsShaderRendering == false {
            content
        } else {
            content.overlay {
                PackagePaperGrainTile(intensity: intensity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct PackagePaperGrainTile: UIViewRepresentable {
    let intensity: Double

    func makeUIView(context: Context) -> PaperGrainTileView {
        PaperGrainTileView()
    }

    func updateUIView(_ view: PaperGrainTileView, context: Context) {
        view.update(intensity: intensity)
    }
}

private final class PaperGrainTileView: UIView {
    private static let tileSize = CGSize(width: 128, height: 128)
    private static let seed: UInt64 = 0xD1CE_BA5E_1234_5678
    private static let tileImage = makeTileImage()
    private var appliedOpacity = -1.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.tileImage.map { UIColor(patternImage: $0) } ?? .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        layer.compositingFilter = "softLightBlendMode"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(intensity: Double) {
        let opacity = max(0, min(1, intensity)) * 0.10
        guard abs(opacity - appliedOpacity) > 0.0001 else { return }
        appliedOpacity = opacity
        alpha = opacity
        isHidden = opacity <= 0.0001 || Self.tileImage == nil
    }

    private static func makeTileImage() -> UIImage? {
        let width = Int(tileSize.width)
        let height = Int(tileSize.height)
        var pixels = [UInt8](repeating: 0, count: width * height)
        var randomState = seed

        for index in pixels.indices {
            randomState = (2862933555777941757 &* randomState) &+ 3037000493
            pixels[index] = UInt8((randomState >> 24) & 0xFF)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: image)
    }
}

public extension View {
    /// Package-side paper grain. Public because the feature packages
    /// (`KnowledgeFeature`, and anything else compiled outside the app target)
    /// physically cannot import `LifeBoard/DesignSystem`, which is why those
    /// surfaces had no signature effects at all rather than by choice.
    func lifeBoardPackagePaperGrain(intensity: Double) -> some View {
        modifier(PackagePaperGrain(intensity: intensity))
    }
}
