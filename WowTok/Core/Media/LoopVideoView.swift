import SwiftUI
import AVFoundation
import UIKit

/// Seamless looper for MP4 wallpapers. Uses AVPlayerLooper so there is no visible
/// gap between repeats, and honours the Low Power Mode tweak.
struct LoopVideoView: UIViewRepresentable {
    let url: URL
    var looping: Bool = true
    var muted: Bool = true
    var pauseOnLowPower: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url, looping: looping, muted: muted, pauseOnLowPower: pauseOnLowPower)
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        uiView.configure(url: url, looping: looping, muted: muted, pauseOnLowPower: pauseOnLowPower)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    private var looping = true
    private var muted = true
    private var pauseOnLowPower = true
    private var isPlaying = false

    init(url: URL, looping: Bool, muted: Bool, pauseOnLowPower: Bool) {
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(powerStateChanged),
                                              name: .NSProcessInfoPowerStateDidChange,
                                              object: nil)
        configure(url: url, looping: looping, muted: muted, pauseOnLowPower: pauseOnLowPower)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(url: URL, looping: Bool, muted: Bool, pauseOnLowPower: Bool) {
        self.pauseOnLowPower = pauseOnLowPower
        self.looping = looping
        self.muted = muted
        queuePlayer?.isMuted = muted

        if currentURL != url {
            currentURL = url
            rebuild(url: url)
        }
        updatePowerState()
        play()
    }

    func play() {
        guard !(pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled) else { return }
        queuePlayer?.play()
        isPlaying = true
    }

    func pause() {
        queuePlayer?.pause()
        isPlaying = false
    }

    func stop() {
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        playerLayer.player = nil
        currentURL = nil
    }

    private func rebuild(url: URL) {
        looper?.disableLooping()
        queuePlayer?.pause()

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = muted
        player.actionAtItemEnd = .advance

        if looping {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            queuePlayer?.removeAllItems()
            player.insert(item, after: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(restartIfNeeded(_:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: item)
        }

        queuePlayer = player
        playerLayer.player = player
    }

    @objc private func restartIfNeeded(_ note: Notification) {
        guard looping == false else { return }
        queuePlayer?.seek(to: .zero)
        queuePlayer?.play()
    }

    @objc private func powerStateChanged() {
        updatePowerState()
    }

    private func updatePowerState() {
        guard pauseOnLowPower else { return }
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            queuePlayer?.pause()
        } else {
            queuePlayer?.play()
        }
    }
}
