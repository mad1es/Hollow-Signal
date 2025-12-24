import SwiftUI

struct MenuView: View {
    @EnvironmentObject var gameState: GameStateManager
    @EnvironmentObject var sensorManager: SensorManager
    @EnvironmentObject var speechRecognizer: SpeechRecognizer
    @EnvironmentObject var reactionEngine: ReactionEngine
    @EnvironmentObject var llmService: LLMService
    @EnvironmentObject var dataRecorder: DataRecorder
    @EnvironmentObject var faceTracker: FaceTracker
    @EnvironmentObject var sensorHub: SensorHub
    
    @State private var showGame = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var isVideoPlaying = false
    @State private var videoFinished = false
    @State private var showBlackScreen = false
    
    private let accent = Color(red: 0x49/255.0, green: 0x9B/255.0, blue: 0x7A/255.0)
    
    var body: some View {
        ZStack {
            VideoBackgroundView(
                videoName: "menu_background",
                videoType: "mp4",
                shouldPlay: $isVideoPlaying,
                onFinished: {
                    videoFinished = true
                    // Плавно показываем черный экран
                    withAnimation(.easeInOut(duration: 1.0)) {
                        showBlackScreen = true
                    }
                    // После затемнения показываем игру
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showGame = true
                    }
                }
            )
            .ignoresSafeArea()
            .opacity(showBlackScreen ? 0 : 1)
            .animation(.easeInOut(duration: 1.0), value: showBlackScreen)
            
            // Затемнение фона когда видео на паузе
            Color.black
                .ignoresSafeArea()
                .opacity(isVideoPlaying ? 0 : 0.5)
                .animation(.easeInOut(duration: 0.5), value: isVideoPlaying)
            
            Color.black
                .ignoresSafeArea()
                .opacity(showBlackScreen ? 1.0 : (isVideoPlaying ? 0.0 : 0.0))
                .animation(.easeInOut(duration: 1.0), value: showBlackScreen)
            
            VStack(spacing: 0) {
                Spacer()
                
                titleSection
                    .offset(y: isVideoPlaying ? -UIScreen.main.bounds.height : -80)
                    .opacity(isVideoPlaying ? 0 : 1)
                    .animation(.easeInOut(duration: 2.0), value: isVideoPlaying)
                
                Spacer()
                    .frame(height: 100)
                
                menuButtons
                    .padding(.top, 40)
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onChange(of: showGame) { newValue in
            if !newValue {
                isVideoPlaying = false
                videoFinished = false
                showBlackScreen = false
            }
        }
        .overlay {
            if showGame {
                ContentView(onDismiss: {
                    showGame = false
                })
                    .environmentObject(gameState)
                    .environmentObject(sensorManager)
                    .environmentObject(speechRecognizer)
                    .environmentObject(reactionEngine)
                    .environmentObject(llmService)
                    .environmentObject(dataRecorder)
                    .environmentObject(faceTracker)
                    .environmentObject(sensorHub)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }
    
    private var titleSection: some View {
        Text("SIGNAL")
            .font(.custom("HeadingNowTrial-36Bold", size: 140))
            .foregroundColor(.white)
            .tracking(2)
    }
    
    private var menuButtons: some View {
        VStack(spacing: 16) {
            MenuButton(
                title: "START GAME",
                action: {
                    isVideoPlaying = true
                }
            )
            .offset(y: isVideoPlaying ? UIScreen.main.bounds.height : 0)
            .opacity(isVideoPlaying ? 0 : 1)
            .animation(.easeInOut(duration: 2.0).delay(0.5), value: isVideoPlaying)
            
            MenuButton(
                title: "SETTINGS",
                action: { showSettings = true }
            )
            .offset(y: isVideoPlaying ? UIScreen.main.bounds.height : 0)
            .opacity(isVideoPlaying ? 0 : 1)
            .disabled(isVideoPlaying)
            .animation(.easeInOut(duration: 2.0).delay(0.3), value: isVideoPlaying)
            
            MenuButton(
                title: "ABOUT",
                action: { showAbout = true }
            )
            .offset(y: isVideoPlaying ? UIScreen.main.bounds.height : 0)
            .opacity(isVideoPlaying ? 0 : 1)
            .disabled(isVideoPlaying)
            .animation(.easeInOut(duration: 2.0).delay(0.1), value: isVideoPlaying)
        }
    }
}

struct MenuButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    private let accent = Color(red: 0x49/255.0, green: 0x9B/255.0, blue: 0x7A/255.0)
    private let darkBase = Color(red: 0.05, green: 0.08, blue: 0.08)
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(accent.opacity(0.9))
                .tracking(3)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    darkBase.opacity(0.9),
                                    darkBase.opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accent.opacity(0.8), lineWidth: 2)
                                .shadow(color: accent.opacity(0.6), radius: 6, x: 0, y: 0)
                                .shadow(color: accent.opacity(0.4), radius: 10, x: 0, y: 0)
                        )
                        .overlay(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.15),
                                    Color.clear,
                                    accent.opacity(0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .blendMode(.screen)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                        .shadow(color: accent.opacity(0.35), radius: isPressed ? 8 : 12, x: 0, y: 0)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    MenuView()
}

