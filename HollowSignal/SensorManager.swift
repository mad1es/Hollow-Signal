import Foundation
import CoreMotion
import AVFoundation
import UIKit

class SensorManager: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var isMoving: Bool = false
    @Published var movementIntensity: Double = 0.0
    @Published var proximityDetected: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var breathingRate: Double = 0.0
    
    private var lastMovementTime: Date = Date()
    private var movementHistory: [Double] = []
    private var audioLevelHistory: [Float] = []
    
    // Метод для обновления аудио данных из SpeechRecognizer
    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.audioLevel = level
            self.audioLevelHistory.append(level)
            if self.audioLevelHistory.count > 50 {
                self.audioLevelHistory.removeFirst()
                self.analyzeBreathing()
            }
        }
    }
    
    override init() {
        super.init()
        setupMotionManager()
        setupProximitySensor()
    }
    
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            let acceleration = sqrt(
                pow(motion.userAcceleration.x, 2) +
                pow(motion.userAcceleration.y, 2) +
                pow(motion.userAcceleration.z, 2)
            )
            
            DispatchQueue.main.async {
                self?.movementIntensity = acceleration
                self?.movementHistory.append(acceleration)
                
                if self?.movementHistory.count ?? 0 > 10 {
                    self?.movementHistory.removeFirst()
                }
                
                // Определяем движение
                if acceleration > 0.1 {
                    self?.isMoving = true
                    self?.lastMovementTime = Date()
                } else if Date().timeIntervalSince(self?.lastMovementTime ?? Date()) > 0.5 {
                    self?.isMoving = false
                }
            }
        }
    }
    
    private func setupProximitySensor() {
        UIDevice.current.isProximityMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(proximityChanged),
            name: UIDevice.proximityStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func proximityChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.proximityDetected = UIDevice.current.proximityState
        }
    }
    
    private func analyzeBreathing() {
        guard audioLevelHistory.count >= 20 else { return }
        
        // Простой анализ частоты дыхания через пики в аудио
        var peaks = 0
        var lastValue: Float = 0
        var isRising = false
        
        for value in audioLevelHistory {
            if value > lastValue && !isRising {
                isRising = true
            } else if value < lastValue && isRising {
                peaks += 1
                isRising = false
            }
            lastValue = value
        }
        
        // Примерно 2 пика = 1 вдох-выдох
        let rate = Double(peaks) / 2.0 / 5.0 // За 5 секунд
        DispatchQueue.main.async { [weak self] in
            self?.breathingRate = rate
        }
    }
    
    func getMovementType() -> MovementType {
        guard movementHistory.count >= 5 else { return .none }
        
        let avg = movementHistory.reduce(0, +) / Double(movementHistory.count)
        let max = movementHistory.max() ?? 0
        
        if max > 0.5 {
            return .sharp
        } else if avg > 0.2 {
            return .moderate
        } else if avg > 0.05 {
            return .gentle
        }
        
        return .none
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
        UIDevice.current.isProximityMonitoringEnabled = false
    }
}

enum MovementType {
    case none
    case gentle
    case moderate
    case sharp
}

