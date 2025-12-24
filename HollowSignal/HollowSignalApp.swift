import SwiftUI

@main
struct HollowSignalApp: App {
    @StateObject private var gameState = GameStateManager()
    @StateObject private var sensorManager = SensorManager()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var reactionEngine = ReactionEngine()
    @StateObject private var llmService = LLMService(
        // Модель можно указать через переменную окружения LLM_MODEL
        // Например: "openai/gpt-4o-mini", "openai/gpt-5", "anthropic/claude-3-5-sonnet"
        model: ProcessInfo.processInfo.environment["LLM_MODEL"]
    )
    @StateObject private var dataRecorder = DataRecorder()
    @StateObject private var faceTracker = FaceTracker()
    @StateObject private var sensorHub = SensorHub.shared
    
    init() {
        // Настройка вибраций
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        
        // Включаем мониторинг батареи
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Инициализация настроек по умолчанию
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hapticsEnabled") == nil {
            defaults.set(true, forKey: "hapticsEnabled")
        }
        if defaults.object(forKey: "soundsEnabled") == nil {
            defaults.set(true, forKey: "soundsEnabled")
        }
        if defaults.object(forKey: "voiceEchoEnabled") == nil {
            defaults.set(true, forKey: "voiceEchoEnabled")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MenuView()
                .environmentObject(gameState)
                .environmentObject(sensorManager)
                .environmentObject(speechRecognizer)
                .environmentObject(reactionEngine)
                .environmentObject(llmService)
                .environmentObject(dataRecorder)
                .environmentObject(faceTracker)
                .environmentObject(sensorHub)
                .preferredColorScheme(.dark)
                .onAppear {
                    sensorHub.bind(
                        sensorManager: sensorManager,
                        dataRecorder: dataRecorder,
                        faceTracker: faceTracker
                    )
                }
        }
    }
}

