import Foundation

enum ChatRole: String {
    case entity
    case user
    case system
}

enum ChatEffect: Equatable {
    case glitch
    case whisper
    case heartbeat
    case overwritten
    case warning
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    var text: String
    var timestamp: Date = Date()
    var effects: [ChatEffect] = []
    var isCorrupted: Bool = false
    var isDeleted: Bool = false
}

struct ChatTimeline {
    var messages: [ChatMessage] = []

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
    }

    mutating func update(_ message: ChatMessage) {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[idx] = message
    }
}


