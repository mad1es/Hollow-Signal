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
    
    var onDismiss: (() -> Void)?
    @State private var showTypingIndicator = false
    @State private var composerText: String = ""
    
    @State private var isAppearing = false
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    
    var body: some View {
        ZStack {
            gradientBackground
            
            Color.black
                .ignoresSafeArea()
                .opacity(isAppearing ? 0 : 1)
                .animation(.easeInOut(duration: 1.5), value: isAppearing)
            
            VStack(spacing: 0) {
                headerBar
                    .opacity(isAppearing ? 1 : 0)
                
                chatTimeline
                    .opacity(isAppearing ? 1 : 0)
                
                if gameState.isTyping {
                    typingIndicator
                        .padding(.vertical, 12)
                        .opacity(isAppearing ? 1 : 0)
                }
                
                composer
                    .opacity(isAppearing ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 1.5), value: isAppearing)
            
            if devModeEnabled {
                DevOverlayView()
                    .opacity(isAppearing ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Перезапускаем игру при каждом появлении экрана
            gameState.startGame()
            setupGame()
            showTypingIndicator = true
            
            // Плавное появление чата из темноты
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAppearing = true
            }
        }
        .onDisappear {
            // Останавливаем всё при закрытии экрана
            HorrorEffectsManager.shared.stopHeartbeatLoop()
            VoiceEchoService.shared.cleanup()
            speechRecognizer.stopListening()
            faceTracker.stopTracking()
            dataRecorder.stopRecording()
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
    
    private var headerBar: some View {
        HStack {
            Button(action: {
                // Останавливаем все эффекты и сенсоры перед возвратом в меню
                HorrorEffectsManager.shared.stopHeartbeatLoop()
                VoiceEchoService.shared.cleanup()
                speechRecognizer.stopListening()
                faceTracker.stopTracking()
                dataRecorder.stopRecording()
                onDismiss?()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("MENU")
                        .font(.system(size: 14, weight: .light, design: .default))
                        .tracking(1)
                }
                .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.9))
            }
            
            Spacer()
            
            Text("HOLLOW SIGNAL")
                .font(.system(size: 12, weight: .light, design: .default))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
    }
    
    private var chatTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(gameState.timeline.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.3), value: message.isCorrupted)
                    }
                }
                .padding(.vertical, 16)
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
            TextField("Type a message...", text: $composerText, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.5), lineWidth: 1)
                        )
                )
            
            Button(action: sendTypedMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.3)
                        : Color(red: 0.0, green: 0.35, blue: 0.18)
                    )
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Subviews
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .entity {
                entityBubble
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                userBubble
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var entityBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.4), lineWidth: 0.5)
                    )
            )
            
            Circle()
                .fill(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.7))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("H")
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundColor(.black)
                )
        }
    }
    
    private var userBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("Y")
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.0, green: 0.35, blue: 0.18).opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DevOverlayView: View {
    @StateObject private var logListener = DevOverlayViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(logListener.entries.suffix(10)) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(channelIcon(entry.channel))
                            .font(.caption2.monospaced())
                            .foregroundColor(channelColor(entry.channel))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("[\(entry.channel.rawValue.uppercased())]")
                                .font(.caption2.monospaced().bold())
                                .foregroundColor(channelColor(entry.channel))
                            
                            Text(entry.message)
                                .font(.caption2.monospaced())
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: 350, maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.leading, 16)
        .padding(.top, 60)
    }
    
    private func channelIcon(_ channel: LogService.Channel) -> String {
        switch channel {
        case .system: return "⚙️"
        case .sensors: return "📡"
        case .llm: return "🤖"
        case .game: return "🎮"
        case .ui: return "🖼️"
        case .audio: return "🔊"
        case .haptics: return "📳"
        case .error: return "❌"
        }
    }
    
    private func channelColor(_ channel: LogService.Channel) -> Color {
        switch channel {
        case .system: return .gray
        case .sensors: return .blue
        case .llm: return .purple
        case .game: return .green
        case .ui: return .orange
        case .audio: return .yellow
        case .haptics: return .pink
        case .error: return .red
        }
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
    ContentView(onDismiss: nil)
        .environmentObject(GameStateManager())
        .environmentObject(SensorManager())
        .environmentObject(SpeechRecognizer())
        .environmentObject(ReactionEngine())
        .environmentObject(LLMService())
        .environmentObject(DataRecorder())
        .environmentObject(FaceTracker())
        .environmentObject(SensorHub.shared)
}


