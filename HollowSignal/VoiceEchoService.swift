import Foundation
import AVFoundation

/// Service for creating distorted voice echo effects - plays back player's voice with delay and distortion
class VoiceEchoService {
    static let shared = VoiceEchoService()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var recordedAudioURL: URL?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    
    private init() {}
    
    /// Start recording player's voice
    func startRecording() {
        guard !isRecording else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            LogService.shared.log(.sensors, "Failed to setup audio session: \(error.localizedDescription)")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordedAudioURL = documentsPath.appendingPathComponent("voice_echo_\(UUID().uuidString).m4a")
        
        guard let url = recordedAudioURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            LogService.shared.log(.sensors, "Started voice recording for echo effect")
        } catch {
            LogService.shared.log(.sensors, "Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    /// Stop recording and prepare for playback
    func stopRecording() {
        guard isRecording else { return }
        audioRecorder?.stop()
        isRecording = false
        LogService.shared.log(.sensors, "Stopped voice recording")
    }
    
    /// Play back recorded voice with delay and heavy distortion effect
    /// - Parameter delay: Delay in seconds before playback starts
    /// - Parameter distortionIntensity: Intensity of distortion effect (0.0 - 1.0)
    func playEcho(delay: TimeInterval = 2.0, distortionIntensity: Float = 0.8) {
        // Проверяем настройки
        guard UserDefaults.standard.bool(forKey: "voiceEchoEnabled") else {
            LogService.shared.log(.sensors, "Voice echo disabled in settings")
            return
        }
        
        guard let url = recordedAudioURL, FileManager.default.fileExists(atPath: url.path) else {
            LogService.shared.log(.sensors, "No recorded audio to play echo")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playbackDistortedEcho(url: url, intensity: distortionIntensity)
        }
    }
    
    private func playbackDistortedEcho(url: URL, intensity: Float) {
        do {
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile = audioFile else { return }
            
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
            
            engine.attach(playerNode)
            
            // Create distortion effect
            let distortion = AVAudioUnitDistortion()
            distortion.loadFactoryPreset(.multiBrokenSpeaker)
            distortion.wetDryMix = intensity * 100
            distortion.preGain = 20
            distortion.bypass = false
            
            engine.attach(distortion)
            
            // Create reverb for echo effect
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.cathedral)
            reverb.wetDryMix = intensity * 50
            reverb.bypass = false
            
            engine.attach(reverb)
            
            // Create pitch shift for creepy effect
            let pitchShift = AVAudioUnitTimePitch()
            pitchShift.pitch = -800 // Lower pitch for creepy effect
            pitchShift.rate = 0.8 // Slightly slower
            
            engine.attach(pitchShift)
            
            // Connect nodes: player -> pitch -> distortion -> reverb -> output
            engine.connect(playerNode, to: pitchShift, format: audioFile.processingFormat)
            engine.connect(pitchShift, to: distortion, format: audioFile.processingFormat)
            engine.connect(distortion, to: reverb, format: audioFile.processingFormat)
            engine.connect(reverb, to: engine.mainMixerNode, format: audioFile.processingFormat)
            
            try engine.start()
            
            playerNode.scheduleFile(audioFile, at: nil) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.stop()
                    playerNode.stop()
                }
            }
            
            playerNode.volume = intensity
            playerNode.play()
            
            LogService.shared.log(.sensors, "Playing distorted voice echo with intensity \(intensity)")
        } catch {
            LogService.shared.log(.sensors, "Failed to play distorted echo: \(error.localizedDescription)")
            // Fallback to simple playback
            fallbackPlayback(url: url, intensity: intensity)
        }
    }
    
    private func fallbackPlayback(url: URL, intensity: Float) {
        do {
            let simplePlayer = try AVAudioPlayer(contentsOf: url)
            simplePlayer.volume = intensity
            simplePlayer.rate = 0.7 // Slower playback
            simplePlayer.play()
        } catch {
            LogService.shared.log(.sensors, "Failed fallback playback: \(error.localizedDescription)")
        }
    }
    
    /// Clean up recorded audio file
    func cleanup() {
        audioRecorder?.stop()
        audioPlayerNode?.stop()
        audioEngine?.stop()
        
        audioRecorder = nil
        audioPlayerNode = nil
        audioEngine = nil
        audioFile = nil
        
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
            recordedAudioURL = nil
        }
        
        isRecording = false
    }
}

