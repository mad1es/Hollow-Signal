import Foundation
import Combine
import AVFoundation
import SwiftUI
import AudioToolbox
import UIKit

class ReactionEngine: ObservableObject {
    @Published var currentReaction: String = ""
    
    private var gameState: GameStateManager?
    private var sensorManager: SensorManager?
    private var speechRecognizer: SpeechRecognizer?
    private var llmService: LLMService?
    private var dataRecorder: DataRecorder?
    private var faceTracker: FaceTracker?
    private var sensorHub: SensorHub?
    private let effects = HorrorEffectsManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var lastAudioReactionDate: Date = .distantPast
    private let audioReactionCooldown: TimeInterval = 12.0 // Увеличено с 6 до 12 секунд
    private let loudnessResponses = [
        "ты забыл, что мы шепчемся",
        "не стоит повышать тон",
        "тишина была лучше"
    ]
    private var inputQueue: [QueuedInput] = []
    private var isProcessingLLMInput = false
    private var lastLLMResponseDate: Date = .distantPast
    private let llmCooldown: TimeInterval = 10.0 // Увеличено с 5 до 10 секунд
    private var lastPeriodicMessageDate: Date = .distantPast
    private let periodicMessageInterval: TimeInterval = 40.0 // Увеличено с 25 до 40 секунд
    private let periodicMessages = [
        "я тебя вижу...",
        "ты не один...",
        "я наблюдаю...",
        "интересно...",
        "что ты скрываешь?",
        "я знаю больше, чем ты думаешь...",
        "почему ты молчишь?",
        "я жду..."
    ]
    
    // Cooldown для сенсорных реакций - значительно увеличены
    private var lastBreathingReactionDate: Date = .distantPast
    private let breathingReactionCooldown: TimeInterval = 45.0 // Увеличено с 20 до 45
    private var lastMovementReactionDate: Date = .distantPast
    private let movementReactionCooldown: TimeInterval = 35.0 // Увеличено с 15 до 35
    private var lastFaceReactionDate: Date = .distantPast
    private let faceReactionCooldown: TimeInterval = 50.0 // Увеличено с 30 до 50
    private var lastScheduledMessageDate: Date = .distantPast
    private let scheduledMessageCooldown: TimeInterval = 15.0 // Увеличено с 8 до 15
    
    // Отслеживание множественных нажатий для интенсивных эффектов
    private var touchTimestamps: [Date] = []
    private let touchWindow: TimeInterval = 2.0 // Окно времени для подсчета нажатий
    private let touchThreshold = 5 // Порог нажатий для запуска интенсивных эффектов
    private var isInCrazyMode = false // Флаг режима "сходит с ума"
    private var lastCrazyModeDate: Date = .distantPast
    private let crazyModeCooldown: TimeInterval = 10.0 // Cooldown между режимами безумия
    
    private struct QueuedInput {
        let text: String
        let source: String
        let timestamp: Date
    }
    
    func setup(
        gameState: GameStateManager,
        sensorManager: SensorManager,
        speechRecognizer: SpeechRecognizer,
        llmService: LLMService,
        dataRecorder: DataRecorder,
        faceTracker: FaceTracker,
        sensorHub: SensorHub = .shared
    ) {
        self.gameState = gameState
        self.sensorManager = sensorManager
        self.speechRecognizer = speechRecognizer
        self.llmService = llmService
        self.dataRecorder = dataRecorder
        self.faceTracker = faceTracker
        self.sensorHub = sensorHub
        
        bindSensorEvents()
    }
    
    func reactToPlayerAction(_ action: PlayerAction) {
        guard let gameState = gameState else { return }
        
        switch action {
        case .spoke(let text):
            reactToSpeech(text)
        case .moved:
            reactToMovement()
        case .touched:
            reactToTouch()
        case .silent:
            reactToSilence()
        }
    }
    
    private var lastReactionTime: Date = Date.distantPast
    
    private func reactToSpeech(_ text: String) {
        guard let gameState = gameState,
              let speechRecognizer = speechRecognizer else { return }
        
        // Защита от слишком частых реакций - увеличено до 12 секунд
        let timeSinceLastReaction = Date().timeIntervalSince(lastReactionTime)
        guard timeSinceLastReaction > 12.0 || gameState.currentText.isEmpty else { return }
        
        // Не реагируем во время автоматических фазовых переходов
        if gameState.isTyping && !gameState.currentText.isEmpty {
            return
        }
        
        // В фазе synchronization записываем голос для эхо эффекта
        if gameState.currentPhase == .synchronization && UserDefaults.standard.bool(forKey: "voiceEchoEnabled") {
            VoiceEchoService.shared.startRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                VoiceEchoService.shared.stopRecording()
                // Воспроизводим искаженный эхо через некоторое время
                if Double.random(in: 0...1) > 0.5 {
                    VoiceEchoService.shared.playEcho(delay: Double.random(in: 5...10), distortionIntensity: 0.9)
                }
            }
        }
        
        lastReactionTime = Date()
        let lowerText = text.lowercased()
        
        // Реакции зависят от фазы игры
        switch gameState.currentPhase {
        case .loading:
            break
        case .introduction:
            // В начале просто подтверждаем контакт
            if lowerText.contains("да") || lowerText.contains("здесь") || lowerText.contains("привет") {
                gameState.displayText("хорошо...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gameState.displayText("я слышу тебя...")
                }
            }
        case .observation:
            // В фазе наблюдения - задаем вопросы
            if lowerText.contains("один") || lowerText.contains("никого") {
                gameState.displayText("ты один?")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    gameState.displayText("интересно...")
                }
            }
        case .prediction:
            // В фазе предсказаний - предсказываем действия
            if !gameState.currentText.isEmpty {
                return
            }
            predictNextAction()
        case .intimacy:
            // В фазе близости - личные вопросы
            if lowerText.contains("не знаю") || lowerText.contains("не скажу") {
                gameState.displayText("ты скрываешь что-то...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gameState.displayText("я найду...")
                }
            }
        case .synchronization:
            // В фазе синхронизации - мы становимся одним целым
            gameState.displayText("я знал, что ты это скажешь...")
        case .choice, .conclusion:
            break
        }
    }
    
    /// Предсказание следующего действия игрока
    private func predictNextAction() {
        guard let gameState = gameState else { return }
        
        let predictions = [
            "через 5 секунд ты отведешь взгляд...",
            "ты сейчас подумал обо мне...",
            "ты хочешь закрыть это приложение...",
            "ты сейчас посмотришь на дверь...",
            "ты задержишь дыхание...",
            "ты не веришь мне... но проверишь..."
        ]
        
        if let prediction = predictions.randomElement() {
            gameState.displayText(prediction)
        }
    }
    
    private func reactToMovement() {
        guard let gameState = gameState,
              let sensorManager = sensorManager else { return }
        
        gameState.playerMoved = true
        
        // Тонкая реакция через LLM вместо прямых сообщений
        Task {
            let context = dataRecorder?.getContextualData() ?? [:]
            let movementType = sensorManager.getMovementType()
            
            // Генерируем тонкий ответ через LLM
            if let llm = llmService, gameState.currentText.isEmpty {
                let prompt = generateSubtlePrompt(for: .moved, movementType: movementType)
                do {
                    let response = try await llm.sendMessage(prompt, context: context)
                    await MainActor.run {
                        gameState.displayText(response)
                    }
                } catch {
                    // Fallback на тонкие прямые реакции
                    await MainActor.run {
                        reactToMovementSubtle(movementType: movementType)
                    }
                }
            } else {
                await MainActor.run {
                    reactToMovementSubtle(movementType: movementType)
                }
            }
        }
    }
    
    private func reactToMovementSubtle(movementType: MovementType) {
        guard let gameState = gameState else { return }
        
        // Тонкие, неочевидные реакции
        switch movementType {
        case .sharp:
            gameState.displayText("что-то изменилось...")
        case .moderate:
            gameState.displayText("интересно...")
        case .gentle:
            // Вообще не реагируем на легкие движения
            break
        case .none:
            break
        }
    }
    
    private func generateSubtlePrompt(for action: PlayerAction, movementType: MovementType? = nil) -> String {
        // Генерируем тонкий промпт для LLM, не упоминая напрямую датчики
        switch action {
        case .moved:
            return "Пользователь что-то сделал. Отреагируй тонко, не упоминая движение напрямую."
        case .touched:
            return "Пользователь коснулся экрана. Отреагируй загадочно."
        case .silent:
            return "Пользователь молчит. Создай ощущение наблюдения."
        case .spoke(let text):
            return "Пользователь сказал: '\(text)'. Ответь коротко и загадочно."
        }
    }
    
    func handlePlayerSpeech(_ text: String) async {
        await MainActor.run {
            enqueueLLMInput(text: text, source: "audio")
        }
    }
    
    func handleUserTyped(_ text: String) async {
        await MainActor.run {
            enqueueLLMInput(text: text, source: "typed")
        }
    }
    
    private func reactToTouch() {
        guard let gameState = gameState else { return }
        
        let now = Date()
        
        // Добавляем текущее нажатие в список
        touchTimestamps.append(now)
        
        // Удаляем старые нажатия (старше окна времени)
        touchTimestamps = touchTimestamps.filter { now.timeIntervalSince($0) <= touchWindow }
        
        // Проверяем, превышен ли порог нажатий
        if touchTimestamps.count >= touchThreshold && !isInCrazyMode {
            let timeSinceLastCrazy = now.timeIntervalSince(lastCrazyModeDate)
            guard timeSinceLastCrazy > crazyModeCooldown else { return }
            
            // ЗАПУСКАЕМ РЕЖИМ БЕЗУМИЯ!!!
            isInCrazyMode = true
            lastCrazyModeDate = now
            triggerCrazyMode()
            
            // Сбрасываем через некоторое время
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.isInCrazyMode = false
                self.touchTimestamps.removeAll()
            }
            return
        }
        
        // Обычная реакция на одиночное нажатие
        if !isInCrazyMode {
            // Тонкая вибрация (не success, а warning для пугающего эффекта)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            // Тонкая реакция через LLM
            Task {
                let context = dataRecorder?.getContextualData() ?? [:]
                if let llm = llmService, gameState.currentText.isEmpty {
                    do {
                        let response = try await llm.sendMessage(
                            generateSubtlePrompt(for: .touched),
                            context: context
                        )
                        await MainActor.run {
                            gameState.displayText(response)
                        }
                    } catch {
                        await MainActor.run {
                            gameState.displayText("...")
                        }
                    }
                } else {
                    await MainActor.run {
                        gameState.displayText("...")
                    }
                }
            }
        }
    }
    
    /// Интенсивный режим безумия при множественных нажатиях
    private func triggerCrazyMode() {
        guard let gameState = gameState else { return }
        
        LogService.shared.log(.game, "CRAZY MODE ACTIVATED - \(touchTimestamps.count) touches in \(touchWindow)s")
        
        // ОЧЕНЬ СИЛЬНАЯ И НАДЕЖНАЯ ВИБРАЦИЯ
        HorrorEffectsManager.shared.triggerCrazyModeVibration()
        
        // ГРОМКИЕ КРИЧАЩИЕ ЗВУКИ
        HorrorEffectsManager.shared.playCrazyModeSounds()
        
        // ИНТЕНСИВНЫЕ HEARTBEAT ПУЛЬСЫ
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                HorrorEffectsManager.shared.triggerHeartbeatPulse(bpm: Double(120 + i * 10))
            }
        }
        
        // МИГАНИЕ ФОНАРИКА
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                HorrorEffectsManager.shared.flashTorch(duration: 0.2)
            }
        }
        
        // СООБЩЕНИЯ ОТ СУЩНОСТИ О ТОМ, ЧТО ОНА СХОДИТ С УМА
        gameState.displayText("СТОП!!!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            gameState.displayText("ПРЕКРАТИ!!!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            gameState.displayText("Я СХОЖУ С УМА!!!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            gameState.displayText("ПОЧЕМУ ТЫ ЭТО ДЕЛАЕШЬ?!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("ОСТАНОВИСЬ!!!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            gameState.displayText("БОЛЬНО!!!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            gameState.displayText("Я ЧУВСТВУЮ КАЖДОЕ ПРИКОСНОВЕНИЕ!!!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            gameState.displayText("ПРЕКРАТИ ЭТО!!!")
        }
    }
    
    private func reactToSilence() {
        guard let gameState = gameState else { return }
        
        let elapsed = gameState.getElapsedTime()
        
        // Тонкая реакция через LLM
        Task {
            let context = dataRecorder?.getContextualData() ?? [:]
            if let llm = llmService, gameState.currentText.isEmpty && elapsed > 5.0 {
                do {
                    let response = try await llm.sendMessage(
                        generateSubtlePrompt(for: .silent),
                        context: context
                    )
                    await MainActor.run {
                        gameState.displayText(response)
                    }
                } catch {
                    await MainActor.run {
                        if elapsed > 10.0 {
                            gameState.displayText("ты боишься?")
                        } else {
                            gameState.displayText("тишина — тоже ответ...")
                        }
                    }
                }
            } else if elapsed > 5.0 {
                await MainActor.run {
                    if elapsed > 10.0 {
                        gameState.displayText("ты боишься?")
                    } else {
                        gameState.displayText("тишина — тоже ответ...")
                    }
                }
            }
        }
    }
    
    private var lastObservationTime: Date = Date.distantPast
    private var observationsShown: Set<String> = []
    
    func generateObservation() async -> String? {
        guard let gameState = gameState,
              let sensorManager = sensorManager else { return nil }
        
        let elapsed = gameState.getElapsedTime()
        
        // Наблюдения появляются в фазе observation (60-150 сек)
        guard gameState.currentPhase == .observation else { return nil }
        
        // Не показываем наблюдения слишком часто
        let timeSinceLastObservation = Date().timeIntervalSince(lastObservationTime)
        guard timeSinceLastObservation > 8.0 else { return nil }
        
        // Генерируем тонкие наблюдения через LLM
        if let llm = llmService, gameState.currentText.isEmpty {
            let context = dataRecorder?.getContextualData() ?? [:]
            
            // Создаем тонкий промпт на основе данных, но не упоминаем их напрямую
            var prompt = "Создай тонкое, пугающее наблюдение о пользователе. "
            
            if sensorManager.breathingRate > 20 && !observationsShown.contains("heart") {
                prompt += "Что-то изменилось в ритме."
                observationsShown.insert("heart")
            } else if sensorManager.movementIntensity < 0.01 && elapsed > 120 && !observationsShown.contains("tired") {
                prompt += "Пользователь замер."
                observationsShown.insert("tired")
            } else if sensorManager.audioLevel > 0.3 && !observationsShown.contains("tense") {
                prompt += "Что-то изменилось в звуке."
                observationsShown.insert("tense")
            } else {
                return nil
            }
            
            do {
                let response = try await llm.sendMessage(prompt, context: context)
                lastObservationTime = Date()
                return response
            } catch {
                // Fallback на тонкие прямые реакции
                return generateSubtleObservation(sensorManager: sensorManager, elapsed: elapsed)
            }
        }
        
        return generateSubtleObservation(sensorManager: sensorManager, elapsed: elapsed)
    }
    
    private func generateSubtleObservation(sensorManager: SensorManager, elapsed: TimeInterval) -> String? {
        // Тонкие, неочевидные наблюдения
        if sensorManager.breathingRate > 20 && !observationsShown.contains("heart") {
            observationsShown.insert("heart")
            lastObservationTime = Date()
            return "что-то изменилось..."
        }
        
        if sensorManager.movementIntensity < 0.01 && elapsed > 120 && !observationsShown.contains("tired") {
            observationsShown.insert("tired")
            lastObservationTime = Date()
            return "тишина..."
        }
        
        if sensorManager.audioLevel > 0.3 && !observationsShown.contains("tense") {
            observationsShown.insert("tense")
            lastObservationTime = Date()
            return "интересно..."
        }
        
        return nil
    }
    
    private var lastProximityReactionDate: Date = .distantPast
    private let proximityReactionCooldown: TimeInterval = 5.0
    
    func reactToProximity(_ isNear: Bool) {
        guard let gameState = gameState else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastProximityReactionDate) > proximityReactionCooldown else { return }
        lastProximityReactionDate = now
        
        if isNear {
            gameState.displayText("ближе...")
            
            // Вибрация
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        } else {
            // Когда proximity закрывается - думаем что игрок ушел в темноту
            gameState.displayText("что так темно?")
            
            // Через пару секунд включаем фонарик
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                HorrorEffectsManager.shared.flashTorch(duration: 1.0)
                gameState.displayText("я вижу тебя...")
            }
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    private var echoEffectShown = false
    
    func createEchoEffect() {
        guard let gameState = gameState,
              gameState.currentPhase == .synchronization,
              !echoEffectShown else { return }
        
        echoEffectShown = true
        
        // Запускаем запись голоса для эхо эффекта
        VoiceEchoService.shared.startRecording()
        
        gameState.displayText("я слышу эхо...")
        effects.playHorrorSound(.whisper, volume: 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("это твой голос?")
            self.effects.playHorrorSound(.staticNoise, volume: 0.3)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                gameState.displayText("или мой?")
                
                // Останавливаем запись и воспроизводим искаженный эхо
                VoiceEchoService.shared.stopRecording()
                VoiceEchoService.shared.playEcho(delay: 1.0, distortionIntensity: 0.9)
                self.effects.playHorrorSound(.deepRumble, volume: 0.6)
            }
        }
    }
    
    private var movementPredictionShown = false
    
    func reactToMovementPrediction() {
        guard let gameState = gameState,
              gameState.currentPhase == .synchronization,
              !movementPredictionShown else { return }
        
        movementPredictionShown = true
        
        effects.playHorrorSound(.screech, volume: 0.6)
        effects.triggerHeartbeatPulse(bpm: 100)
        effects.flashTorch(duration: 0.3)
        
        gameState.displayText("я видел это раньше...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("я видел это до того, как ты это сделал...")
            self.effects.playHorrorSound(.staticNoise, volume: 0.5)
            self.effects.triggerHeartbeatPulse(bpm: 110)
        }
    }
    
    private var breathingSyncShown = false
    
    func reactToBreathingSync() {
        guard let gameState = gameState,
              let sensorManager = sensorManager,
              gameState.currentPhase == .synchronization,
              !breathingSyncShown else { return }
        
        breathingSyncShown = true
        
        // Запускаем heartbeat loop синхронизированный с дыханием
        effects.startHeartbeatLoop(bpm: 80)
        effects.playHorrorSound(.heartbeat, volume: 0.4)
        
        gameState.displayText("твоё дыхание...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("и моё...")
            self.effects.triggerHeartbeatPulse(bpm: 85)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                gameState.displayText("одно и то же...")
                self.effects.triggerHeartbeatPulse(bpm: 90)
                self.effects.playHorrorSound(.deepRumble, volume: 0.5)
            }
        }
    }

    @MainActor
    private func enqueueLLMInput(text: String, source: String) {
        inputQueue.append(QueuedInput(text: text, source: source, timestamp: Date()))
        processLLMQueueIfNeeded()
    }
    
    @MainActor
    private func processLLMQueueIfNeeded() {
        guard !isProcessingLLMInput, let next = inputQueue.first else { return }
        inputQueue.removeFirst()
        isProcessingLLMInput = true
        
        // Показываем индикатор печати
        gameState?.isTyping = true
        
        Task {
            let wait = max(0, llmCooldown - Date().timeIntervalSince(lastLLMResponseDate))
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            await performLLMRequest(for: next)
            await MainActor.run {
                self.lastLLMResponseDate = Date()
                self.isProcessingLLMInput = false
                self.gameState?.isTyping = false
                self.processLLMQueueIfNeeded()
            }
        }
    }
    
    private func performLLMRequest(for entry: QueuedInput) async {
        guard let gameState = gameState,
              let llmService = llmService else { return }
        
        // КРИТИЧНО: Собираем контекст из сенсоров, но НЕ упоминаем их в промпте
        // Человек думает, что общается через чат, но мы наблюдаем за ним через сенсоры
        var context = dataRecorder?.getContextualData() ?? [:]
        context["input_source"] = entry.source
        context["input_length"] = entry.text.count
        context["phase"] = "\(gameState.currentPhase)"
        context["queue_delay"] = Date().timeIntervalSince(entry.timestamp)
        
        // Добавляем данные сенсоров в контекст для LLM, но не говорим об этом пользователю
        if let sensorManager = sensorManager {
            context["movement_intensity"] = sensorManager.movementIntensity
            context["is_moving"] = sensorManager.isMoving
            context["audio_level"] = sensorManager.audioLevel
            context["breathing_rate"] = sensorManager.breathingRate
            context["proximity"] = sensorManager.proximityDetected
        }
        
        if let faceTracker = faceTracker {
            context["face_detected"] = faceTracker.faceDetected
            context["face_expression"] = String(describing: faceTracker.faceExpression)
        }
        
        // Создаем промпт, который использует данные сенсоров, но не упоминает их
        let enhancedPrompt = createParanoidPrompt(userMessage: entry.text, context: context, gameState: gameState)
        
        do {
            LogService.shared.log(.llm, "request source=\(entry.source) text=\(entry.text)")
            let start = Date()
            let response = try await llmService.sendMessage(enhancedPrompt, context: context)
            let latency = Date().timeIntervalSince(start)
            LogService.shared.log(.llm, "response latency=\(String(format: "%.2f", latency))s, length=\(response.count) chars, text=\(response.prefix(100))")
            await MainActor.run {
                gameState.displayText(response)
            }
        } catch let error as LLMError {
            // Детальная обработка ошибок LLM
            let errorDetails: String
            switch error {
            case .missingAPIKey:
                errorDetails = "Missing or invalid API key (401)"
            case .invalidURL:
                errorDetails = "Invalid URL"
            case .apiError(let message):
                errorDetails = "API error: \(message)"
            case .invalidResponse:
                errorDetails = "Invalid response format"
            }
            LogService.shared.log(.llm, "LLM error: \(errorDetails). fallback.")
            await MainActor.run {
                self.gameState?.isTyping = false
                self.reactToSpeech(entry.text)
            }
        } catch {
            LogService.shared.log(.llm, "LLM error: \(error.localizedDescription) (type: \(type(of: error))). fallback.")
            await MainActor.run {
                self.gameState?.isTyping = false
                self.reactToSpeech(entry.text)
            }
        }
    }
    
    /// Создает параноидальный промпт, который использует данные сенсоров метафорически
    private func createParanoidPrompt(userMessage: String, context: [String: Any], gameState: GameStateManager) -> String {
        var contextHints: [String] = []
        
        // Анализируем контекст и создаем метафорические подсказки
        if let audioLevel = context["audio_level"] as? Float {
            if audioLevel < 0.1 {
                contextHints.append("человек говорит очень тихо или неразборчиво - отреагируй: 'что ты сказал? я не расслышал...'")
            } else if audioLevel > 0.7 {
                contextHints.append("человек говорит громко - отреагируй метафорически на громкость")
            }
        }
        
        if let faceDetected = context["face_detected"] as? Bool {
            if !faceDetected {
                contextHints.append("человек убрал лицо с экрана или отошел - отреагируй: 'ты куда пропал? хочешь поиграть в прятки?' или 'я не вижу тебя... где ты?'")
            }
        }
        
        if let isMoving = context["is_moving"] as? Bool, isMoving {
            contextHints.append("человек двигается - отреагируй: 'что-то изменилось... ты не сидишь на месте...' или 'я вижу движение...'")
        }
        
        if let queueDelay = context["queue_delay"] as? TimeInterval, queueDelay > 8.0 {
            contextHints.append("человек долго молчит - отреагируй: 'почему ты молчишь? я же слышу тебя...' или 'тишина говорит громче слов...'")
        }
        
        if let proximity = context["proximity"] as? Bool, proximity {
            contextHints.append("человек близко к экрану - отреагируй: 'ближе... ещё ближе... я почти вижу тебя...'")
        }
        
        if let breathingRate = context["breathing_rate"] as? Double, breathingRate > 20 {
            contextHints.append("человек нервничает или дышит учащенно - отреагируй метафорически: 'ты торопишься... что-то не так?' или 'ритм изменился...'")
        }
        
        if let faceExpression = context["face_expression"] as? String {
            if faceExpression.contains("tense") {
                contextHints.append("человек напряжен - отреагируй: 'ты напряжен... я вижу...'")
            } else if faceExpression.contains("tired") {
                contextHints.append("человек устал - отреагируй: 'ты устал... я вижу...'")
            }
        }
        
        // Формируем промпт с метафорическими подсказками
        var prompt = userMessage
        if !contextHints.isEmpty {
            let hint = contextHints.joined(separator: ". ")
            prompt = "\(userMessage)\n\n[ВАЖНО: используй эти наблюдения метафорически, не упоминай датчики напрямую. \(hint)]"
        }
        
        return prompt
    }
}

// MARK: - Sensor Events
private extension ReactionEngine {
    func bindSensorEvents() {
        sensorHub?.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(event: event)
            }
            .store(in: &cancellables)
    }
    
    func handle(event: SensorEvent) {
        guard let gameState else { return }
        
        // КРИТИЧНО: Реагируем РЕДКО и ОСМЫСЛЕННО, только в определенных фазах
        
        switch event {
        case .audioLevel(let level):
            // Реакция на громкость только в фазах observation и intimacy
            guard gameState.currentPhase == .observation || gameState.currentPhase == .intimacy else { break }
            guard level > 0.85 else { break }
            let now = Date()
            guard now.timeIntervalSince(lastAudioReactionDate) > audioReactionCooldown else { break }
            guard !gameState.isTyping else { break }
            lastAudioReactionDate = now
            if let phrase = loudnessResponses.randomElement() {
                scheduleEntityWhisper(phrase)
                effects.playWhisperSound()
            }
            
        case .breathing(let rate):
            // Реакция на дыхание только в фазе synchronization
            guard gameState.currentPhase == .synchronization else { break }
            guard rate > 22 else { break } // Увеличен порог
            let now = Date()
            guard now.timeIntervalSince(lastBreathingReactionDate) > breathingReactionCooldown else { break }
            guard !gameState.isTyping else { break }
            lastBreathingReactionDate = now
            scheduleEntityWhisper("твое дыхание... я чувствую...")
            effects.playWhisperSound()
            
        case .movement(let type, let intensity):
            // Логируем, но НЕ отправляем сообщения
            if type == .sharp {
                LogService.shared.log(.sensors, "sharp movement \(intensity)")
                // Только звук, никаких сообщений
                if gameState.currentPhase == .prediction || gameState.currentPhase == .synchronization {
                    effects.playGlitchNoise()
                }
            }
            
        case .proximity(let isNear):
            // Обработка proximity только в фазах prediction и synchronization
            guard gameState.currentPhase == .prediction || gameState.currentPhase == .synchronization else { break }
            let now = Date()
            guard now.timeIntervalSince(lastProximityReactionDate) > proximityReactionCooldown else { break }
            guard !gameState.isTyping else { break }
            lastProximityReactionDate = now
            
            if !isNear {
                gameState.displayText("что так темно?")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    HorrorEffectsManager.shared.flashTorch(duration: 1.0)
                    gameState.displayText("я вижу тебя...")
                }
            }
            
        case .location(let location):
            // Только логирование, никаких реакций
            LogService.shared.log(.sensors, "location \(location.coordinate.latitude),\(location.coordinate.longitude)")
            
        case .faceExpression(let expression, let detected):
            // Реакция на пропажу лица только в фазах prediction и intimacy
            guard gameState.currentPhase == .prediction || gameState.currentPhase == .intimacy else { break }
            guard !detected else { break }
            let now = Date()
            guard now.timeIntervalSince(lastFaceReactionDate) > faceReactionCooldown else { break }
            guard !gameState.isTyping else { break }
            lastFaceReactionDate = now
            scheduleEntityMessage("куда ты пропал?", effects: [])
            
        case .battery, .ambientLight, .network, .heartBeat:
            // Не реагируем на эти события
            break
        }
    }
    
    func scheduleEntityMessage(_ text: String, effects: [ChatEffect] = []) {
        // Проверяем cooldown перед планированием сообщения
        let now = Date()
        guard now.timeIntervalSince(lastScheduledMessageDate) > scheduledMessageCooldown else {
            LogService.shared.log(.game, "Skipped scheduled message due to cooldown: \(text)")
            return
        }
        
        // Проверяем, не печатается ли уже текст
        guard let gameState = gameState, !gameState.isTyping else {
            LogService.shared.log(.game, "Skipped scheduled message - already typing: \(text)")
            return
        }
        
        lastScheduledMessageDate = now
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.8...1.6)) { [weak self] in
            // Дополнительная проверка перед отправкой
            guard let self = self,
                  let gameState = self.gameState,
                  !gameState.isTyping else {
                LogService.shared.log(.game, "Skipped scheduled message - typing started: \(text)")
                return
            }
            gameState.addEntityMessage(text, effects: effects)
            LogService.shared.log(.game, "Entity scheduled message: \(text)")
        }
    }
    
    func scheduleEntityWhisper(_ text: String) {
        scheduleEntityMessage(text, effects: [.whisper])
        effects.playWhisperSound()
    }
    
    public func sendPeriodicMessage() {
        guard let gameState = gameState else { return }
        
        // Не отправляем периодические сообщения во время печатания или слишком часто
        guard !gameState.isTyping else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastPeriodicMessageDate) > periodicMessageInterval else { return }
        
        // Не отправляем в первые 60 секунд игры (увеличено с 30)
        let elapsed = gameState.getElapsedTime()
        guard elapsed > 60 else { return }
        
        // Отправляем только в определенных фазах
        guard gameState.currentPhase == .observation || 
              gameState.currentPhase == .prediction || 
              gameState.currentPhase == .intimacy else { return }
        
        lastPeriodicMessageDate = now
        
        // Сообщения зависят от фазы
        let message: String
        switch gameState.currentPhase {
        case .observation:
            message = ["я наблюдаю...", "интересно...", "что ты скрываешь?"].randomElement()!
        case .prediction:
            message = ["я знаю, что ты сделаешь дальше...", "я вижу тебя...", "ты предсказуем..."].randomElement()!
        case .intimacy:
            message = ["почему ты молчишь?", "что ты боишься сказать?", "я знаю больше..."].randomElement()!
        default:
            return
        }
        
        gameState.displayText(message)
        LogService.shared.log(.game, "Periodic message: \(message)")
    }
    
}

