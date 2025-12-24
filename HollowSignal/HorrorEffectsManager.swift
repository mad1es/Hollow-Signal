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
    
    /// Системная вибрация - самая надежная, не использует CoreHaptics
    func triggerSystemVibration(count: Int = 1, interval: TimeInterval = 0.5) {
        guard hapticsEnabled else { return }
        
        DispatchQueue.main.async {
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            }
        }
    }
    
    /// Интенсивная вибрация для запугивания
    func triggerIntenseVibration(duration: TimeInterval = 2.0) {
        triggerSystemVibration(count: 4, interval: duration / 4.0)
    }
    
    /// ОЧЕНЬ СИЛЬНАЯ И НАДЕЖНАЯ вибрация для режима безумия
    func triggerCrazyModeVibration() {
        guard hapticsEnabled else { return }
        
        // Используем ТОЛЬКО системную вибрацию - это самый надежный способ
        DispatchQueue.main.async {
            // Первая серия - 15 быстрых вибраций
            for i in 0..<15 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            }
            
            // Вторая серия через 2 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                for j in 0..<10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(j) * 0.12) {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                }
            }
        }
    }
    
    /// Громкие пугающие звуки в начале игры
    func playIntenseStartupSounds() {
        guard soundsEnabled else { return }
        
        queue.async { [weak self] in
            // Серия громких звуков
            self?.playSystemSound(type: .screech, volume: 1.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.playSystemSound(type: .deepRumble, volume: 1.0)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self?.playSystemSound(type: .staticNoise, volume: 1.0)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self?.playSystemSound(type: .screech, volume: 0.9)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self?.playSystemSound(type: .deepRumble, volume: 0.8)
            }
        }
    }
    
    /// ГРОМКИЕ КРИЧАЩИЕ ЗВУКИ для режима безумия
    func playCrazyModeSounds() {
        guard soundsEnabled else { return }
        
        queue.async { [weak self] in
            // Интенсивная серия громких кричащих звуков
            for i in 0..<15 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    if i % 3 == 0 {
                        self?.playSystemSound(type: .screech, volume: 1.0)
                    } else if i % 3 == 1 {
                        self?.playSystemSound(type: .deepRumble, volume: 1.0)
                    } else {
                        self?.playSystemSound(type: .staticNoise, volume: 1.0)
                    }
                }
            }
            
            // Дополнительные звуки
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                for j in 0..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(j) * 0.1) {
                        self?.playSystemSound(type: .screech, volume: 0.9)
                    }
                }
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

