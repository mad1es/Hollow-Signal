import Foundation
import AVFoundation
import AudioToolbox
import SwiftUI

final class HorrorEffectsManager {
    static let shared = HorrorEffectsManager()
    
    private let heartbeatHaptics = HeartbeatHaptics()
    private let queue = DispatchQueue(label: "com.hollowsignal.effects", qos: .userInitiated)
    private var torchDevice: AVCaptureDevice? = AVCaptureDevice.default(for: .video)
    private var audioPlayers: [AVAudioPlayer] = []
    
    private var hapticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    private var soundsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundsEnabled")
    }
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            LogService.shared.log(.system, "Audio session setup failed: \(error.localizedDescription)")
        }
    }
    
    func triggerHeartbeatPulse(bpm: Double = 74) {
        guard hapticsEnabled else { return }
        
        if let heartbeatHaptics {
            heartbeatHaptics.playPulse(bpm: bpm)
        } else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    func startHeartbeatLoop(bpm: Double = 70) {
        guard hapticsEnabled else { return }
        heartbeatHaptics?.startLoop(bpm: bpm)
    }
    
    func stopHeartbeatLoop() {
        heartbeatHaptics?.stopLoop()
    }
    
    func playWhisperSound() {
        guard soundsEnabled else { return }
        queue.async {
            AudioServicesPlaySystemSound(1304)
        }
    }
    
    func playGlitchNoise() {
        guard soundsEnabled else { return }
        queue.async {
            AudioServicesPlaySystemSound(1108)
        }
    }
    
    func playHorrorSound(_ soundType: HorrorSoundType, volume: Float = 0.7) {
        guard soundsEnabled else { return }
        
        queue.async { [weak self] in
            self?.playSystemSound(type: soundType, volume: volume)
        }
    }
    
    private func playSystemSound(type: HorrorSoundType, volume: Float) {
        let soundID: SystemSoundID
        
        switch type {
        case .deepRumble:
            soundID = 1054
        case .staticNoise:
            soundID = 1108
        case .screech:
            soundID = 1057
        case .whisper:
            soundID = 1304
        case .heartbeat:
            soundID = 1053
        }
        
        AudioServicesPlaySystemSound(soundID)
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

enum HorrorSoundType {
    case deepRumble
    case staticNoise
    case screech
    case whisper
    case heartbeat
}

