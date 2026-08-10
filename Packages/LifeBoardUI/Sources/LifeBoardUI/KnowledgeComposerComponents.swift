import LifeBoardTokens
import SwiftUI

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
            VStack(alignment: .leading, spacing: 18) {
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
/// Grain sits **behind** content and never over it. Applying a `layerEffect` to
/// a whole scrolling composer asks Metal to flatten every control, label and
/// field into one oversized render surface; keeping it in the background is both
/// cheaper and makes it structurally impossible for the shader to soften type.
/// The workspace redesign learned this the expensive way and left the note at
/// `WeeklyPlanningWorkspaceView.swift:104`.
///
/// The two layers are not redundant. `.lifeboardPaperGrain` is a `layerEffect`,
/// and a `layerEffect` applied to a bare `Color` rasterizes to nothing: this
/// composer rendered as the sheet's plain elevated fill (#FFFDF7) instead of
/// warm paper (#FFF7D8) until the pixels were sampled and compared. So the flat
/// canvas is painted unconditionally underneath, and the grain rides a
/// `Rectangle` that a `GeometryReader` has given a concrete size — which is the
/// thing the effect can actually rasterize. If the shader is unavailable the
/// texture simply never arrives and the paper is still paper.
private struct ComposerCanvas: View {
    var body: some View {
        GrainedCanvas(intensity: 0.42)
    }
}

/// Warm paper with its tooth, as one named view.
///
/// Every surface that wants grain uses this rather than inlining the two-layer
/// `ZStack` + `GeometryReader`. Inlining it four times was not just duplication:
/// dropping the closure into an existing `body` pushed
/// `KnowledgeNoteEditor` from under to over the 500 ms type-check
/// budget this repo treats as a required split. A named `View` gets its own
/// `body` call, its own stack frame, and costs the caller one identifier.
public struct GrainedCanvas: View {
    private let intensity: Double

    public init(intensity: Double = 0.30) {
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            Color(SemanticColorTokens.foundationCanvas)
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color(SemanticColorTokens.foundationCanvas))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .lifeBoardPackagePaperGrain(intensity: intensity)
            }
        }
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
/// The readiness check is not optional politeness: this was the one shader call
/// site in the app that reached for `ShaderFunction(library: .default, …)`
/// without asking whether the Metal library had finished warming, so on a cold
/// launch it could attempt a function that did not exist yet. `ShaderReadiness`
/// lives in `LifeBoardTokens` precisely so this package can ask.
///
/// Grain is texture rather than motion, so it gates on contrast and transparency
/// — not on Reduce Motion, which has no opinion about a static surface.
private struct PackagePaperGrain: ViewModifier {
    let intensity: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased || ShaderReadiness.allowsShaderRendering == false {
            content
        } else {
            content.layerEffect(
                Shader(
                    function: ShaderFunction(library: .default, name: "LifeBoardPaperGrain"),
                    arguments: [
                        .float2(1, 1),
                        .float(Float(max(0, min(1, intensity))))
                    ]
                ),
                maxSampleOffset: .zero
            )
        }
    }
}

private extension View {
    func lifeBoardPackagePaperGrain(intensity: Double) -> some View {
        modifier(PackagePaperGrain(intensity: intensity))
    }
}
