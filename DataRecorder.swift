import Foundation
import CoreLocation
import AVFoundation
import CoreMotion
import UIKit

class DataRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordedData: SessionData = SessionData()
    
    private let locationManager = CLLocationManager()
    private var motionManager: CMMotionManager?
    
    // Аудио запись
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // Таймеры для записи данных
    private var recordingTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupMotionManager() {
        motionManager = CMMotionManager()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.recordedData = SessionData()
            self?.recordedData.startTime = Date()
            LogService.shared.log(.sensors, "Recording session started")
        }
        
        // Запускаем отслеживание местоположения
        locationManager.startUpdatingLocation()
        
        // Запускаем отслеживание движения
        startMotionTracking()
        
        // Запускаем запись аудио
        startAudioRecording()
        
        // Запускаем периодическую запись данных
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordSnapshot()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        locationManager.stopUpdatingLocation()
        stopMotionTracking()
        stopAudioRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.recordedData.endTime = Date()
            LogService.shared.log(.sensors, "Recording session stopped")
        }
    }
    
    private func startMotionTracking() {
        guard let motionManager = motionManager,
              motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            let snapshot = MotionSnapshot(
                timestamp: Date(),
                acceleration: (
                    x: motion.userAcceleration.x,
                    y: motion.userAcceleration.y,
                    z: motion.userAcceleration.z
                ),
                rotation: (
                    x: motion.rotationRate.x,
                    y: motion.rotationRate.y,
                    z: motion.rotationRate.z
                ),
                attitude: (
                    roll: motion.attitude.roll,
                    pitch: motion.attitude.pitch,
                    yaw: motion.attitude.yaw
                )
            )
            
            DispatchQueue.main.async {
                self?.recordedData.motionSnapshots.append(snapshot)
            }
        }
    }
    
    private func stopMotionTracking() {
        motionManager?.stopDeviceMotionUpdates()
    }
    
    private func startAudioRecording() {
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("session_\(Date().timeIntervalSince1970).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            recordedData.audioFilePath = audioFilename.path
        } catch {
            print("Ошибка начала записи аудио: \(error)")
        }
    }
    
    private func stopAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    private func recordSnapshot() {
        let snapshot = DataSnapshot(
            timestamp: Date(),
            location: recordedData.currentLocation,
            audioLevel: getCurrentAudioLevel(),
            proximity: UIDevice.current.proximityState,
            batteryLevel: UIDevice.current.batteryLevel,
            isCharging: UIDevice.current.batteryState == .charging
        )
        
        recordedData.snapshots.append(snapshot)
    }
    
    private func getCurrentAudioLevel() -> Float {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160.0
        return pow(10, (level + 60) / 20)
    }
    
    func addTranscription(_ transcription: SpeechTranscription) {
        recordedData.speechTranscriptions.append(transcription)
    }
    
    func getContextualData() -> [String: Any] {
        var context: [String: Any] = [:]
        
        // Местоположение
        if let location = recordedData.currentLocation {
            context["location"] = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
        }
        
        // Движение
        if let lastMotion = recordedData.motionSnapshots.last {
            let intensity = sqrt(
                pow(lastMotion.acceleration.x, 2) +
                pow(lastMotion.acceleration.y, 2) +
                pow(lastMotion.acceleration.z, 2)
            )
            context["movement_intensity"] = intensity
        }
        
        // Аудио
        if let lastSnapshot = recordedData.snapshots.last {
            context["audio_level"] = lastSnapshot.audioLevel
        }
        
        // Время сессии
        if let startTime = recordedData.startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            context["session_duration"] = elapsed
        }
        
        return context
    }
}

extension DataRecorder: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        recordedData.currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Ошибка получения местоположения: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
}

// Структуры данных
struct SessionData {
    var startTime: Date?
    var endTime: Date?
    var currentLocation: CLLocation?
    var motionSnapshots: [MotionSnapshot] = []
    var snapshots: [DataSnapshot] = []
    var audioFilePath: String?
    var speechTranscriptions: [SpeechTranscription] = []
}

struct MotionSnapshot {
    let timestamp: Date
    let acceleration: (x: Double, y: Double, z: Double)
    let rotation: (x: Double, y: Double, z: Double)
    let attitude: (roll: Double, pitch: Double, yaw: Double)
}

struct DataSnapshot {
    let timestamp: Date
    let location: CLLocation?
    let audioLevel: Float
    let proximity: Bool
    let batteryLevel: Float
    let isCharging: Bool
}

struct SpeechTranscription {
    let timestamp: Date
    let text: String
    let confidence: Float
}

