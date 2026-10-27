import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case ollama = "Local Ollama (100% Free On-Device)"
    case gemini = "Google Gemini API (Free Tier / Pro)"
    case openai = "OpenAI / Groq / OpenRouter API"
    
    var id: String { rawValue }
}

struct RecommendedFreeModel: Identifiable {
    let id: String
    let tag: String
    let title: String
    let badge: String
    let description: String
}

@MainActor
final class LLMService: ObservableObject {
    static let smartAutoRouteTag = "auto:smart-router"
    
    static let recommendedModels: [RecommendedFreeModel] = [
        RecommendedFreeModel(
            id: "gemma4:e4b",
            tag: "gemma4:e4b",
            title: "Gemma 4 (e4B Multimodal)",
            badge: "NEW · VISION + FAST",
            description: "Google DeepMind's newest multimodal model. Reads screen images + audio transcripts with <250ms latency."
        ),
        RecommendedFreeModel(
            id: "gemma4:26b",
            tag: "gemma4:26b",
            title: "Gemma 4 26B MoE (4B Active)",
            badge: "BEST ALL-AROUND",
            description: "26B Mixture-of-Experts with only 4B active parameters per token. Frontier intelligence + native Vision at 4B speed."
        ),
        RecommendedFreeModel(
            id: "qwen3-coder-64k:latest",
            tag: "qwen3-coder-64k:latest",
            title: "Qwen3 Coder 64K (30B-A3B)",
            badge: "INSTALLED · ELITE CODING",
            description: "Already installed on your Mac. 64K context window specialized for LeetCode, HackerRank, and repository coding."
        ),
        RecommendedFreeModel(
            id: "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M",
            tag: "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M",
            title: "Qwen 3.8 27B (Unsloth Dynamic Q4)",
            badge: "INSTALLED · HEAVY REASONING",
            description: "Already installed on your Mac. 27B dense model for deep system design and hard algorithmic reasoning."
        ),
        RecommendedFreeModel(
            id: "qwen3.6:27b-coding",
            tag: "qwen3.6:27b-coding",
            title: "Qwen 3.6 27B Coding",
            badge: "NEW · AGENTIC CODING",
            description: "Latest Qwen 3.6 coding flagship with upgraded algorithm synthesis and bug fixing."
        )
    ]
    
    @Published var provider: LLMProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "cluely.provider") }
    }
    @Published var ollamaEndpoint: String {
        didSet { UserDefaults.standard.set(ollamaEndpoint, forKey: "cluely.ollamaEndpoint") }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "cluely.selectedModel") }
    }
    @Published var fastDirectMode: Bool {
        didSet { UserDefaults.standard.set(fastDirectMode, forKey: "cluely.fastDirectMode") }
    }
    @Published var availableOllamaModels: [String] = [
        LLMService.smartAutoRouteTag,
        "gemma4:e4b",
        "qwen3-coder-64k:latest",
        "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M",
        "hf.co/unsloth/Qwen3-14B-128K-GGUF:UD-Q4_K_XL",
        "qwen2.5vl-64k:latest",
        "devstral-16k:latest",
        "qwen3:4b-instruct"
    ]
    @Published var geminiApiKey: String {
        didSet { UserDefaults.standard.set(geminiApiKey, forKey: "cluely.geminiApiKey") }
    }
    @Published var openAIApiKey: String {
        didSet { UserDefaults.standard.set(openAIApiKey, forKey: "cluely.openAIApiKey") }
    }
    @Published var openAIBaseURL: String {
        didSet { UserDefaults.standard.set(openAIBaseURL, forKey: "cluely.openAIBaseURL") }
    }
    
    @Published var isStreaming: Bool = false
    @Published var activeResolvedModel: String = ""
    @Published var currentResponse: String = ""
    @Published var errorMessage: String? = nil
    
    // Model pull progress state
    @Published var isPullingModel: Bool = false
    @Published var pullingModelName: String = ""
    @Published var pullProgressText: String = ""
    @Published var pullProgressFraction: Double = 0.0
    
    private var activeTask: Task<Void, Never>?
    
    init() {
        let savedProvider = UserDefaults.standard.string(forKey: "cluely.provider") ?? LLMProvider.ollama.rawValue
        self.provider = LLMProvider(rawValue: savedProvider) ?? .ollama
        self.ollamaEndpoint = UserDefaults.standard.string(forKey: "cluely.ollamaEndpoint") ?? "http://localhost:11434"
        self.selectedModel = UserDefaults.standard.string(forKey: "cluely.selectedModel") ?? LLMService.smartAutoRouteTag
        if UserDefaults.standard.object(forKey: "cluely.fastDirectMode") == nil {
            self.fastDirectMode = true
        } else {
            self.fastDirectMode = UserDefaults.standard.bool(forKey: "cluely.fastDirectMode")
        }
        self.geminiApiKey = UserDefaults.standard.string(forKey: "cluely.geminiApiKey") ?? (ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "")
        self.openAIApiKey = UserDefaults.standard.string(forKey: "cluely.openAIApiKey") ?? (ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "")
        self.openAIBaseURL = UserDefaults.standard.string(forKey: "cluely.openAIBaseURL") ?? "https://api.openai.com/v1"
        
        Task {
            await refreshOllamaModels()
        }
    }
    
    func cancelGeneration() {
        activeTask?.cancel()
        activeTask = nil
        isStreaming = false
    }
    
    func refreshOllamaModels() async {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                if !names.isEmpty {
                    self.availableOllamaModels = [Self.smartAutoRouteTag] + names
                }
            }
        } catch {
            // Keep default fallback list if Ollama isn't running yet
        }
    }
    
    /// Dynamically selects the strongest installed local model for the current Copilot mode when `auto:smart-router` is enabled.
    func resolveBestLocalModel(for mode: CopilotMode, hasScreenshot: Bool) -> String {
        if selectedModel != Self.smartAutoRouteTag {
            return selectedModel
        }
        let installed = Set(availableOllamaModels)
        switch mode {
        case .codingSolver:
            if installed.contains("qwen3.6:27b-coding") { return "qwen3.6:27b-coding" }
            if installed.contains("qwen3-coder-64k:latest") { return "qwen3-coder-64k:latest" }
            if installed.contains("gemma4:26b") { return "gemma4:26b" }
            if installed.contains("hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M") { return "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M" }
            if installed.contains("gemma4:e4b") { return "gemma4:e4b" }
        case .systemDesign:
            if installed.contains("gemma4:26b") { return "gemma4:26b" }
            if installed.contains("hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M") { return "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M" }
            if installed.contains("qwen3-coder-64k:latest") { return "qwen3-coder-64k:latest" }
            if installed.contains("gemma4:e4b") { return "gemma4:e4b" }
        case .interviewCopilot, .generalAssistant:
            if installed.contains("gemma4:26b") { return "gemma4:26b" }
            if installed.contains("gemma4:e4b") { return "gemma4:e4b" }
            if hasScreenshot && installed.contains("qwen2.5vl-64k:latest") { return "qwen2.5vl-64k:latest" }
            if installed.contains("hf.co/unsloth/Qwen3-14B-128K-GGUF:UD-Q4_K_XL") { return "hf.co/unsloth/Qwen3-14B-128K-GGUF:UD-Q4_K_XL" }
            if installed.contains("qwen3-coder-64k:latest") { return "qwen3-coder-64k:latest" }
            if installed.contains("qwen3:4b-instruct") { return "qwen3:4b-instruct" }
        }
        return availableOllamaModels.first(where: { $0 != Self.smartAutoRouteTag }) ?? "gemma4:e4b"
    }
    
    /// Pulls any model directly from the Ollama registry with live streaming progress.
    func pullOllamaModel(_ modelTag: String) {
        guard !isPullingModel else { return }
        isPullingModel = true
        pullingModelName = modelTag
        pullProgressText = "Starting download for \(modelTag)..."
        pullProgressFraction = 0.02
        
        Task {
            defer {
                self.isPullingModel = false
            }
            guard let url = URL(string: "\(ollamaEndpoint)/api/pull") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["name": modelTag, "stream": true]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (bytes, _) = try await URLSession.shared.bytes(for: request)
                for try await line in bytes.lines {
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    let status = (json["status"] as? String) ?? "Downloading..."
                    if let completed = json["completed"] as? Double,
                       let total = json["total"] as? Double, total > 0 {
                        let frac = min(1.0, max(0.0, completed / total))
                        self.pullProgressFraction = frac
                        let pct = Int(frac * 100)
                        self.pullProgressText = "\(status) (\(pct)%)"
                    } else {
                        self.pullProgressText = status
                    }
                }
                await refreshOllamaModels()
                self.selectedModel = modelTag
                self.pullProgressText = "Installed \(modelTag) successfully!"
                self.pullProgressFraction = 1.0
            } catch {
                self.pullProgressText = "Failed to pull \(modelTag): \(error.localizedDescription)"
            }
        }
    }
    
    func generateStreamingResponse(
        mode: CopilotMode,
        systemPrompt: String,
        userPrompt: String,
        liveTranscript: String,
        screenOCR: String,
        screenshotBase64: String?
    ) {
        cancelGeneration()
        isStreaming = true
        errorMessage = nil
        currentResponse = ""
        
        var compositeUserMessage = ""
        if !liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            compositeUserMessage += "=== LIVE AUDIO TRANSCRIPT (RECENT) ===\n\(liveTranscript)\n\n"
        }
        if !screenOCR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            compositeUserMessage += "=== ACTIVE SCREEN OCR TEXT ===\n\(screenOCR)\n\n"
        }
        compositeUserMessage += "=== REQUEST ===\n\(userPrompt)"
        if fastDirectMode {
            compositeUserMessage += "\n\n/no_think"
        }
        
        activeTask = Task {
            do {
                switch provider {
                case .ollama:
                    let resolved = resolveBestLocalModel(for: mode, hasScreenshot: screenshotBase64 != nil)
                    self.activeResolvedModel = resolved
                    try await streamOllama(
                        model: resolved,
                        systemPrompt: systemPrompt,
                        userMessage: compositeUserMessage,
                        screenshotBase64: screenshotBase64
                    )
                case .gemini:
                    let modelName = selectedModel.starts(with: "gemini") ? selectedModel : "gemini-2.5-flash"
                    self.activeResolvedModel = modelName
                    try await requestGemini(
                        modelName: modelName,
                        systemPrompt: systemPrompt,
                        userMessage: compositeUserMessage,
                        screenshotBase64: screenshotBase64
                    )
                case .openai:
                    let modelName = (selectedModel.contains("gpt") || selectedModel.contains("o1") || selectedModel.contains("o3") || selectedModel.contains("llama")) ? selectedModel : "gpt-4o"
                    self.activeResolvedModel = modelName
                    try await streamOpenAI(
                        modelName: modelName,
                        systemPrompt: systemPrompt,
                        userMessage: compositeUserMessage,
                        screenshotBase64: screenshotBase64
                    )
                }
            } catch is CancellationError {
                // Cancelled intentionally
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isStreaming = false
        }
    }
    
    // MARK: - Local Ollama Streaming
    
    private func streamOllama(
        model: String,
        systemPrompt: String,
        userMessage: String,
        screenshotBase64: String?
    ) async throws {
        guard let url = URL(string: "\(ollamaEndpoint)/api/chat") else {
            throw NSError(domain: "LLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama endpoint URL"])
        }
        
        var userDict: [String: Any] = [
            "role": "user",
            "content": userMessage
        ]
        
        // Attach raw base64 image for multimodal vision models (Gemma 4, Qwen-VL, Qwen3.5/3.6, LLaVA)
        let lowerModel = model.lowercased()
        if let b64 = screenshotBase64, !b64.isEmpty,
           (lowerModel.contains("gemma4") || lowerModel.contains("gemma3") || lowerModel.contains("vl") || lowerModel.contains("qwen3.5") || lowerModel.contains("vision") || lowerModel.contains("llava")) {
            userDict["images"] = [b64]
        }
        
        var payload: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                userDict
            ],
            "options": [
                "temperature": 0.25
            ]
        ]
        if fastDirectMode {
            payload["think"] = false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Ollama returned HTTP \(httpResponse.statusCode) for model `\(model)`. Ensure Ollama is running (`ollama serve`)."
            ])
        }
        
        var insideThinkBlock = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let message = json["message"] as? [String: Any],
               let chunk = message["content"] as? String {
                if fastDirectMode {
                    // Filter out raw <think>...</think> wrappers if a model still emits them
                    if chunk.contains("<think>") {
                        insideThinkBlock = true
                        continue
                    }
                    if chunk.contains("</think>") {
                        insideThinkBlock = false
                        continue
                    }
                    if insideThinkBlock {
                        continue
                    }
                }
                self.currentResponse += chunk
            }
        }
    }
    
    // MARK: - Google Gemini API
    
    private func requestGemini(
        modelName: String,
        systemPrompt: String,
        userMessage: String,
        screenshotBase64: String?
    ) async throws {
        let key = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini API Key. Open Settings tab in the HUD to enter your key or switch to Local Ollama."])
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(key)") else {
            throw NSError(domain: "LLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }
        
        var parts: [[String: Any]] = [["text": userMessage]]
        if let b64 = screenshotBase64, !b64.isEmpty {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": b64
                ]
            ])
        }
        
        let payload: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["temperature": 0.25]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini HTTP \(httpResponse.statusCode): \(errBody)"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let resParts = content["parts"] as? [[String: Any]] {
            let combined = resParts.compactMap { $0["text"] as? String }.joined()
            self.currentResponse = combined
        }
    }
    
    // MARK: - OpenAI / Compatible Streaming API
    
    private func streamOpenAI(
        modelName: String,
        systemPrompt: String,
        userMessage: String,
        screenshotBase64: String?
    ) async throws {
        let key = openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API Key. Open Settings tab in the HUD to enter your key or switch to Local Ollama."])
        }
        guard let url = URL(string: "\(openAIBaseURL)/chat/completions") else {
            throw NSError(domain: "LLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL"])
        }
        
        var userContent: Any = userMessage
        if let b64 = screenshotBase64, !b64.isEmpty {
            userContent = [
                ["type": "text", "text": userMessage],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
            ]
        }
        
        let payload: [String: Any] = [
            "model": modelName,
            "stream": true,
            "temperature": 0.25,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "LLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned HTTP \(httpResponse.statusCode)"])
        }
        
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonStr == "[DONE]" { break }
            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }
            self.currentResponse += content
        }
    }
}
