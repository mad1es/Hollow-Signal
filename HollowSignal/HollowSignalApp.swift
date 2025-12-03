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
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
                .environmentObject(sensorManager)
                .environmentObject(speechRecognizer)
                .environmentObject(reactionEngine)
                .environmentObject(llmService)
                .environmentObject(dataRecorder)
                .environmentObject(faceTracker)
                .environmentObject(sensorHub)
                .preferredColorScheme(.dark) // Темная тема
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

