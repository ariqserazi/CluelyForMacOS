import Foundation

enum CopilotMode: String, CaseIterable, Identifiable {
    case interviewCopilot = "Interview Copilot"
    case codingSolver     = "Coding / OA Solver"
    case systemDesign     = "System Design"
    case generalAssistant = "Meeting Assistant"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .interviewCopilot: return "person.wave.2.fill"
        case .codingSolver:     return "chevron.left.forwardslash.chevron.right"
        case .systemDesign:     return "cpu.fill"
        case .generalAssistant: return "sparkles"
        }
    }
}

@MainActor
final class ContextManager: ObservableObject {
    @Published var mode: CopilotMode = .interviewCopilot
    @Published var personalProfileContext: String {
        didSet { UserDefaults.standard.set(personalProfileContext, forKey: "cluely.personalProfileContext") }
    }
    @Published var sessionNotesOrJobDescription: String {
        didSet { UserDefaults.standard.set(sessionNotesOrJobDescription, forKey: "cluely.sessionNotesOrJobDescription") }
    }
    @Published var preferredCodingLanguage: String {
        didSet { UserDefaults.standard.set(preferredCodingLanguage, forKey: "cluely.preferredCodingLanguage") }
    }
    
    init() {
        let savedProfile = UserDefaults.standard.string(forKey: "cluely.personalProfileContext")
        if let savedProfile = savedProfile, !savedProfile.isEmpty {
            self.personalProfileContext = savedProfile
        } else {
            self.personalProfileContext = Self.defaultCandidateContext()
        }
        
        self.sessionNotesOrJobDescription = UserDefaults.standard.string(forKey: "cluely.sessionNotesOrJobDescription") ?? ""
        self.preferredCodingLanguage = UserDefaults.standard.string(forKey: "cluely.preferredCodingLanguage") ?? "Python 3"
    }
    
    func resetToDefaultProfile() {
        self.personalProfileContext = Self.defaultCandidateContext()
    }
    
    func buildSystemPrompt() -> String {
        let modeInstructions: String
        switch mode {
        case .interviewCopilot:
            modeInstructions = """
            You are an elite, real-time invisible Interview Copilot assisting the candidate during a live technical or behavioral interview.
            - Provide an immediate, high-signal **Direct Answer / Talking Points** section first so the candidate can speak naturally right away.
            - Ground behavioral and experience answers strictly in the candidate's real background (Rutgers CS, Amin AI, TidaMed, AIJobAssistant, Trackwise, MediaWiki Bridge API).
            - If a coding or technical question is asked, give the crisp conceptual intuition first, followed by clean \(preferredCodingLanguage) code and Time/Space complexity.
            - Keep bullet points scannable at a glance.
            """
        case .codingSolver:
            modeInstructions = """
            You are an elite Competitive Programming & Online Assessment Coding Copilot.
            - Analyze the problem statement, constraints, and starter code from the screen OCR / image / prompt.
            - Provide:
              1. **Optimal Approach & Intuition** (2-3 concise bullets)
              2. **Complete, Production-Ready Solution in \(preferredCodingLanguage)** (handle all edge cases, exact method signature if visible)
              3. **Time & Space Complexity**
              4. **Quick Dry Run / Edge Cases**
            """
        case .systemDesign:
            modeInstructions = """
            You are a Principal Distributed Systems Architect guiding the candidate through a live System Design interview.
            - Structure your response clearly into:
              1. **Functional & Non-Functional Requirements + Scale Estimates**
              2. **High-Level Architecture & API Design (REST / gRPC)**
              3. **Data Model & Storage Choices (PostgreSQL, Redis, Kafka, etc.)**
              4. **Deep Dive: Bottlenecks, Sharding, Caching, Fault Tolerance**
            """
        case .generalAssistant:
            modeInstructions = """
            You are a real-time executive meeting & technical assistant.
            - Directly answer questions based on the live audio transcript, screen content, and custom notes.
            - Suggest 2-3 high-leverage follow-up questions or talking points when helpful.
            """
        }
        
        var fullPrompt = modeInstructions + "\n\n=== CANDIDATE PROFILE & PROJECT BANK ===\n" + personalProfileContext
        
        if !sessionNotesOrJobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullPrompt += "\n\n=== CURRENT INTERVIEW / JOB DESCRIPTION / CUSTOM NOTES ===\n" + sessionNotesOrJobDescription
        }
        
        return fullPrompt
    }
    
    static func defaultCandidateContext() -> String {
        return """
        CANDIDATE: Ariq Serazi
        Location: Piscataway, NJ (NYC Metro) | Citizenship: US Citizen (No visa sponsorship needed)
        Preferred Language: Python (also proficient in Java, JavaScript/TypeScript, Dart, SQL/PostgreSQL, C/C++)
        
        EDUCATION:
        - Rutgers University, New Brunswick:
          * M.S. in Computer Science (Sept 2026 – Projected May 2028)
          * B.S. in Computer Science (Sept 2020 – May 2024), GPA: 3.85 / 4.00
        
        WORK EXPERIENCE:
        1. Amin AI (Edison, NJ) — Cofounder and Automation Engineer (Oct 2025 – Present)
           - Built Python & FastAPI LLM/agentic workflows with strict Pydantic structured outputs, MediaWiki REST integrations, Docker, and GCP Gemini.
        2. TidaMed (Piscataway, NJ) — Software Engineer (Dec 2024 – Present)
           - Built full-stack healthcare & payment flows using Node.js, Express, Flutter, PostgreSQL, Stripe Checkout, and PayPal REST APIs with robust validation and error handling.
        3. Maryam and Fatima LLC (Whitehouse Station, NJ) — Software Engineer (Oct 2024 – July 2025)
           - Engineered serverless backends and cross-platform apps using Python, AWS Lambda, API Gateway, DynamoDB, and Flutter/Dart.
        
        FEATURED PROJECTS:
        1. AIJobAssistant (Autonomous Agentic Workflow & RPA Platform) | Python, Playwright, Ollama (qwen3:4b-instruct), macOS ScriptingBridge, GCP:
           - Architected a 5-worker parallel browser automation engine using modulo task partitioning and POSIX file locks (fcntl).
           - Integrated on-device local LLM (qwen3:4b-instruct via Ollama) for sub-second dynamic schema classification at $0/token.
           - Engineered OS-level IPC via macOS ScriptingBridge to extract real-time 2FA/OTP verification codes silently without stealing window focus.
        2. Trackwise (Distributed Real-Time Financial Tracker) | Python, gRPC, Protobuf, PostgreSQL, Docker, Flutter:
           - Built a real-time distributed expense tracker with sub-100ms synchronization and gRPC Protobuf contracts reducing payload size by 30% over JSON.
           - Designed PostgreSQL schemas with composite indexes and connection pooling for concurrent ledger consistency.
        3. MediaWiki Bridge API | Python, FastAPI, Docker, Pydantic, Model Context Protocol (MCP):
           - Designed a high-performance FastAPI service with Pydantic v2 validation and an MCP server adapter allowing autonomous AI agents to query canonical data as a structured tool.
        """
    }
}
