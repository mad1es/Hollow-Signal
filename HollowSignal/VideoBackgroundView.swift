import SwiftUI
import AVKit
import AVFoundation

struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    let videoType: String
    @Binding var shouldPlay: Bool
    var onFinished: (() -> Void)?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        guard let path = Bundle.main.path(forResource: videoName, ofType: videoType) else {
            LogService.shared.log(.system, "Video file not found: \(videoName).\(videoType)")
            return view
        }
        
        let url = URL(fileURLWithPath: path)
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        context.coordinator.playerItem = playerItem
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        player.seek(to: .zero) { finished in
            if finished {
                player.pause()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerLayer = context.coordinator.playerLayer,
              let player = context.coordinator.player else { return }
        
        playerLayer.frame = uiView.bounds
        
        if shouldPlay {
            if player.timeControlStatus != .playing {
                player.play()
            }
        } else {
            if player.timeControlStatus == .playing {
                player.pause()
            }
            player.seek(to: .zero) { finished in
                if finished {
                    player.pause()
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.playerLayer = nil
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var onFinished: (() -> Void)?
        var playerItem: AVPlayerItem?
        
        init(onFinished: (() -> Void)?) {
            self.onFinished = onFinished
        }
        
        @objc func playerDidFinishPlaying() {
            DispatchQueue.main.async {
                self.player?.pause()
                self.onFinished?()
            }
        }
    }
}

