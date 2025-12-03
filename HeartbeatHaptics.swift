import Foundation
import CoreHaptics
import UIKit

/// Реалистичная вибрация «как пульс» с поддержкой петель и дрожащими темпами.
final class HeartbeatHaptics {
    private let engine: CHHapticEngine
    private let pattern: CHHapticPattern
    private var player: CHHapticAdvancedPatternPlayer?
    private let accessQueue = DispatchQueue(label: "com.hollowsignal.haptics.heartbeat")
    private var loopTimer: DispatchSourceTimer?
    private var isLooping = false
    private let fallbackGenerator = UIImpactFeedbackGenerator(style: .heavy)

    init?() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }

        do {
            engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false

            let events = HeartbeatHaptics.buildPulseEvents()
            pattern = try CHHapticPattern(events: events, parameters: [])

            engine.resetHandler = { [weak self] in
                self?.handleEngineReset()
            }

            try engine.start()
            player = try engine.makeAdvancedPlayer(with: pattern)

            engine.stoppedHandler = { [weak self] _ in
                self?.player = nil
            }
            fallbackGenerator.prepare()
        } catch {
            LogService.shared.log(.haptics, "Heartbeat haptics init failed: \(error.localizedDescription)")
            return nil
        }
    }

    deinit {
        loopTimer?.cancel()
        loopTimer = nil
        engine.stop(completionHandler: nil)
    }

    func playPulse(bpm: Double = 74) {
        accessQueue.async { [weak self] in
            self?.isLooping = false
            self?.loopTimer?.cancel()
            self?.loopTimer = nil
            self?.triggerPulse(targetBPM: bpm)
        }
    }

    func startLoop(bpm: Double = 72) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.isLooping = true
            self.loopTimer?.cancel()

            let timer = DispatchSource.makeTimerSource(queue: self.accessQueue)
            let period = max(0.45, 60.0 / bpm)
            timer.schedule(deadline: .now(), repeating: period)
            timer.setEventHandler { [weak self] in
                let jittered = bpm + Double.random(in: -4...4)
                self?.triggerPulse(targetBPM: max(45, jittered))
            }
            self.loopTimer = timer
            timer.resume()
        }
    }

    func stopLoop() {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.isLooping = false
            self.loopTimer?.cancel()
            self.loopTimer = nil
        }
    }

    private func triggerPulse(targetBPM: Double) {
        do {
            try ensureEngineReady()
            guard let player else {
                fallbackOnMain()
                return
            }

            // Проверяем, запущен ли игрок перед отменой (избегаем ошибки -4805)
            // Сбрасываем предыдущее состояние игрока только если он запущен
            do {
                try player.cancel()
            } catch let cancelError as NSError {
                // Игнорируем ошибку -4805 (игрок не был запущен) - это нормально
                if cancelError.code != -4805 {
                    LogService.shared.log(.haptics, "Player cancel failed: \(cancelError.localizedDescription)")
                }
            }
            
            player.loopEnabled = false
            player.playbackRate = playbackRate(for: targetBPM)

            try player.start(atTime: CHHapticTimeImmediate)
        } catch let error as NSError {
            // Игнорируем ошибку -4805 (игрок не был запущен) - используем fallback
            if error.code == -4805 {
                fallbackOnMain()
            } else {
                // Логируем только серьезные ошибки
                LogService.shared.log(.haptics, "Heartbeat pulse failed: \(error.localizedDescription) (code: \(error.code))")
                fallbackOnMain()
            }
        } catch {
            LogService.shared.log(.haptics, "Heartbeat pulse failed: \(error.localizedDescription)")
            fallbackOnMain()
        }
    }

    private func ensureEngineReady() throws {
        do {
            try engine.start()
        } catch let startError as NSError {
            // Игнорируем ошибку -4805 (движок уже запущен) - это нормально
            if startError.code != -4805 {
                throw startError
            }
        }

        if player == nil {
            do {
                player = try engine.makeAdvancedPlayer(with: pattern)
            } catch {
                // Если не удалось создать игрока, используем fallback
                throw error
            }
        }
    }

    private func handleEngineReset() {
        accessQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.engine.start()
                self.player = try self.engine.makeAdvancedPlayer(with: self.pattern)
            } catch let error as NSError {
                // Игнорируем ошибку -4805 при сбросе движка
                if error.code != -4805 {
                    self.player = nil
                    LogService.shared.log(.haptics, "Heartbeat engine reset failed: \(error.localizedDescription)")
                }
            } catch {
                self.player = nil
                LogService.shared.log(.haptics, "Heartbeat engine reset failed: \(error.localizedDescription)")
            }
        }
    }

    private func fallbackOnMain() {
        DispatchQueue.main.async { [weak self] in
            self?.fallbackGenerator.impactOccurred(intensity: 0.9)
            self?.fallbackGenerator.prepare()
        }
    }

    private func playbackRate(for bpm: Double) -> Float {
        let period = max(0.45, 60.0 / bpm)
        let patternDuration = max(0.2, pattern.duration)
        let baseRate = patternDuration / period
        let jitter = Double.random(in: -0.06...0.06)
        return Float(max(0.35, min(1.6, baseRate * (1.0 + jitter))))
    }

    private static func buildPulseEvents() -> [CHHapticEvent] {
        let primaryHit = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
            ],
            relativeTime: 0
        )

        let secondaryHit = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
            ],
            relativeTime: 0.22,
            duration: 0.11
        )

        let decay = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.02),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0)
            ],
            relativeTime: 0.38,
            duration: 0.32
        )

        return [primaryHit, secondaryHit, decay]
    }
}

