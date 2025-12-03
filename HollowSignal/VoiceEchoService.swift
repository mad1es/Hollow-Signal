import Foundation
import AVFoundation

/// Service for creating voice echo effects - plays back player's voice with delay
class VoiceEchoService {
    static let shared = VoiceEchoService()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordedAudioURL: URL?
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
    
    /// Play back recorded voice with delay and echo effect
    /// - Parameter delay: Delay in seconds before playback starts
    /// - Parameter echoIntensity: Intensity of echo effect (0.0 - 1.0)
    func playEcho(delay: TimeInterval = 2.0, echoIntensity: Float = 0.5) {
        guard let url = recordedAudioURL, FileManager.default.fileExists(atPath: url.path) else {
            LogService.shared.log(.sensors, "No recorded audio to play echo")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playbackEcho(url: url, intensity: echoIntensity)
        }
    }
    
    private func playbackEcho(url: URL, intensity: Float) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = intensity
            audioPlayer?.play()
            LogService.shared.log(.sensors, "Playing voice echo with intensity \(intensity)")
        } catch {
            LogService.shared.log(.sensors, "Failed to play echo: \(error.localizedDescription)")
        }
    }
    
    /// Clean up recorded audio file
    func cleanup() {
        audioRecorder?.stop()
        audioPlayer?.stop()
        
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
            recordedAudioURL = nil
        }
        
        isRecording = false
    }
}

