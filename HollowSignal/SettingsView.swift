import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundsEnabled") private var soundsEnabled = true
    @AppStorage("voiceEchoEnabled") private var voiceEchoEnabled = true
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        settingsSection(
                            title: "AUDIO",
                            items: [
                                SettingToggle(
                                    title: "Sounds",
                                    description: "Enable horror sound effects",
                                    isOn: $soundsEnabled
                                ),
                                SettingToggle(
                                    title: "Voice Echo",
                                    description: "Play distorted echo of your voice",
                                    isOn: $voiceEchoEnabled
                                )
                            ]
                        )
                        
                        settingsSection(
                            title: "HAPTICS",
                            items: [
                                SettingToggle(
                                    title: "Heartbeat",
                                    description: "Enable heartbeat haptic feedback",
                                    isOn: $hapticsEnabled
                                )
                            ]
                        )
                        
                        settingsSection(
                            title: "DEVELOPMENT",
                            items: [
                                SettingToggle(
                                    title: "Dev Mode",
                                    description: "Show debug logs in game",
                                    isOn: $devModeEnabled
                                )
                            ]
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0x49/255.0, green: 0x9B/255.0, blue: 0x7A/255.0))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func settingsSection(title: String, items: [SettingToggle]) -> some View {
        let accentColor = Color(red: 0x49/255.0, green: 0x9B/255.0, blue: 0x7A/255.0)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(accentColor.opacity(0.9))
                .tracking(2)
            
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    item
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.4), lineWidth: 1)
                    )
            )
        }
    }
}

struct SettingToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0x49/255.0, green: 0x9B/255.0, blue: 0x7A/255.0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

#Preview {
    SettingsView()
}

