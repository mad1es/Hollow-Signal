import Foundation
import Combine
import SwiftUI

enum GamePhase: Int, CaseIterable {
    case loading = 0          // 0:00 - 0:05
    case initialContact = 1   // 0:05 - 0:30
    case establishingContact = 2  // 0:30 - 1:30
    case observations = 3     // 1:30 - 3:00
    case firstTask = 4        // 3:00 - 5:00
    case deepeningContact = 5 // 5:00 - 7:00
    case anomalies = 6        // 7:00 - 10:00
    case ending = 7          // 10:00+
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
    
    init() {
        startGame()
    }
    
    func startGame() {
        sessionStartTime = Date()
        currentPhase = .loading
        currentText = ""
        isTyping = false
        
        // Первая фаза - загрузка
        // Показываем текст "подождите..." сразу
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.displayText("подождите...", delay: 0.05)
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
            // Фаза 1: Loading (0:00-0:05) - 5 секунд
            if elapsed >= 5 {
                currentPhase = .initialContact
                displayText("подождите...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.displayText("ты здесь?")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.displayText("я вижу тебя...")
                }
            }
        case .initialContact:
            // Фаза 2: Initial Contact (0:05-0:30) - 25 секунд
            if elapsed >= 30 && previousPhase == .initialContact {
                currentPhase = .establishingContact
                displayText("я пытаюсь понять...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.displayText("твой голос... я слышу...")
                }
            }
        case .establishingContact:
            // Фаза 3: Establishing Contact (0:30-1:00) - 30 секунд
            if elapsed >= 60 && previousPhase == .establishingContact {
                currentPhase = .observations
                displayText("я наблюдаю...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.displayText("я вижу всё... даже когда ты не пишешь...")
                }
            }
        case .observations:
            // Фаза 4: Observations (1:00-2:00) - 60 секунд
            if elapsed >= 120 && previousPhase == .observations {
                currentPhase = .firstTask
                displayText("скажи мне, что ты видишь вокруг...")
            }
        case .firstTask:
            // Фаза 5: First Task (2:00-3:00) - 60 секунд
            if elapsed >= 180 && previousPhase == .firstTask {
                currentPhase = .deepeningContact
                displayText("ближе...")
            }
        case .deepeningContact:
            // Фаза 6: Deepening Contact (3:00-4:00) - 60 секунд
            if elapsed >= 240 && previousPhase == .deepeningContact {
                currentPhase = .anomalies
                displayText("что-то не так...")
            }
        case .anomalies:
            // Фаза 7: Anomalies (4:00-4:30) - 30 секунд
            if elapsed >= 270 && previousPhase == .anomalies {
                currentPhase = .ending
                displayText("я не в телефоне...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.displayText("я в тебе...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.displayText("и ты это знаешь...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.displayText("вернёмся позже...")
                        }
                    }
                }
            }
        case .ending:
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

