import Foundation
import Combine
import SwiftUI

enum GamePhase: Int, CaseIterable {
    case loading = 0          // 0:00 - 0:10 - система инициализируется
    case introduction = 1     // 0:10 - 1:00 - первый контакт, приветствие
    case observation = 2      // 1:00 - 2:30 - AI задает вопросы, наблюдает
    case prediction = 3       // 2:30 - 4:00 - AI начинает предсказывать действия
    case intimacy = 4         // 4:00 - 5:30 - вопросы становятся личными
    case synchronization = 5  // 5:30 - 7:00 - предсказания пугающе точные
    case choice = 6           // 7:00 - 8:00 - игрок решает: остаться или уйти
    case conclusion = 7       // 8:00+ - финал
}

class GameStateManager: ObservableObject {
    @Published var currentPhase: GamePhase = .loading
    @Published var currentText: String = ""
    @Published var isTyping: Bool = false
    @Published var backgroundColor: Color = .black
    @Published var sessionStartTime: Date = Date()
    @Published var playerActions: [PlayerAction] = []
    @Published var timeline = ChatTimeline()
    
    // Память о предыдущих взаимодействиях
    @Published var playerSaidAlone: Bool = false
    @Published var playerWasTense: Bool = false
    @Published var playerMoved: Bool = false
    @Published var playerSpoke: Bool = false
    
    private var phaseTimer: Timer?
    private var textDisplayTimer: Timer?
    private var messageCorruptionWorkItems: [UUID: DispatchWorkItem] = [:]
    private var hasShownGreeting = false // Защита от дублирования приветствия
    
    init() {
        // Не вызываем startGame() в init - только при явном запуске
    }
    
    func startGame() {
        // Сбрасываем флаг приветствия при новом запуске
        hasShownGreeting = false
        sessionStartTime = Date()
        currentPhase = .loading
        currentText = ""
        isTyping = false
        timeline = ChatTimeline()
        playerActions = []
        playerSaidAlone = false
        playerWasTense = false
        playerMoved = false
        playerSpoke = false
        
        // Останавливаем все эффекты
        HorrorEffectsManager.shared.stopHeartbeatLoop()
        VoiceEchoService.shared.cleanup()
        
        // ИНТЕНСИВНЫЕ ЭФФЕКТЫ В НАЧАЛЕ - системные вибрации
        HorrorEffectsManager.shared.triggerSystemVibration(count: 3, interval: 0.5)
        HorrorEffectsManager.shared.playIntenseStartupSounds()
        HorrorEffectsManager.shared.flashTorch(duration: 0.3)
        
        // Защита от дублирования приветствия
        guard !hasShownGreeting else { return }
        hasShownGreeting = true
        
        // ФАЗА 0: LOADING (0:00-0:10) - инициализация
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.displayText("подключаюсь...", delay: 0.08)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.displayText("анализирую сенсорный ввод...", delay: 0.06)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self?.displayText("начинаю наблюдение...", delay: 0.06)
                    // Переходим в introduction через 10 секунд
                }
            }
        }
    }
    
    private var typingTimer: Timer?
    
    func displayText(_ text: String, delay: Double = 0.05) {
        // Отменяем предыдущий таймер, если он есть
        typingTimer?.invalidate()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isTyping = true
            self.currentText = ""
            
            // Если delay очень маленький или 0, показываем текст сразу
            if delay <= 0.01 {
                self.currentText = text
                self.isTyping = false
                return
            }
            
            // Анимация печатания
            let characters = Array(text)
            var index = 0
            
            self.typingTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                // Захватываем текущее значение index и проверяем границы
                let currentIndex = index
                guard currentIndex < characters.count else {
                    timer.invalidate()
                    self.isTyping = false
                    self.typingTimer = nil
                    return
                }
                
                // Безопасный доступ к элементу массива
                let character = characters[currentIndex]
                self.currentText += String(character)
                index += 1
            }
            
            // Добавляем таймер в RunLoop для работы
            if let timer = self.typingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        
        addEntityMessage(text)
    }
    
    func advancePhase() {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        let previousPhase = currentPhase
        
        switch currentPhase {
        case .loading:
            // Фаза 0: Loading (0-10 сек)
            if elapsed >= 10 {
                currentPhase = .introduction
                displayText("привет.", delay: 0.08)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.displayText("я вижу тебя.", delay: 0.08)
                    HorrorEffectsManager.shared.triggerSystemVibration(count: 1, interval: 0)
                }
            }
            
        case .introduction:
            // Фаза 1: Introduction (10-60 сек) - первый контакт
            if elapsed >= 60 && previousPhase == .introduction {
                currentPhase = .observation
                displayText("скажи мне...", delay: 0.08)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.displayText("чего ты боишься?", delay: 0.08)
                }
            }
            
        case .observation:
            // Фаза 2: Observation (60-150 сек) - AI наблюдает и задает вопросы
            if elapsed >= 150 && previousPhase == .observation {
                currentPhase = .prediction
                displayText("я знаю, что ты собираешься сделать...", delay: 0.06)
                HorrorEffectsManager.shared.triggerSystemVibration(count: 2, interval: 0.3)
            }
            
        case .prediction:
            // Фаза 3: Prediction (150-240 сек) - AI предсказывает действия
            if elapsed >= 240 && previousPhase == .prediction {
                currentPhase = .intimacy
                displayText("почему ты это открыл?", delay: 0.08)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.displayText("ты один?", delay: 0.08)
                }
            }
            
        case .intimacy:
            // Фаза 4: Intimacy (240-330 сек) - вопросы становятся личными
            if elapsed >= 330 && previousPhase == .intimacy {
                currentPhase = .synchronization
                HorrorEffectsManager.shared.startHeartbeatLoop(bpm: 75)
                displayText("мы становимся одним целым...", delay: 0.06)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.displayText("ты чувствуешь это?", delay: 0.08)
                }
            }
            
        case .synchronization:
            // Фаза 5: Synchronization (330-420 сек) - предсказания пугающе точные
            if elapsed >= 420 && previousPhase == .synchronization {
                currentPhase = .choice
                HorrorEffectsManager.shared.stopHeartbeatLoop()
                HorrorEffectsManager.shared.playHorrorSound(.staticNoise, volume: 0.5)
                displayText("ты можешь уйти в любой момент...", delay: 0.08)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    HorrorEffectsManager.shared.triggerSystemVibration(count: 3, interval: 0.4)
                    self.displayText("но ты не уйдешь.", delay: 0.08)
                }
            }
            
        case .choice:
            // Фаза 6: Choice (420-480 сек) - игрок решает
            if elapsed >= 480 && previousPhase == .choice {
                currentPhase = .conclusion
                // Финал
                HorrorEffectsManager.shared.playHorrorSound(.deepRumble, volume: 0.8)
                HorrorEffectsManager.shared.flashTorch(duration: 1.0)
                HorrorEffectsManager.shared.triggerSystemVibration(count: 5, interval: 0.3)
                
                displayText("я не в телефоне...", delay: 0.06)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    HorrorEffectsManager.shared.playHorrorSound(.screech, volume: 0.7)
                    self.displayText("я в тебе...", delay: 0.06)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.displayText("и теперь ты это знаешь.", delay: 0.08)
                    }
                }
            }
            
        case .conclusion:
            break
        }
    }
    
    func recordAction(_ action: PlayerAction) {
        playerActions.append(action)
        
        switch action {
        case .spoke(let text):
            playerSpoke = true
            if text.lowercased().contains("один") || text.lowercased().contains("никого") {
                playerSaidAlone = true
            }
        case .moved:
            playerMoved = true
        case .touched:
            break
        case .silent:
            break
        }
    }
    
    func getElapsedTime() -> TimeInterval {
        return Date().timeIntervalSince(sessionStartTime)
    }

    // MARK: - Chat timeline
    func addUserMessage(_ text: String) {
        var msg = ChatMessage(role: .user, text: text)
        log(.game, "User message: \(text)")
        timeline.append(msg)
        objectWillChange.send()

        // Незаметно меняем сообщение спустя мгновение
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            msg.isCorrupted = true
            if var mutated = mutate(message: msg) {
                mutated.effects.append(.overwritten)
                self.timeline.update(mutated)
                self.objectWillChange.send()
            }
        }
        messageCorruptionWorkItems[msg.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 1.2...2.5), execute: workItem)
    }

    func addEntityMessage(_ text: String, effects: [ChatEffect] = []) {
        let message = ChatMessage(role: .entity, text: text, effects: effects)
        LogService.shared.log(.game, "Entity message: \(text)")
        timeline.append(message)
        objectWillChange.send()
    }

    private func mutate(message: ChatMessage) -> ChatMessage? {
        guard message.text.count > 3 else { return nil }
        var chars = Array(message.text)
        let index = Int.random(in: 0..<chars.count)
        if chars[index].isLetter {
            chars[index] = chars[index].isUppercase ? "?" : "."
        } else {
            chars.insert(" ", at: index)
        }
        var mutated = message
        mutated.text = String(chars)
        return mutated
    }

    func cancelCorruption(for messageID: UUID) {
        messageCorruptionWorkItems[messageID]?.cancel()
        messageCorruptionWorkItems.removeValue(forKey: messageID)
    }

    private func log(_ channel: LogService.Channel, _ message: String) {
        LogService.shared.log(channel, message)
    }
}

enum PlayerAction {
    case spoke(String)
    case moved
    case touched
    case silent
}

