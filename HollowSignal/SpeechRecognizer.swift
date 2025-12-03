import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    @Published var speechVolume: Float = 0.0
    @Published var speechSpeed: Double = 0.0 // Слов в секунду
    
    @Published var lastSpeechTime: Date?
    private var speechWords: [String] = []
    private var speechStartTime: Date?
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Разрешение на распознавание речи получено")
                case .denied, .restricted, .notDetermined:
                    print("Разрешение на распознавание речи отклонено")
                @unknown default:
                    break
                }
            }
        }
    }
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Распознавание речи недоступно")
            return
        }
        
        // Остановить предыдущую задачу
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Настроить аудио сессию
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Для категории .record доступны только опции: .allowBluetooth, .allowBluetoothA2DP
            // .defaultToSpeaker работает только с .playAndRecord
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try audioSession.setActive(true, options: [])
        } catch {
            print("Ошибка настройки аудио сессии: \(error.localizedDescription)")
            // Пытаемся деактивировать и попробовать снова
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                // Небольшая задержка перед повторной попыткой
                Thread.sleep(forTimeInterval: 0.1)
                try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
                try audioSession.setActive(true, options: [])
            } catch {
                print("Повторная попытка настройки аудио сессии также не удалась: \(error.localizedDescription)")
                return
            }
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            
            // Анализ громкости
            if let channelData = buffer.floatChannelData {
                let channelDataValue = channelData.pointee
                let frameLength = Int(buffer.frameLength)
                let strideValue = buffer.stride
                
                // Безопасный доступ к данным буфера
                guard frameLength > 0, strideValue > 0 else { return }
                
                let channelDataValueArray = Swift.stride(from: 0, to: frameLength, by: strideValue)
                    .compactMap { index -> Float? in
                        guard index < frameLength else { return nil }
                        return channelDataValue[index]
                    }
                
                guard !channelDataValueArray.isEmpty else { return }
                
                let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
                let avgPower = 20 * log10(max(rms, 0.0001)) // Защита от log(0)
                let volume = pow(10, (avgPower + 60) / 20)
                
                DispatchQueue.main.async {
                    self?.speechVolume = volume
                }
            }
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async { [weak self] in
                self?.speechStartTime = Date()
                self?.isListening = true
            }
        } catch {
            print("Ошибка запуска аудио движка: \(error)")
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.recognizedText = text
                    
                    // Анализ скорости речи
                    if let startTime = self.speechStartTime {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                        self.speechWords = words
                        self.lastSpeechTime = Date()
                        
                        if elapsed > 0 {
                            self.speechSpeed = Double(words.count) / elapsed
                        }
                    }
                }
                
                // Если финальный результат
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.stopListening()
                    }
                }
            }
            
            if let error = error {
                print("Ошибка распознавания: \(error)")
                DispatchQueue.main.async {
                    self.stopListening()
                }
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.isListening = false
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }
    
    func analyzeSpeechEmotion() -> SpeechEmotion {
        let text = recognizedText.lowercased()
        
        // Простой анализ эмоций по словам и характеристикам речи
        if speechSpeed > 4.0 {
            return .nervous
        } else if speechSpeed < 1.5 {
            return .tired
        } else if speechVolume > 0.5 {
            return .loud
        } else if speechVolume < 0.1 {
            return .quiet
        } else if text.contains("боюсь") || text.contains("страшно") {
            return .afraid
        } else if text.contains("злюсь") || text.contains("злой") {
            return .angry
        }
        
        return .neutral
    }
    
    func containsKeywords(_ keywords: [String]) -> Bool {
        let text = recognizedText.lowercased()
        return keywords.contains { text.contains($0.lowercased()) }
    }
    
    deinit {
        stopListening()
    }
}

enum SpeechEmotion {
    case neutral
    case nervous
    case tired
    case loud
    case quiet
    case afraid
    case angry
}

