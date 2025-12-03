import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var gameState: GameStateManager
    @EnvironmentObject var sensorManager: SensorManager
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    @EnvironmentObject var reactionEngine: ReactionEngine
    @EnvironmentObject var llmService: LLMService
    @EnvironmentObject var dataRecorder: DataRecorder
    @EnvironmentObject var faceTracker: FaceTracker
    @EnvironmentObject var sensorHub: SensorHub
    
    @State private var showTypingIndicator = false
    @State private var composerText: String = ""
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack(spacing: 12) {
                chatTimeline
                
                if gameState.isTyping {
                    typingIndicator
                        .padding(.bottom, 20)
                }
                
                composer
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)
            
        
        }
        .onAppear {
            setupGame()
            showTypingIndicator = true
        }
        .onChange(of: speechRecognizer.recognizedText) { text in
            guard !text.isEmpty else { return }
            let transcription = SpeechTranscription(timestamp: Date(), text: text, confidence: 1.0)
            dataRecorder.addTranscription(transcription)
            LogService.shared.log(.sensors, "captured speech: \(text)")
            
            Task {
                await reactionEngine.handlePlayerSpeech(text)
            }
            gameState.recordAction(.spoke(text))
        }
        .onChange(of: sensorManager.isMoving) { isMoving in
            if isMoving {
                reactionEngine.reactToPlayerAction(.moved)
                gameState.recordAction(.moved)
            }
        }
        .onChange(of: speechRecognizer.speechVolume) { volume in
            sensorManager.updateAudioLevel(volume)
        }
        .onChange(of: sensorManager.proximityDetected) { isNear in
            reactionEngine.reactToProximity(isNear)
        }
        .onTapGesture {
            reactionEngine.reactToPlayerAction(.touched)
            gameState.recordAction(.touched)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateGame()
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            // Незаметно реагируем на сенсоры во время чата (отвлекающий маневр)
            reactToSensorsSubtly()
        }
    }
    
    private var gradientBackground: some View {
        Color.black
            .ignoresSafeArea()
    }
    
    private var chatTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(gameState.timeline.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.3), value: message.isCorrupted)
                    }
                }
                .padding(.vertical, 8)
                .onChange(of: gameState.timeline.messages.count) { _ in
                    if let last = gameState.timeline.messages.last {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .scaleEffect(showTypingIndicator ? 1.2 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: showTypingIndicator
                    )
            }
        }
    }
    
    private func setupGame() {
        reactionEngine.setup(
            gameState: gameState,
            sensorManager: sensorManager,
            speechRecognizer: speechRecognizer,
            llmService: llmService,
            dataRecorder: dataRecorder,
            faceTracker: faceTracker,
            sensorHub: sensorHub
        )
        
        dataRecorder.startRecording()
        speechRecognizer.startListening()
        faceTracker.startTracking()
    }
    
    private func updateGame() {
        gameState.advancePhase()
        let elapsed = gameState.getElapsedTime()
        
        if gameState.currentPhase == .observations && !gameState.isTyping {
            Task {
                if let observation = await reactionEngine.generateObservation() {
                    await MainActor.run {
                        gameState.displayText(observation)
                    }
                }
            }
        }
        
        if gameState.currentPhase == .anomalies {
            let anomaliesStartTime: TimeInterval = 240
            let timeInAnomalies = elapsed - anomaliesStartTime
            
            if timeInAnomalies >= 2 && timeInAnomalies < 4 {
                reactionEngine.createEchoEffect()
            }
            
            if sensorManager.isMoving && timeInAnomalies >= 10 && timeInAnomalies < 12 {
                reactionEngine.reactToMovementPrediction()
            }
            
            if timeInAnomalies >= 20 && timeInAnomalies < 22 {
                reactionEngine.reactToBreathingSync()
            }
        }
    }
    
    private func sendTypedMessage() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        composerText = ""
        gameState.addUserMessage(trimmed)
        
        Task {
            await reactionEngine.handleUserTyped(trimmed)
        }
        gameState.recordAction(.spoke(trimmed))
    }
    
    /// Незаметно реагирует на сенсоры во время чата - создает ощущение наблюдения
    private func reactToSensorsSubtly() {
        // Реагируем только если нет активного текста и прошло достаточно времени
        guard !gameState.isTyping && gameState.currentText.isEmpty else { return }
        
        let elapsed = gameState.getElapsedTime()
        
        // В фазе наблюдений и дальше - более активные реакции
        if gameState.currentPhase.rawValue >= GamePhase.observations.rawValue {
            // Если человек двигается - тонкая реакция
            if sensorManager.isMoving && Double.random(in: 0...1) > 0.7 {
                Task {
                    await reactionEngine.reactToPlayerAction(.moved)
                }
            }
            
            // Если долго молчит - реакция на тишину
            if elapsed > 10.0 && Double.random(in: 0...1) > 0.8 {
                Task {
                    await reactionEngine.reactToPlayerAction(.silent)
                }
            }
        }
    }
    
    private var composer: some View {
        HStack(spacing: 12) {
            TextField("напечатайте…", text: $composerText, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .foregroundColor(.white)
            
            Button(action: sendTypedMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.4)
                        : Color.white
                    )
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Subviews
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .entity {
                bubble
                Spacer()
            } else {
                Spacer()
                bubble
            }
        }
    }
    
    private var bubble: some View {
        Text(message.text)
            .font(.system(size: 17, weight: .regular, design: .default))
            .foregroundColor(message.role == .entity ? .white : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

struct DevOverlayView: View {
    @StateObject private var logListener = DevOverlayViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(logListener.entries.suffix(4)) { entry in
                Text("[\(entry.channel.rawValue)] \(entry.message)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

final class DevOverlayViewModel: ObservableObject {
    @Published var entries: [LogService.LogEntry] = []
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = LogService.shared.$latestEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.entries = $0 }
    }
}

struct NoiseView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let step = 8.0
                for x in stride(from: 0, to: size.width, by: step) {
                    for y in stride(from: 0, to: size.height, by: step) {
                        let opacity = Double.random(in: 0...0.3)
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStateManager())
        .environmentObject(SensorManager())
        .environmentObject(SpeechRecognizer())
        .environmentObject(ReactionEngine())
        .environmentObject(LLMService())
        .environmentObject(DataRecorder())
        .environmentObject(FaceTracker())
        .environmentObject(SensorHub.shared)
}

