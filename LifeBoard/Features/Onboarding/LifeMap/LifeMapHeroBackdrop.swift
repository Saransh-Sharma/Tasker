import AVFoundation
import LifeBoardTokens
import SwiftUI
import UIKit

/// The looping dawn video that sits behind the whole flow, plus the scrim that
/// makes text legible on top of it.
///
/// One lifetime-managed player for the entire flow, not one per step: the video
/// is the single ambient timeline (`DESIGN.md`: "At most one ambient timeline
/// per screen"). Nothing else in onboarding may run a perpetual clock — orbit,
/// clay, and shader motion are all event-driven.

// MARK: - Player

private final class LifeMapLoopingPlayerView: UIView {
    let playerLayer = AVPlayerLayer()
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var wantsPlayback = true
    private nonisolated(unsafe) var lifecycleObservers: [NSObjectProtocol] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        isUserInteractionEnabled = false
        layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        // Muted for the whole lifetime, and the audio session is never touched:
        // onboarding must not duck or interrupt whatever the user is listening to.
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        if let url = LifeMapHeroVideo.url {
            let item = AVPlayerItem(asset: AVURLAsset(url: url))
            looper = AVPlayerLooper(player: player, templateItem: item)
        }
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reconcilePlayback()
                }
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.player.pause()
                }
            }
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        player.pause()
        player.removeAllItems()
        looper = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcilePlayback()
    }

    func update(wantsPlayback: Bool) {
        self.wantsPlayback = wantsPlayback
        reconcilePlayback()
    }

    /// Resumes rather than restarts — `playImmediately` keeps the current time,
    /// so returning from the background does not snap the dawn back to frame 0.
    private func reconcilePlayback() {
        if window != nil, wantsPlayback, UIApplication.shared.applicationState != .background {
            player.playImmediately(atRate: 1)
        } else {
            player.pause()
        }
    }
}

private struct LifeMapHeroVideoView: UIViewRepresentable {
    let isPlaying: Bool

    func makeUIView(context: Context) -> LifeMapLoopingPlayerView {
        let view = LifeMapLoopingPlayerView()
        view.update(wantsPlayback: isPlaying)
        return view
    }

    func updateUIView(_ uiView: LifeMapLoopingPlayerView, context: Context) {
        uiView.update(wantsPlayback: isPlaying)
    }
}

enum LifeMapHeroVideo {
    static let resourceName = "HeroWelcomeHighCompressMb"

    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    static var isAvailable: Bool { url != nil }
}

// MARK: - Backdrop

struct LifeMapOnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @State private var powerRevision = 0

    private var effectiveReduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }

    /// Low Power and thermal pressure are non-overridable — `DESIGN.md` treats
    /// them as gates the user cannot turn off, unlike Reduce Motion.
    private var isEnergyConstrained: Bool {
        _ = powerRevision
        return ProcessInfo.processInfo.isLowPowerModeEnabled
            || ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical
    }

    private var playsVideo: Bool {
        LifeMapHeroVideo.isAvailable
            && effectiveReduceMotion == false
            && reduceTransparency == false
            && isEnergyConstrained == false
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if reduceTransparency {
                    // Geometry-identical opaque surface. Reduce Transparency asks
                    // for no see-through layers, not for a different layout.
                    Color.lifeboard(.bgCanvas)
                } else {
                    posterFallback
                    if playsVideo {
                        LifeMapHeroVideoView(isPlaying: true)
                            .transition(.opacity)
                    }
                    scrim
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            powerRevision &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            powerRevision &+= 1
        }
    }

    /// The veil that buys contrast without hiding the video.
    ///
    /// `.bgCanvas` is already the adaptive warm-paper / indigo-night token, so
    /// scrimming toward it keeps the blue-pink dawn recognizable in both
    /// appearances while pulling body text back over the 4.5:1 floor. The
    /// vertical ramp is heavier at top and bottom, where the chrome and the dock
    /// sit, and lightest across the middle, where the orbit shows through.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: Color.lifeboard(.bgCanvas).opacity(topOpacity), location: 0),
                .init(color: Color.lifeboard(.bgCanvas).opacity(midOpacity), location: 0.42),
                .init(color: Color.lifeboard(.bgCanvas).opacity(bottomOpacity), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Light appearance needs a heavier veil than dark: the dawn video is bright,
    // so cocoa ink on an unscrimmed frame lands well under the contrast floor.
    //
    // The *top* band is the exception, and it is sized differently from the rest.
    // No body copy lives up there — it is where the Life Map draws — and a cream
    // veil at 0.74 over a bright dawn frame left that whole region a flat pale
    // wash with the map's hairlines invisible inside it. Light mode now lets the
    // scene through at the top and keeps its full strength across the reading
    // field below, where the contrast floor actually has to be met.
    private var topOpacity: Double {
        if contrast == .increased { return colorScheme == .dark ? 0.86 : 0.90 }
        return colorScheme == .dark ? 0.58 : 0.44
    }

    private var midOpacity: Double {
        if contrast == .increased { return colorScheme == .dark ? 0.74 : 0.80 }
        return colorScheme == .dark ? 0.44 : 0.56
    }

    private var bottomOpacity: Double {
        if contrast == .increased { return colorScheme == .dark ? 0.92 : 0.94 }
        return colorScheme == .dark ? 0.74 : 0.82
    }

    private var posterFallback: some View {
        ZStack {
            Color.lifeboard(.bgCanvas)
            Image("HeroWelcomePoster")
                .resizable()
                .scaledToFill()
                .opacity(0.85)
        }
    }
}
