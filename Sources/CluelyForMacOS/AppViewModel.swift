import AppKit
import SwiftUI

enum HUDTab: String, CaseIterable, Identifiable {
    case copilot    = "Copilot"
    case transcript = "Audio & OCR"
    case context    = "Context"
    case settings   = "Models"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .copilot:    return "sparkles"
        case .transcript: return "waveform"
        case .context:    return "person.text.rectangle.fill"
        case .settings:   return "cpu.fill"
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedTab: HUDTab = .copilot
    @Published var isStealthMode: Bool = true {
        didSet { onStealthModeChanged?(isStealthMode) }
    }
    @Published var isGhostClickThrough: Bool = false {
        didSet { onGhostModeChanged?(isGhostClickThrough) }
    }
    @Published var hudOpacity: Double = 0.94
    @Published var customPrompt: String = ""
    @Published var latestSnapshot: ScreenSnapshot? = nil
    @Published var isCapturingScreen: Bool = false
    @Published var statusBanner: String = "Stealth Active — Hidden from Zoom, Meet, Teams & Screenshots"
    
    let audioManager = AudioTranscriptionManager()
    let contextManager = ContextManager()
    let llmService = LLMService()
    
    var onStealthModeChanged: ((Bool) -> Void)?
    var onGhostModeChanged: ((Bool) -> Void)?
    var onToggleHUDVisibility: (() -> Void)?
    var onNudgeWindow: ((CGFloat, CGFloat) -> Void)?
    
    /// Triggered by `Cmd + Shift + Space` or "Ask AI" button.
    func askAI(captureFreshScreenIfNeeded: Bool = false) {
        selectedTab = .copilot
        Task {
            if captureFreshScreenIfNeeded || latestSnapshot == nil {
                await captureScreenSilently()
            }
            
            let transcript = audioManager.formattedTranscript()
            let ocrText = latestSnapshot?.extractedText ?? ""
            let b64 = latestSnapshot?.base64JPEG
            
            let userQuery: String
            let trimmedPrompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPrompt.isEmpty {
                userQuery = trimmedPrompt
                customPrompt = ""
            } else if !transcript.isEmpty {
                userQuery = "Based on the most recent question or statement in the live interview transcript (and any visible screen context), provide a clear, concise, direct answer and talking points I can speak right now."
            } else if !ocrText.isEmpty {
                userQuery = "Analyze the active screen content and provide the direct answer, code solution, or key talking points."
            } else {
                userQuery = "Give me a crisp 30-second elevator pitch and 3 key talking points tailored to my profile and projects."
            }
            
            statusBanner = "Streaming response..."
            llmService.generateStreamingResponse(
                mode: contextManager.mode,
                systemPrompt: contextManager.buildSystemPrompt(),
                userPrompt: userQuery,
                liveTranscript: transcript,
                screenOCR: ocrText,
                screenshotBase64: b64
            )
        }
    }
    
    /// Triggered by `Cmd + Shift + S` or "Snap & Solve" button.
    func snapScreenAndSolve() {
        selectedTab = .copilot
        Task {
            await captureScreenSilently()
            let transcript = audioManager.formattedTranscript()
            let ocrText = latestSnapshot?.extractedText ?? ""
            let b64 = latestSnapshot?.base64JPEG
            
            let trimmedPrompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let userQuery: String
            if !trimmedPrompt.isEmpty {
                userQuery = trimmedPrompt
                customPrompt = ""
            } else {
                userQuery = """
                Examine the captured screen text/image carefully.
                If there is a coding problem, algorithm question, or bug on screen:
                1. State the optimal approach in 2-3 crisp bullets.
                2. Write the complete, clean, bug-free solution in \(contextManager.preferredCodingLanguage).
                3. State exact Time and Space Complexity.
                If it is a multiple-choice question, system design diagram, or technical prompt, give the exact answer and concise explanation immediately.
                """
            }
            
            statusBanner = "Screen captured (\(ocrText.count) chars OCR) — solving..."
            llmService.generateStreamingResponse(
                mode: .codingSolver,
                systemPrompt: contextManager.buildSystemPrompt(),
                userPrompt: userQuery,
                liveTranscript: transcript,
                screenOCR: ocrText,
                screenshotBase64: b64
            )
        }
    }
    
    func captureScreenSilently() async {
        isCapturingScreen = true
        statusBanner = "Capturing screen & running Vision OCR..."
        do {
            let snap = try await ScreenCaptureManager.shared.captureScreenAndRecognizeText()
            self.latestSnapshot = snap
            statusBanner = "Screen captured (\(snap.extractedText.count) chars extracted via Vision OCR)"
        } catch {
            statusBanner = "Screen capture failed — grant Screen Recording permission in System Settings"
        }
        isCapturingScreen = false
    }
    
    func clearSession() {
        llmService.cancelGeneration()
        llmService.currentResponse = ""
        llmService.errorMessage = nil
        latestSnapshot = nil
        audioManager.clearTranscript()
        statusBanner = "Session cleared"
    }
}
