import AVKit
import SwiftUI

#if os(iOS) || os(visionOS)
import Lottie
#elseif os(macOS)
import AppKit
#endif

enum EvaMediaAsset {
    static let introVideoName = "EvaIntroVideo"
    static let introLottieName = "EvaLottie00-lite"
}

#if os(iOS) || os(visionOS)
struct EvaLoopingVideoView: UIViewRepresentable {
    let videoName: String

    func makeUIView(context: Context) -> EvaLoopingPlayerUIView {
        EvaLoopingPlayerUIView(videoName: videoName)
    }

    func updateUIView(_ uiView: EvaLoopingPlayerUIView, context: Context) {
        uiView.update(videoName: videoName)
    }
}

final class EvaLoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private let player = AVQueuePlayer()
    private var currentVideoName: String?

    init(videoName: String) {
        super.init(frame: .zero)
        layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else { return }
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing Eva media asset: \(videoName).mp4")
            logWarning(
                event: "eva_media_missing_video_asset",
                message: "Missing bundled Eva media asset",
                fields: ["video_name": videoName]
            )
            return
        }
        currentVideoName = videoName
        let url = URL(fileURLWithPath: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}

struct EvaLoopingLottieView: UIViewRepresentable {
    let animationName: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let configuration = LottieConfiguration(renderingEngine: .coreAnimation)
        let animationView = LottieAnimationView(name: animationName, configuration: configuration)
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.isAnimationPlaying == false {
            uiView.play()
        }
    }
}
#elseif os(macOS)
struct EvaLoopingVideoView: NSViewRepresentable {
    let videoName: String

    func makeNSView(context: Context) -> EvaLoopingPlayerNSView {
        EvaLoopingPlayerNSView(videoName: videoName)
    }

    func updateNSView(_ nsView: EvaLoopingPlayerNSView, context: Context) {
        nsView.update(videoName: videoName)
    }
}

final class EvaLoopingPlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private let player = AVQueuePlayer()
    private var currentVideoName: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    convenience init(videoName: String) {
        self.init(frame: .zero)
        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else { return }
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing Eva media asset: \(videoName).mp4")
            logWarning(
                event: "eva_media_missing_video_asset",
                message: "Missing bundled Eva media asset",
                fields: ["video_name": videoName]
            )
            return
        }
        currentVideoName = videoName
        let url = URL(fileURLWithPath: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}
#endif

enum EvaHeroMediaPresentationStyle {
    case card
    case fullBleed
}

struct EvaHeroMediaView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: EvaHeroMediaPresentationStyle

    init(style: EvaHeroMediaPresentationStyle = .card) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .card:
            cardBody
        case .fullBleed:
            fullBleedBody
        }
    }

    private var cardBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker(.surfacePrimary),
                            Color.tasker(.accentWash).opacity(0.62),
                            Color.tasker(.surfacePrimary)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if reduceMotion {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                EvaLoopingVideoView(videoName: EvaMediaAsset.introVideoName)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.tasker(.bgCanvas).opacity(0.02),
                                Color.tasker(.bgCanvas).opacity(0.08),
                                Color.tasker(.bgCanvas).opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous))
                    )
                    .overlay(alignment: .bottomTrailing) {
                        EvaLoopingLottieContainer(size: 76)
                            .padding(TaskerTheme.Spacing.md)
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
        .shadow(color: Color.tasker(.accentPrimary).opacity(0.12), radius: 18, y: 10)
    }

    private var fullBleedBody: some View {
        ZStack {
            if reduceMotion {
                LinearGradient(
                    colors: [
                        Color.tasker(.surfacePrimary),
                        Color.tasker(.accentWash).opacity(0.62),
                        Color.tasker(.surfacePrimary)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                EvaLoopingVideoView(videoName: EvaMediaAsset.introVideoName)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.tasker(.bgCanvas).opacity(0.02),
                                Color.tasker(.bgCanvas).opacity(0.08),
                                Color.tasker(.bgCanvas).opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        EvaLoopingLottieContainer(size: 76)
                            .padding(TaskerTheme.Spacing.md)
                    }
            }
        }
    }
}

struct EvaLoopingLottieContainer: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.tasker(.bgCanvas).opacity(0.78))
                .overlay(Circle().stroke(Color.tasker(.strokeHairline), lineWidth: 1))
            if reduceMotion {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                #if os(iOS) || os(visionOS)
                EvaLoopingLottieView(animationName: EvaMediaAsset.introLottieName)
                    .padding(size * 0.14)
                #else
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                #endif
            }
        }
        .frame(width: size, height: size)
    }
}

struct EvaInstallStatusView: View {
    let isComplete: Bool
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tasker(.surfaceTertiary), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    LinearGradient(
                        colors: [Color.tasker(.accentPrimary), Color.tasker(.accentSecondary)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(TaskerAnimation.heroReveal, value: progress)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Color.tasker(.statusSuccess))
            } else {
                ZStack {
                    EvaLoopingLottieContainer(size: 92)
                    Circle()
                        .fill(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.tasker(.accentMuted).opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .frame(width: 140, height: 140)
    }
}
