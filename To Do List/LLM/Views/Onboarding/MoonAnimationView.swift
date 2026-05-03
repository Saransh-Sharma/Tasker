//
//  MoonAnimationView.swift
//
//

import AVKit
import SwiftUI
import Lottie

#if os(macOS)
import AppKit
#endif

#if os(iOS) || os(visionOS)
struct PlayerView: UIViewRepresentable {
    var videoName: String

    /// Initializes a new instance.
    init(videoName: String) {
        self.videoName = videoName
    }

    /// Executes updateUIView.
    func updateUIView(_: UIView, context _: UIViewRepresentableContext<PlayerView>) {}

    /// Executes makeUIView.
    func makeUIView(context _: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        (uiView as? LoopingPlayerUIView)?.tearDownPlayback()
    }
}

class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()

    /// Initializes a new instance.
    init(videoName: String) {
        super.init(frame: .zero)

        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            // Fallback: show a static moon SF Symbol instead of crashing.
            let fallback = UIImageView(image: UIImage(systemName: "moon"))
            fallback.contentMode = .scaleAspectFit
            fallback.tintColor = .secondaryLabel
            addSubview(fallback)
            fallback.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                fallback.leadingAnchor.constraint(equalTo: leadingAnchor),
                fallback.trailingAnchor.constraint(equalTo: trailingAnchor),
                fallback.topAnchor.constraint(equalTo: topAnchor),
                fallback.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            return
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        // Prevent other audio from stopping
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logError("Failed to set audio session category: \(error)")
        }

        player.play()
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes layoutSubviews.
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    deinit {
        MainActor.assumeIsolated {
            tearDownPlayback()
        }
    }

    func tearDownPlayback() {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
        playerLayer.player = nil
    }
}
#endif

#if os(macOS)
struct PlayerView: NSViewRepresentable {
    var videoName: String

    /// Initializes a new instance.
    init(videoName: String) {
        self.videoName = videoName
    }

    /// Executes updateNSView.
    func updateNSView(_ nsView: NSView, context: Context) {
        // No dynamic updates needed for this player
    }

    /// Executes makeNSView.
    func makeNSView(context: Context) -> NSView {
        return LoopingPlayerNSView(videoName: videoName)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? LoopingPlayerNSView)?.tearDownPlayback()
    }
}

class LoopingPlayerNSView: NSView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()

    /// Initializes a new instance.
    init(videoName: String) {
        // Ensure the video file exists
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            fatalError("Video file \(videoName).mp4 not found in bundle.")
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        super.init(frame: .zero)

        // Configure the player layer
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        self.wantsLayer = true
        self.layer?.addSublayer(playerLayer)

        // Setup looping
        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        // Start playback
        player.play()
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes layout.
    override func layout() {
        super.layout()
        playerLayer.frame = self.bounds
    }

    deinit {
        tearDownPlayback()
    }

    func tearDownPlayback() {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
        playerLayer.player = nil
    }
}
#endif

/// SwiftUI wrapper for a looping Lottie animation
#if os(iOS) || os(visionOS)
struct LottieView: UIViewRepresentable {
    let animationName: String

    /// Executes makeUIView.
    func makeUIView(context: Context) -> LottieAnimationView {
                let configuration = LottieConfiguration(renderingEngine: .coreAnimation)
        let animationView = LottieAnimationView(name: animationName, configuration: configuration)
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.play()
        return animationView
    }

    /// Executes updateUIView.
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No dynamic updates needed yet
    }

    static func dismantleUIView(_ uiView: LottieAnimationView, coordinator: ()) {
        uiView.stop()
    }
}
#endif

struct MoonAnimationView: View {
    var isDone: Bool

    var body: some View {
        ZStack {
            if isDone {
                ZStack {
                    Circle()
                        .fill(Color.tasker(.statusSuccess).opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .foregroundColor(Color.tasker(.statusSuccess))
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Lottie loading animation

                #if os(iOS) || os(visionOS)
                LottieView(animationName: "loading-animation")
                    .aspectRatio(contentMode: .fit)
                    .mask {
                        Circle()
                            .scale(0.30)
                    }
                    .transition(.scale.combined(with: .opacity))
#else
                // Fallback on macOS: chat bubbles symbol with wiggle effect
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
                    .mask {
                        Circle()
                            .scale(0.40)
                    }
                    .transition(.scale.combined(with: .opacity))
#endif
            }
        }
        .frame(width: 88, height: 88)
        .animation(TaskerAnimation.bouncy, value: isDone)
    }
}

#Preview {
    @Previewable @State var done = false
    VStack(spacing: 50) {
        Toggle(isOn: $done, label: { Text("Done") })
        MoonAnimationView(isDone: done)
    }
}
