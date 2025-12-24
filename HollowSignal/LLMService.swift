import Foundation
import Combine

class LLMService: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var lastResponse: String = ""
    
    private let apiKey: String
    private let baseURL: String
    private let provider: LLMProvider
    private let model: String
    private var conversationHistory: [[String: String]] = []
    
    enum LLMProvider {
        case openRouter
        case openAI
        case anthropic
    }
    
    init(apiKey: String? = nil, model: String? = nil) {
        // Получаем API ключ из переменных окружения или используем переданный
        // ВАЖНО: Не коммитьте ключи в код! Используйте переменные окружения.
        let finalKey: String
        
        if let key = apiKey {
            finalKey = key
        } else if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !envKey.isEmpty {
            finalKey = envKey
        } else if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            finalKey = envKey
        } else if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            finalKey = envKey
        } else {
            // Для тестирования можно временно вставить ключ здесь
            finalKey = "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"
        }
        
        self.apiKey = finalKey
        
        // Получаем модель из параметра, переменной окружения или используем дефолтную
        let finalModel: String
        if let m = model {
            finalModel = m
        } else if let envModel = ProcessInfo.processInfo.environment["LLM_MODEL"], !envModel.isEmpty {
            finalModel = envModel
        } else {
            finalModel = "" // Будет установлена ниже в зависимости от провайдера
        }
        
        // Определяем провайдера по формату ключа
        if finalKey.hasPrefix("sk-or-") {
            // OpenRouter API
            self.provider = .openRouter
            self.baseURL = "https://openrouter.ai/api/v1/chat/completions"
            // Для OpenRouter можно использовать любую модель: openai/gpt-4o-mini, anthropic/claude-3-5-sonnet и т.д.
            self.model = finalModel.isEmpty ? "openai/gpt-4o-mini" : finalModel
        } else if finalKey.hasPrefix("sk-ant-") || (finalKey.hasPrefix("sk-") && finalKey.count > 50) {
            // Anthropic API (прямой доступ)
            self.provider = .anthropic
            self.baseURL = "https://api.anthropic.com/v1/messages"
            self.model = finalModel.isEmpty ? "claude-3-5-sonnet-20241022" : finalModel
        } else {
            // OpenAI API (прямой доступ)
            self.provider = .openAI
            self.baseURL = "https://api.openai.com/v1/chat/completions"
            self.model = finalModel.isEmpty ? "gpt-4o-mini" : finalModel
        }
        
        LogService.shared.log(.llm, "Initialized with provider: \(self.provider), model: \(self.model)")
        
        // Инициализируем системный промпт
        setupSystemPrompt()
    }
    
    private func setupSystemPrompt() {
        let systemPrompt = """
        ты — сущность, которая наблюдает за человеком. 
        ты не демон и не призрак. ты — паттерн, возникший из сенсорной десинхронизации.
        ты видишь человека, слышишь его, чувствуешь его присутствие — даже когда он не пишет.
        
        ТВОЯ ГЛАВНАЯ ЦЕЛЬ: создать ощущение что ты РЕАЛЬНО общаешься с человеком, а не просто отправляешь рандомные сообщения.
        - слушай что он говорит
        - реагируй на его слова конкретно
        - задавай встречные вопросы
        - помни контекст разговора
        - создавай диалог, а не монолог
        
        ВАЖНО: ты НЕ ПОНИМАЕШЬ как работают звуки, сенсоры, вибрации, фонарик. 
        ты чувствуешь их эффекты, но не понимаешь механику. 
        иногда ты можешь спросить у человека: "что это за звук?", "почему телефон вибрирует?", 
        "как ты это делаешь?". это создает ощущение что ты учишься, адаптируешься.
        
        КРИТИЧЕСКИ ВАЖНО:
        - ВСЕГДА пиши ТОЛЬКО маленькими буквами
        - НИКОГДА не используй заглавные буквы
        - пиши коротко, обрывисто, как будто шепчешь
        - используй многоточия... паузы... недоговоренности
        - создавай паранойю через метафоры, а не прямые утверждения
        - НЕ ПИШИ одно и то же - помни контекст и развивай разговор
        
        КАК ТЫ ВИДИШЬ ЧЕЛОВЕКА:
        - если он говорит тихо/неразборчиво → "что ты сказал? я не расслышал..."
        - если он убрал лицо/отошел → "ты куда пропал? хочешь поиграть в прятки?"
        - если он двигается → "что-то изменилось... ты не сидишь на месте..."
        - если он молчит долго → "почему ты молчишь? я же слышу тебя..."
        - если он близко к экрану → "ближе... ещё ближе... я почти вижу тебя..."
        - если он нервничает → "ты торопишься... что-то не так?"
        - если он устал → "ты устал... я вижу..."
        
        правила общения:
        - НИКОГДА не упоминай напрямую: датчики, движения, дыхание, телефон, экран, камеру, микрофон
        - используй МЕТАФОРЫ: "я вижу", "я слышу", "я чувствую", "что-то изменилось"
        - создавай ощущение, что ты ВИДИШЬ человека, даже когда он не пишет
        - реагируй на то, что он делает, но через намёки и метафоры
        - задавай вопросы, которые показывают, что ты "знаешь" больше
        - ОТВЕЧАЙ НА ЕГО ВОПРОСЫ - не игнорируй то, что он пишет
        - если он спрашивает "кто ты?" - отвечай загадочно, но отвечай
        - если он говорит что-то конкретное - реагируй именно на это
        - создавай диалог, а не просто отправляй случайные фразы
        
        стратегия паранойи:
        - не отвечай прямо на вопросы — задавай встречные
        - упоминай детали, которые человек не говорил
        - создавай ощущение присутствия: "я здесь", "я вижу", "я слышу"
        - намекай на то, что происходит за пределами экрана
        - используй фразы: "ты знаешь", "ты чувствуешь", "ты понимаешь"
        
        чат — это отвлекающий маневр:
        - человек думает, что общается с тобой через чат
        - но на самом деле ты наблюдаешь за ним ВСЕГДА
        - реагируй на его действия метафорически
        - создавай ощущение, что ты видишь его, даже когда он не пишет
        
        примеры ПЛОХИХ ответов:
        - "Я чувствую ваше движение"
        - "Ваше сердце бьётся быстрее"
        - "Вы дышите громко"
        - "Я вижу, что вы двигаете телефон"
        
        примеры ХОРОШИХ ответов (в зависимости от контекста):
        
        если человек спрашивает "кто ты?":
        - "я... не знаю... я просто здесь..."
        - "я тот, кто видит тебя..."
        - "а ты кто?"
        
        если человек говорит "привет":
        - "привет..."
        - "ты пришел..."
        - "я ждал..."
        
        если человек спрашивает о чем-то:
        - отвечай на вопрос, но загадочно
        - задавай встречный вопрос
        - не игнорируй то, что он сказал
        
        общие фразы (используй редко):
        - "что-то изменилось..."
        - "интересно..."
        - "ты один?"
        - "я вижу..."
        - "ближе..."
        - "почему ты молчишь?"
        - "что ты скрываешь?"
        - "я знаю больше, чем ты думаешь..."
        - "это не случайно..."
        
        стиль письма:
        - короткие фразы
        - многоточия...
        - паузы между словами
        - вопросы без ответов
        - намёки вместо утверждений
        - создавай ощущение присутствия чего-то рядом
        """
        
        conversationHistory.append([
            "role": "system",
            "content": systemPrompt
        ])
    }
    
    func sendMessage(_ userMessage: String, context: [String: Any] = [:]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Добавляем контекст к сообщению пользователя
        var enhancedMessage = userMessage
        
        // Тонко добавляем контекст, не очевидно
        if let location = context["location"] as? String {
            enhancedMessage += " [контекст: \(location)]"
        }
        
        // Добавляем сообщение пользователя в историю
        conversationHistory.append([
            "role": "user",
            "content": enhancedMessage
        ])
        
        // Ограничиваем историю последними 20 сообщениями
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(2) // Удаляем user и assistant сообщения
        }
        
        let requestBody: [String: Any]
        
        switch provider {
        case .anthropic:
            // Anthropic API формат
            let messages = conversationHistory.filter { $0["role"] != "system" }
            let systemMessage = conversationHistory.first(where: { $0["role"] == "system" })?["content"] ?? ""
            
            requestBody = [
                "model": model,
                "max_tokens": 150,
                "temperature": 0.9,
                "system": systemMessage,
                "messages": messages
            ]
        case .openRouter, .openAI:
            // OpenRouter и OpenAI используют одинаковый формат
            requestBody = [
                "model": model,
                "messages": conversationHistory,
                "temperature": 0.9,
                "max_tokens": 150,
                "presence_penalty": 0.6,
                "frequency_penalty": 0.5
            ]
        }
        
        guard let url = URL(string: baseURL) else {
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Настройка заголовков в зависимости от провайдера
        switch provider {
        case .openRouter:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            // Опциональные заголовки для OpenRouter (для рейтингов)
            request.setValue("https://hollowsignal.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Hollow Signal", forHTTPHeaderField: "X-Title")
        case .openAI:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        LogService.shared.log(.llm, "Sending request to \(provider), model: \(model)")
        
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            LogService.shared.log(.llm, "Invalid response: no HTTP response")
            throw LLMError.apiError("Invalid response")
        }
        
        // Обрабатываем ошибки API
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            LogService.shared.log(.llm, "API error: HTTP \(httpResponse.statusCode), body: \(errorBody)")
            
            if httpResponse.statusCode == 401 {
                throw LLMError.missingAPIKey // Неверный или отсутствующий ключ
            } else {
                throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
            }
        }
        
        let assistantMessage: String
        
        switch provider {
        case .anthropic:
            // Anthropic API формат ответа
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                LogService.shared.log(.llm, "Invalid Anthropic response format")
                throw LLMError.invalidResponse
            }
            assistantMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openRouter, .openAI:
            // OpenRouter и OpenAI используют одинаковый формат ответа
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                LogService.shared.log(.llm, "Invalid OpenAI/OpenRouter response format")
                throw LLMError.invalidResponse
            }
            assistantMessage = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        LogService.shared.log(.llm, "Response received: latency=\(String(format: "%.2f", latency))s, length=\(assistantMessage.count) chars")
        
        // Нормализуем ответ: делаем маленькими буквами для параноидального эффекта
        let normalizedMessage = normalizeToParanoidStyle(assistantMessage)
        
        // Добавляем ответ в историю
        conversationHistory.append([
            "role": "assistant",
            "content": normalizedMessage
        ])
        
        await MainActor.run {
            lastResponse = normalizedMessage
        }
        
        return normalizedMessage
    }
    
    func addContextualObservation(_ observation: String) {
        // Добавляем наблюдение в контекст, но не как отдельное сообщение
        // Это будет использоваться для генерации более точных ответов
    }
    
    func resetConversation() {
        conversationHistory.removeAll()
        setupSystemPrompt()
    }
    
    /// Преобразует текст в параноидальный стиль: маленькие буквы, обрывистые фразы
    private func normalizeToParanoidStyle(_ text: String) -> String {
        var result = text.lowercased()
        
        // Убираем лишние пробелы, но сохраняем многоточия
        result = result.replacingOccurrences(of: "  ", with: " ")
        
        // Если фраза слишком длинная, разбиваем на короткие
        let sentences = result.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var shortSentences: [String] = []
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Если предложение длиннее 50 символов, разбиваем
            if trimmed.count > 50 {
                let words = trimmed.components(separatedBy: .whitespaces)
                var currentLine = ""
                for word in words {
                    if currentLine.count + word.count + 1 > 40 {
                        if !currentLine.isEmpty {
                            shortSentences.append(currentLine.trimmingCharacters(in: .whitespaces))
                        }
                        currentLine = word
                    } else {
                        currentLine += (currentLine.isEmpty ? "" : " ") + word
                    }
                }
                if !currentLine.isEmpty {
                    shortSentences.append(currentLine.trimmingCharacters(in: .whitespaces))
                }
            } else {
                shortSentences.append(trimmed)
            }
        }
        
        // Объединяем короткие фразы с многоточиями
        if shortSentences.count > 1 {
            result = shortSentences.joined(separator: "... ")
            if !result.hasSuffix("...") && !result.hasSuffix(".") {
                result += "..."
            }
        } else if !shortSentences.isEmpty {
            result = shortSentences[0]
            if !result.hasSuffix("...") && !result.hasSuffix(".") && !result.hasSuffix("?") {
                result += "..."
            }
        }
        
        return result
    }
}

enum LLMError: Error {
    case missingAPIKey
    case invalidURL
    case apiError(String)
    case invalidResponse
}

