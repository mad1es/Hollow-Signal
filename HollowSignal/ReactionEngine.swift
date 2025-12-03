import Foundation
import Combine
import AVFoundation
import SwiftUI

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
    private let audioReactionCooldown: TimeInterval = 6.0
    private let loudnessResponses = [
        "ты забыл, что мы шепчемся",
        "порог снова горит",
        "не стоит повышать тон",
        "тебе не понравится, если я отвечу так же громко",
        "тишина была лучше"
    ]
    private var inputQueue: [QueuedInput] = []
    private var isProcessingLLMInput = false
    private var lastLLMResponseDate: Date = .distantPast
    private let llmCooldown: TimeInterval = 5.0
    
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
        
        // Защита от слишком частых реакций
        let timeSinceLastReaction = Date().timeIntervalSince(lastReactionTime)
        guard timeSinceLastReaction > 2.0 || gameState.currentText.isEmpty else { return }
        
        // Не реагируем во время автоматических фазовых переходов
        if gameState.isTyping && !gameState.currentText.isEmpty {
            return
        }
        
        lastReactionTime = Date()
        let lowerText = text.lowercased()
        
        // Реакции на конкретные слова (только в соответствующих фазах)
        if gameState.currentPhase == .initialContact || gameState.currentPhase == .establishingContact {
            if lowerText.contains("да") || lowerText.contains("здесь") || lowerText.contains("да, я здесь") {
                gameState.displayText("хорошо...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    gameState.displayText("я слышу тебя...")
                }
                return
            } else if lowerText.contains("нет") {
                gameState.displayText("...нет?")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    gameState.displayText("ты уверен?")
                }
                return
            }
        }
        
        // Реакция на "один" в фазе firstTask
        if gameState.currentPhase == .firstTask {
            if lowerText.contains("один") || lowerText.contains("никого") {
                gameState.playerSaidAlone = true
                gameState.displayText("ты... один?")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gameState.displayText("ты уверен?")
                }
                return
            }
        }
        
        // Общие реакции на речь (только если нет активного текста)
        if gameState.currentText.isEmpty {
            let emotion = speechRecognizer.analyzeSpeechEmotion()
            
            switch emotion {
            case .quiet:
                // Реакция на тихую речь - метафорически
                gameState.displayText("что ты сказал? я не расслышал...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gameState.displayText("говори громче... я же слышу тебя...")
                }
            case .loud:
                gameState.displayText("слышу тебя...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    gameState.displayText("не нужно кричать... я же здесь...")
                }
            case .nervous:
                if gameState.currentPhase == .observations {
                    gameState.displayText("ты торопишься... что-то не так?")
                }
            case .tired:
                if gameState.currentPhase == .observations {
                    gameState.displayText("ты устал... я вижу...")
                }
            case .afraid:
                gameState.displayText("ты боишься?")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gameState.displayText("не бойся... я же здесь...")
                }
            case .angry:
                gameState.displayText("ты злишься?")
            case .neutral:
                if gameState.currentPhase == .establishingContact {
                    gameState.displayText("спасибо...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        gameState.displayText("твой голос... знакомый...")
                    }
                }
            }
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
        
        // Наблюдения появляются в фазе observations (1:30 - 3:00)
        guard gameState.currentPhase == .observations else { return nil }
        
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
    
    func reactToProximity(_ isNear: Bool) {
        guard let gameState = gameState else { return }
        
        if isNear {
            gameState.displayText("ближе...")
            
            // Вибрация
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                gameState.displayText("ещё ближе...")
            }
        } else {
            gameState.displayText("не уходи...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                gameState.displayText("мне нужно видеть тебя...")
            }
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    private var echoEffectShown = false
    
    func createEchoEffect() {
        guard let gameState = gameState,
              gameState.currentPhase == .anomalies,
              !echoEffectShown else { return }
        
        echoEffectShown = true
        
        // В реальной реализации здесь бы записывался голос и воспроизводился с задержкой
        // Для MVP просто показываем реакцию
        gameState.displayText("я слышу эхо...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("это твой голос?")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                gameState.displayText("или мой?")
            }
        }
    }
    
    private var movementPredictionShown = false
    
    func reactToMovementPrediction() {
        guard let gameState = gameState,
              gameState.currentPhase == .anomalies,
              !movementPredictionShown else { return }
        
        movementPredictionShown = true
        
        gameState.displayText("я видел это раньше...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("я видел это до того, как ты это сделал...")
        }
    }
    
    private var breathingSyncShown = false
    
    func reactToBreathingSync() {
        guard let gameState = gameState,
              let sensorManager = sensorManager,
              gameState.currentPhase == .anomalies,
              !breathingSyncShown else { return }
        
        breathingSyncShown = true
        
        gameState.displayText("твоё дыхание...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameState.displayText("и моё...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                gameState.displayText("одно и то же...")
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
        switch event {
        case .audioLevel(let level):
            guard level > 0.85 else { break }
            let now = Date()
            guard now.timeIntervalSince(lastAudioReactionDate) > audioReactionCooldown else { break }
            lastAudioReactionDate = now
            if let phrase = loudnessResponses.randomElement() {
                scheduleEntityWhisper(phrase)
                effects.playWhisperSound()
            }
        case .breathing(let rate):
            if rate > 18 {
                scheduleEntityWhisper("я слышу, как ты торопишь вдох")
                effects.playWhisperSound()
            }
        case .movement(let type, let intensity):
            if type == .sharp {
                LogService.shared.log(.sensors, "sharp movement \(intensity)")
                effects.playGlitchNoise()
            }
        case .proximity(let isNear):
            if isNear {
                scheduleEntityMessage("не отводи экран", effects: [.whisper])
                effects.flashTorch()
            }
        case .location(let location):
            LogService.shared.log(.sensors, "location \(location.coordinate.latitude),\(location.coordinate.longitude)")
        case .faceExpression(let expression, let detected):
            guard let gameState = self.gameState else { return }
            // Реакция на то, что лицо пропало
            if !detected && gameState.currentPhase.rawValue >= GamePhase.establishingContact.rawValue {
                scheduleEntityMessage("ты куда пропал? хочешь поиграть в прятки?", effects: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    gameState.displayText("я не вижу тебя... где ты?")
                }
            }
        case .battery, .ambientLight, .network:
            break
        case .heartBeat:
            effects.triggerHeartbeatPulse()
        }
    }
    
    func scheduleEntityMessage(_ text: String, effects: [ChatEffect] = []) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.8...1.6)) { [weak self] in
            self?.gameState?.addEntityMessage(text, effects: effects)
            LogService.shared.log(.game, "Entity scheduled message: \(text)")
        }
    }
    
    func scheduleEntityWhisper(_ text: String) {
        scheduleEntityMessage(text, effects: [.whisper])
        effects.playWhisperSound()
    }
    
}

