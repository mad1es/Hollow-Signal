import SwiftUI

struct TextDisplayView: View {
    let text: String
    let isTyping: Bool
    @State private var displayedText: String = ""
    @State private var showCursor: Bool = true
    
    var body: some View {
        Text(displayedText + (isTyping && showCursor ? "|" : ""))
            .font(.system(size: 24, weight: .light, design: .default))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .onAppear {
                if isTyping {
                    animateTyping()
                } else {
                    displayedText = text
                }
            }
            .onChange(of: text) { newText in
                if isTyping {
                    animateTyping()
                } else {
                    displayedText = newText
                }
            }
    }
    
    private func animateTyping() {
        displayedText = ""
        let characters = Array(text)
        
        for (index, character) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                displayedText += String(character)
            }
        }
        
        // Мигающий курсор
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            showCursor.toggle()
            if !isTyping {
                timer.invalidate()
            }
        }
    }
}

