import Foundation
import Combine
import os.log

/// Центральный логгер, пишет события в консоль и файл.
final class LogService {
    static let shared = LogService()

    enum Channel: String {
        case system
        case sensors
        case llm
        case game
        case ui
        case audio
        case haptics
        case error
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let channel: Channel
        let message: String
    }

    private let queue = DispatchQueue(label: "com.hollowsignal.logservice")
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    @Published private(set) var latestEntries: [LogEntry] = []
    private let maxEntries = 200

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Подготавливаем файл логов
        let logsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs", isDirectory: true)

        if let logsURL = logsURL {
            try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
            let fileURL = logsURL.appendingPathComponent("session-\(Int(Date().timeIntervalSince1970)).log")
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            fileHandle = try? FileHandle(forWritingTo: fileURL)
        } else {
            fileHandle = nil
        }
    }

    func log(_ channel: Channel, _ message: String) {
        let entry = LogEntry(timestamp: Date(), channel: channel, message: message)

        queue.async { [weak self] in
            guard let self else { return }

            // Обновляем буфер последних записей
            DispatchQueue.main.async {
                self.latestEntries.append(entry)
                if self.latestEntries.count > self.maxEntries {
                    self.latestEntries.removeFirst(self.latestEntries.count - self.maxEntries)
                }
            }

            let formatted = "[\(self.dateFormatter.string(from: entry.timestamp))][\(channel.rawValue.uppercased())] \(message)\n"
            os_log("%{public}@", formatted)

            if let data = formatted.data(using: .utf8) {
                try? self.fileHandle?.write(contentsOf: data)
            }
        }
    }
}

