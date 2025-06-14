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

    init(videoName: String) {
        self.videoName = videoName
    }

    func updateUIView(_: UIView, context _: UIViewRepresentableContext<PlayerView>) {}

    func makeUIView(context _: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName)
    }
}

class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()

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
        let asset = AVAsset(url: url)
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
            print("Failed to set audio session category: \(error)")
        }
        
        player.play()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
#endif

#if os(macOS)
struct PlayerView: NSViewRepresentable {
    var videoName: String
    
    init(videoName: String) {
        self.videoName = videoName
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No dynamic updates needed for this player
    }
    
    func makeNSView(context: Context) -> NSView {
        return LoopingPlayerNSView(videoName: videoName)
    }
}

class LoopingPlayerNSView: NSView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()
    
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
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = self.bounds
    }
}
#endif

/// SwiftUI wrapper for a looping Lottie animation
#if os(iOS) || os(visionOS)
struct LottieView: UIViewRepresentable {
    let animationName: String

    func makeUIView(context: Context) -> LottieAnimationView {
                let configuration = LottieConfiguration(renderingEngine: .coreAnimation)
        let animationView = LottieAnimationView(name: animationName, configuration: configuration)
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No dynamic updates needed yet
    }
}
#endif

struct MoonAnimationView: View {
    var isDone: Bool
    
    var body: some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.green)
            } else {
                // Lottie loading animation
                
                #if os(iOS) || os(visionOS)
                LottieView(animationName: "loading-animation")
                    .aspectRatio(contentMode: .fit)
                    .mask {
                        Circle()
                            .scale(0.30)
                    }
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
#endif
            }
        }
        .frame(width: 64, height: 64)
    }
}

#Preview {
    @Previewable @State var done = false
    VStack(spacing: 50) {
        Toggle(isOn: $done, label: { Text("Done") })
        MoonAnimationView(isDone: done)
    }
}
