import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

final class OnboardingLoopingPlayerView: UIView {
    let playerLayer = AVPlayerLayer()
    let player = AVQueuePlayer()
    var playerLooper: AVPlayerLooper?
    var currentVideoName: String?

    init(videoName: String, accessibilityIdentifier: String) {
        super.init(frame: .zero)
        self.accessibilityIdentifier = accessibilityIdentifier
        backgroundColor = .black
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        isUserInteractionEnabled = false

        layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        player.isMuted = true
        player.actionAtItemEnd = .none

        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            player.pause()
        } else {
            player.play()
        }
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else {
            if window != nil {
                player.play()
            }
            return
        }

        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing onboarding hero asset: \(videoName).mp4")
            logWarning(
                event: "onboarding_missing_video_asset",
                message: "Missing bundled onboarding hero asset",
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
