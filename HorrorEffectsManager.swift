import Foundation
import AVFoundation
import AudioToolbox

final class HorrorEffectsManager {
    static let shared = HorrorEffectsManager()
    
    private let heartbeatHaptics = HeartbeatHaptics()
    private let queue = DispatchQueue(label: "com.hollowsignal.effects", qos: .userInitiated)
    private var torchDevice: AVCaptureDevice? = AVCaptureDevice.default(for: .video)
    
    private init() {
        // nothing yet
    }
    
    func triggerHeartbeatPulse(bpm: Double = 74) {
        if let heartbeatHaptics {
            heartbeatHaptics.playPulse(bpm: bpm)
        } else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    func startHeartbeatLoop(bpm: Double = 70) {
        heartbeatHaptics?.startLoop(bpm: bpm)
    }
    
    func stopHeartbeatLoop() {
        heartbeatHaptics?.stopLoop()
    }
    
    func playWhisperSound() {
        queue.async {
            AudioServicesPlaySystemSound(1304) // subtle keyboard click as placeholder whisper
        }
    }
    
    func playGlitchNoise() {
        queue.async {
            AudioServicesPlaySystemSound(1108)
        }
    }
    
    func flashTorch(duration: TimeInterval = 0.2) {
        guard let device = torchDevice, device.hasTorch else { return }
        queue.async {
            do {
                try device.lockForConfiguration()
                try device.setTorchModeOn(level: 1.0)
                device.unlockForConfiguration()
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    do {
                        try device.lockForConfiguration()
                        device.torchMode = .off
                        device.unlockForConfiguration()
                    } catch {
                        LogService.shared.log(.system, "Torch unlock failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                LogService.shared.log(.system, "Torch failed: \(error.localizedDescription)")
            }
        }
    }
}

