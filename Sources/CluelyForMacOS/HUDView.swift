import SwiftUI
import AppKit

struct HUDView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var audioManager: AudioTranscriptionManager
    @ObservedObject var contextManager: ContextManager
    @ObservedObject var llmService: LLMService
    
    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self.audioManager = viewModel.audioManager
        self.contextManager = viewModel.contextManager
        self.llmService = viewModel.llmService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topHeaderBar
            Divider().background(Color.white.opacity(0.12))
            tabSelectorBar
            Divider().background(Color.white.opacity(0.10))
            
            Group {
                switch viewModel.selectedTab {
                case .copilot:
                    copilotTabView
                case .transcript:
                    transcriptAndOCRTabView
                case .context:
                    contextTabView
                case .settings:
                    modelsAndSettingsTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider().background(Color.white.opacity(0.10))
            bottomStatusBar
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.10).opacity(viewModel.hudOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    viewModel.isStealthMode ? Color.emeraldGreen.opacity(0.55) : Color.orange.opacity(0.55),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
    
    // MARK: - Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 8) {
            // Stealth badge toggle
            Button {
                viewModel.isStealthMode.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isStealthMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(viewModel.isStealthMode ? "STEALTH ON" : "VISIBLE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewModel.isStealthMode ? Color.emeraldGreen.opacity(0.22) : Color.orange.opacity(0.25))
                )
                .foregroundColor(viewModel.isStealthMode ? Color.emeraldGreen : Color.orange)
            }
            .buttonStyle(.plain)
            .help("ToggleNSWindow.SharingType.none (Invisible to Zoom, Meet, Teams, OBS & screenshots)")
            
            // Live Audio Listen Pill
            Button {
                audioManager.toggleListening()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(audioManager.isListening ? Color.red : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(audioManager.isListening ? "LISTENING" : "MIC IDLE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(audioManager.isListening ? Color.red.opacity(0.22) : Color.white.opacity(0.08))
                )
                .foregroundColor(audioManager.isListening ? Color.red.opacity(0.95) : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle System + Microphone Live Transcription (⌘⇧M)")
            
            // Ghost Click-Through Pill
            Button {
                viewModel.isGhostClickThrough.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 10))
                    Text(viewModel.isGhostClickThrough ? "GHOST ON (⌘⇧G)" : "GHOST")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewModel.isGhostClickThrough ? Color.purple.opacity(0.30) : Color.white.opacity(0.08))
                )
                .foregroundColor(viewModel.isGhostClickThrough ? Color.purple : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Click-Through Ghost Mode (⌘⇧G)")
            
            Spacer()
            
            // Copilot Mode Picker
            Menu {
                ForEach(CopilotMode.allCases) { mode in
                    Button {
                        contextManager.mode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: contextManager.mode.iconName)
                        .font(.system(size: 11))
                    Text(contextManager.mode.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.blue.opacity(0.22)))
                .foregroundColor(.cyan)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Opacity mini slider
            HStack(spacing: 4) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.hudOpacity, in: 0.45...0.98)
                    .frame(width: 58)
            }
            .help("Adjust HUD translucency")
            
            // Hide HUD button
            Button {
                viewModel.onToggleHUDVisibility?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hide HUD (Press ⌘⇧H to bring back anytime)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab Selector Bar
    
    private var tabSelectorBar: some View {
        HStack(spacing: 6) {
            ForEach(HUDTab.allCases) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(viewModel.selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedTab == tab ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Active model indicator badge
            Button {
                viewModel.selectedTab = .settings
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text(shortModelDisplayName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
    
    private var shortModelDisplayName: String {
        if llmService.selectedModel == LLMService.smartAutoRouteTag {
            if !llmService.activeResolvedModel.isEmpty {
                return "Auto → \(shortenTag(llmService.activeResolvedModel))"
            }
            return "Smart Auto-Router"
        }
        return shortenTag(llmService.selectedModel)
    }
    
    private func shortenTag(_ tag: String) -> String {
        if tag.contains("Qwen3.8-27B") { return "Qwen3.8-27B" }
        if tag.contains("Qwen3-14B") { return "Qwen3-14B" }
        if tag.contains("qwen3-coder-64k") { return "Qwen3-Coder-64K" }
        if tag.contains("qwen2.5vl") { return "Qwen2.5-VL" }
        return tag
    }
    
    // MARK: - Tab 1: Copilot View
    
    private var copilotTabView: some View {
        VStack(spacing: 8) {
            // Quick Action Buttons Row
            HStack(spacing: 8) {
                Button {
                    viewModel.askAI(captureFreshScreenIfNeeded: false)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Ask AI")
                            .fontWeight(.semibold)
                        Text("⌘⇧Space")
                            .font(.system(size: 10, design: .monospaced))
                            .opacity(0.75)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    viewModel.snapScreenAndSolve()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "viewfinder.rectangular")
                        Text("Snap & Solve Code")
                            .fontWeight(.semibold)
                        Text("⌘⇧S")
                            .font(.system(size: 10, design: .monospaced))
                            .opacity(0.75)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.emeraldGreen.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.emeraldGreen.opacity(0.55), lineWidth: 1)
                    )
                    .foregroundColor(Color.emeraldGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if llmService.isStreaming {
                    Button {
                        llmService.cancelGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.25))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                } else if !llmService.currentResponse.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(llmService.currentResponse, forType: .string)
                        viewModel.statusBanner = "Copied full response to clipboard"
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.09))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        viewModel.clearSession()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.white.opacity(0.07))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .help("Clear session (⌘⇧K)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Prompt Input Bar
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                TextField("Ask a question, paste a prompt, or press Return...", text: $viewModel.customPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .onSubmit {
                        viewModel.askAI(captureFreshScreenIfNeeded: false)
                    }
                if !viewModel.customPrompt.isEmpty {
                    Button {
                        viewModel.customPrompt = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
            .padding(.horizontal, 12)
            
            // Live Audio Mini Ticker (if listening or has recent transcript)
            if audioManager.isListening || !audioManager.systemLivePartial.isEmpty || !audioManager.micLivePartial.isEmpty {
                liveAudioMiniStrip
                    .padding(.horizontal, 12)
            }
            
            // Main Response Output Area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let error = llmService.errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.14)))
                        }
                        
                        if llmService.currentResponse.isEmpty && !llmService.isStreaming {
                            emptyCopilotPlaceholder
                        } else {
                            FormattedResponseView(
                                markdownText: llmService.currentResponse,
                                onCopyCode: { code in
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(code, forType: .string)
                                    viewModel.statusBanner = "Copied code block to clipboard!"
                                }
                            )
                        }
                        
                        Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                    }
                    .padding(12)
                }
                .onChange(of: llmService.currentResponse) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var liveAudioMiniStrip: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !audioManager.systemLivePartial.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("INTERVIEWER:")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text(audioManager.systemLivePartial)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            if !audioManager.micLivePartial.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("YOU:")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(.emeraldGreen)
                    Text(audioManager.micLivePartial)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            if audioManager.systemLivePartial.isEmpty && audioManager.micLivePartial.isEmpty,
               let last = audioManager.segments.last {
                HStack(alignment: .top, spacing: 6) {
                    Text("\(last.speaker.uppercased()):")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(last.text)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }
    
    private var emptyCopilotPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 18))
                    .foregroundColor(.emeraldGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Cluely HUD Ready")
                        .font(.system(size: 13, weight: .bold))
                    Text("Invisible to Zoom, Google Meet, Microsoft Teams, and Screenshots (`sharingType = .none`).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    hotkeyBadge("⌘⇧Space")
                    Text("Instant AI Answer (uses live audio transcript + your resume/projects)")
                        .font(.system(size: 11.5))
                }
                GridRow {
                    hotkeyBadge("⌘⇧S")
                    Text("Snap Screen & Solve Code/OA (Vision OCR + Optimal \(contextManager.preferredCodingLanguage) Solution)")
                        .font(.system(size: 11.5))
                }
                GridRow {
                    hotkeyBadge("⌘⇧M")
                    Text("Toggle Real-Time System + Mic Audio Transcription")
                        .font(.system(size: 11.5))
                }
                GridRow {
                    hotkeyBadge("⌘⇧G")
                    Text("Toggle Ghost Click-Through Mode (mouse clicks pass right through HUD)")
                        .font(.system(size: 11.5))
                }
                GridRow {
                    hotkeyBadge("⌘⇧H")
                    Text("Instantly Hide / Show HUD Window anywhere")
                        .font(.system(size: 11.5))
                }
                GridRow {
                    hotkeyBadge("⌘⇧Arrows")
                    Text("Move HUD Window across screen without touching the mouse")
                        .font(.system(size: 11.5))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
    
    private func hotkeyBadge(_ keys: String) -> some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
            .foregroundColor(.cyan)
    }
    
    // MARK: - Tab 2: Live Audio & Screen OCR View
    
    private var transcriptAndOCRTabView: some View {
        VStack(spacing: 10) {
            // Audio Transcript Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Real-Time Audio Transcript (System + Mic)", systemImage: "waveform.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                    Spacer()
                    Button(audioManager.isListening ? "Pause Audio" : "Start Listening") {
                        audioManager.toggleListening()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(audioManager.isListening ? .red : .blue)
                    .controlSize(.small)
                    
                    Button("Clear") {
                        audioManager.clearTranscript()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if audioManager.segments.isEmpty && audioManager.systemLivePartial.isEmpty && audioManager.micLivePartial.isEmpty {
                            Text("No audio transcribed yet. Press ⌘⇧M or click 'Start Listening' to capture both system meeting audio and your microphone.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(audioManager.segments) { seg in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(seg.speaker == "Interviewer" ? "INTERVIEWER:" : "YOU:")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(seg.speaker == "Interviewer" ? .cyan : .emeraldGreen)
                                        .frame(width: 92, alignment: .leading)
                                    Text(seg.text)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.92))
                                        .textSelection(.enabled)
                                }
                            }
                            if !audioManager.systemLivePartial.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("INTERVIEWER:")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                        .frame(width: 92, alignment: .leading)
                                    Text(audioManager.systemLivePartial)
                                        .font(.system(size: 12))
                                        .italic()
                                        .foregroundColor(.cyan.opacity(0.9))
                                }
                            }
                            if !audioManager.micLivePartial.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("YOU:")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(.emeraldGreen)
                                        .frame(width: 92, alignment: .leading)
                                    Text(audioManager.micLivePartial)
                                        .font(.system(size: 12))
                                        .italic()
                                        .foregroundColor(.emeraldGreen.opacity(0.9))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.28)))
            }
            .frame(maxHeight: .infinity)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Screen Capture + Apple Vision OCR Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("On-Demand Screen Capture & Apple Vision OCR", systemImage: "text.viewfinder")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.emeraldGreen)
                    Spacer()
                    Button {
                        Task { await viewModel.captureScreenSilently() }
                    } label: {
                        Label(viewModel.isCapturingScreen ? "Capturing..." : "Capture Screen Now", systemImage: "camera.viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.emeraldGreen)
                    .controlSize(.small)
                }
                
                if let snap = viewModel.latestSnapshot {
                    HStack(alignment: .top, spacing: 10) {
                        Image(nsImage: snap.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        
                        ScrollView {
                            Text(snap.extractedText.isEmpty ? "(No text detected on screen)" : snap.extractedText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.88))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.3)))
                    }
                    .frame(height: 100)
                } else {
                    Text("Press ⌘⇧S or click 'Capture Screen Now' to silently grab the active display (excluding this HUD) and extract all visible code & text via Apple Vision.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Tab 3: Custom Context Injection View
    
    private var contextTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Preferred Coding Language:", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .bold))
                    Picker("", selection: $contextManager.preferredCodingLanguage) {
                        Text("Python 3").tag("Python 3")
                        Text("Java").tag("Java")
                        Text("C++").tag("C++")
                        Text("TypeScript / JS").tag("TypeScript")
                        Text("Go").tag("Go")
                        Text("SQL (PostgreSQL)").tag("PostgreSQL")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    
                    Spacer()
                    
                    Button("Reset Profile to Default") {
                        contextManager.resetToDefaultProfile()
                        viewModel.statusBanner = "Reset profile context to Ariq's canonical background"
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Role / Job Description / Specific Meeting Notes")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.cyan)
                    TextEditor(text: $contextManager.sessionNotesOrJobDescription)
                        .font(.system(size: 11.5, design: .monospaced))
                        .frame(height: 85)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Candidate Resume, Experience & Project Bank (Injected into every prompt)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.emeraldGreen)
                    TextEditor(text: $contextManager.personalProfileContext)
                        .font(.system(size: 11.5, design: .monospaced))
                        .frame(height: 190)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Tab 4: Models & Settings View
    
    private var modelsAndSettingsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Provider & Active Model
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Backend:")
                            .font(.system(size: 12, weight: .bold))
                        Picker("", selection: $llmService.provider) {
                            ForEach(LLMProvider.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .labelsHidden()
                        
                        Spacer()
                        
                        Button {
                            Task { await llmService.refreshOllamaModels() }
                        } label: {
                            Label("Refresh Ollama", systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if llmService.provider == .ollama {
                        HStack {
                            Text("Active Model:")
                                .font(.system(size: 12, weight: .bold))
                            Picker("", selection: $llmService.selectedModel) {
                               ForEach(llmService.availableOllamaModels, id: \.self) { model in
                                    if model == LLMService.smartAutoRouteTag {
                                        Text("⚡ Smart Auto-Router (Best Model per Task)").tag(model)
                                    } else {
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            .labelsHidden()
                        }
                        
                        Toggle(isOn: $llmService.fastDirectMode) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Fast Direct Mode (Skip <think> Latency)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text("Streams the visible answer immediately (<250ms first token) without waiting on internal thinking chains.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    } else if llmService.provider == .gemini {
                        HStack {
                            Text("Gemini API Key:")
                                .font(.system(size: 11.5, weight: .semibold))
                            SecureField("Paste AI Studio Key (AIza...)", text: $llmService.geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                            TextField("Model (e.g. gemini-2.5-flash)", text: $llmService.selectedModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 155)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Base URL:")
                                    .font(.system(size: 11.5, weight: .semibold))
                                TextField("https://api.openai.com/v1 or https://api.groq.com/openai/v1", text: $llmService.openAIBaseURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Text("API Key:")
                                    .font(.system(size: 11.5, weight: .semibold))
                                SecureField("sk-... or gsk_...", text: $llmService.openAIApiKey)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Model (e.g. gpt-4o)", text: $llmService.selectedModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 145)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                
                // Pull progress bar if downloading
                if llmService.isPullingModel || !llmService.pullProgressText.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(llmService.pullProgressText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                            Spacer()
                        }
                        if llmService.isPullingModel {
                            ProgressView(value: llmService.pullProgressFraction)
                                .tint(.cyan)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.12)))
                }
                
                // Top Free Local Models Hub
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best Free On-Device Models (Apple Silicon M4 Pro Optimized)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.emeraldGreen)
                    
                    ForEach(LLMService.recommendedModels) { rec in
                        let isInstalled = llmService.availableOllamaModels.contains(rec.tag)
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(rec.title)
                                        .font(.system(size: 12, weight: .bold))
                                    Text(isInstalled ? "INSTALLED" : rec.badge)
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(isInstalled ? Color.emeraldGreen.opacity(0.25) : Color.blue.opacity(0.25)))
                                        .foregroundColor(isInstalled ? Color.emeraldGreen : .cyan)
                                }
                                Text(rec.description)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isInstalled {
                                Button(llmService.selectedModel == rec.tag ? "Active" : "Use") {
                                    llmService.provider = .ollama
                                    llmService.selectedModel = rec.tag
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(llmService.selectedModel == rec.tag ? .emeraldGreen : .blue)
                                .controlSize(.small)
                            } else {
                                Button("1-Click Pull") {
                                    llmService.pullOllamaModel(rec.tag)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(llmService.isPullingModel)
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.26)))
                    }
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Bottom Status Bar
    
    private var bottomStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(llmService.isStreaming ? Color.cyan : Color.emeraldGreen)
                .frame(width: 6, height: 6)
            Text(viewModel.statusBanner)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Text("⌘⇧Space Ask · ⌘⇧S Snap · ⌘⇧M Mic · ⌘⇧G Ghost · ⌘⇧H Hide")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Formatted Markdown + Code Block Renderer

struct ResponseBlock: Identifiable {
    let id = UUID()
    let isCode: Bool
    let language: String
    let content: String
}

struct FormattedResponseView: View {
    let markdownText: String
    let onCopyCode: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parseBlocks(from: markdownText)) { block in
                if block.isCode {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(block.language.isEmpty ? "CODE" : block.language.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            Spacer()
                            Button {
                                onCopyCode(block.content)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Code")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.14)))
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(block.content)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(red: 0.88, green: 0.95, blue: 1.0))
                                .textSelection(.enabled)
                                .padding(10)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                } else {
                    Text(block.content)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func parseBlocks(from text: String) -> [ResponseBlock] {
        var blocks: [ResponseBlock] = []
        let lines = text.components(separatedBy: "\n")
        var inCode = false
        var currentLang = ""
        var currentBuffer: [String] = []
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    blocks.append(ResponseBlock(
                        isCode: true,
                        language: currentLang,
                        content: currentBuffer.joined(separator: "\n")
                    ))
                    currentBuffer.removeAll()
                    currentLang = ""
                    inCode = false
                } else {
                    let prose = currentBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !prose.isEmpty {
                        blocks.append(ResponseBlock(isCode: false, language: "", content: prose))
                    }
                    currentBuffer.removeAll()
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    currentLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    inCode = true
                }
            } else {
                currentBuffer.append(line)
            }
        }
        
        let remaining = currentBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            blocks.append(ResponseBlock(isCode: inCode, language: currentLang, content: remaining))
        }
        return blocks
    }
}

extension Color {
    static let emeraldGreen = Color(red: 0.16, green: 0.85, blue: 0.56)
}
