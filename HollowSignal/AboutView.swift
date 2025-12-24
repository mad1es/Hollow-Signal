import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        aboutSection
                        
                        developersSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("ABOUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.18))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ABOUT")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.cyan.opacity(0.7))
                .tracking(2)
            
            Text(aboutText)
                .font(.system(size: 15, weight: .light, design: .default))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var developersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DEVELOPERS")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.cyan.opacity(0.7))
                .tracking(2)
            
            VStack(alignment: .leading, spacing: 12) {
                DeveloperInfo(
                    name: "Ray Games",
                    role: "Baizhuman Madi, Olzhas Tuimekhan, Alzhazira Zhumat"
                )
                
                DeveloperInfo(
                    name: "Neuroscience Research",
                    role: "Sensory Desynchronization Concepts"
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private let aboutText = """
    At Hollow Signal, we delve deep into the realms of the human mind, exploring the unknown edges of neuroscience and the chilling consequences of tampering with reality. Our team is dedicated to crafting immersive psychological horror experiences that challenge your perceptions and evoke a deep sense of unease.

    In this game, you'll navigate through high-tech labs, uncover dark secrets, and witness the unraveling of reality itself. From glitchy, disturbing brain scans to secretive experiments and a viral technological catastrophe, Hollow Signal brings you closer to the haunting truths buried within the mind.

    We aim to blur the lines between fiction and reality, creating a world where every discovery brings you one step closer to an unsettling revelation.

    Enter the world of Hollow Signal… but be warned—what you uncover may change you forever.
    """
}

struct DeveloperInfo: View {
    let name: String
    let role: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white)
            
            Text(role)
                .font(.system(size: 13, weight: .light, design: .default))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    AboutView()
}

