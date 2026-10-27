import Foundation
import AVFoundation
import Speech
import ScreenCaptureKit
import CoreMedia

struct TranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    let speaker: String // "Interviewer (System)" or "You (Mic)"
    var text: String
    let timestamp: Date
}

@MainActor
final class AudioTranscriptionManager: NSObject, ObservableObject {
    @Published var isListening: Bool = false
    @Published var systemLivePartial: String = ""
    @Published var micLivePartial: String = ""
    @Published var segments: [TranscriptSegment] = []
    @Published var statusMessage: String = "Audio idle"
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    // Microphone pipeline
    private var audioEngine: AVAudioEngine?
    private var micRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var micRecognitionTask: SFSpeechRecognitionTask?
    
    // System audio pipeline (ScreenCaptureKit)
    private var scStream: SCStream?
    private var systemAudioOutput: SystemAudioStreamOutput?
    private var systemRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var systemRecognitionTask: SFSpeechRecognitionTask?
    
    private let audioQueue = DispatchQueue(label: "com.ariqserazi.cluely.systemaudio", qos: .userInteractive)
    
    override init() {
        super.init()
    }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            Task {
                await startListening()
            }
        }
    }
    
    func startListening() async {
        guard !isListening else { return }
        
        let speechAuthorized = await requestSpeechPermission()
        guard speechAuthorized else {
            statusMessage = "Speech Recognition permission needed in System Settings > Privacy"
            return
        }
        
        let micAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        
        isListening = true
        statusMessage = "Listening (System + Mic)..."
        
        if micAuthorized {
            startMicrophoneTranscription()
        }
        
        await startSystemAudioTranscription()
    }
    
    func stopListening() {
        isListening = false
        statusMessage = "Audio paused"
        
        // Commit any remaining partials
        commitPartialIfNeeded(speaker: "Interviewer", partial: &systemLivePartial)
        commitPartialIfNeeded(speaker: "You", partial: &micLivePartial)
        
        stopMicrophoneTranscription()
        Task {
            await stopSystemAudioTranscription()
        }
    }
    
    func clearTranscript() {
        segments.removeAll()
        systemLivePartial = ""
        micLivePartial = ""
    }
    
    /// Returns a formatted rolling transcript string for LLM context injection.
    func formattedTranscript(maxCharacters: Int = 5000) -> String {
        var lines: [String] = segments.map { segment in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return "[\(formatter.string(from: segment.timestamp))] \(segment.speaker): \(segment.text)"
        }
        if !systemLivePartial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("[Live] Interviewer: \(systemLivePartial)")
        }
        if !micLivePartial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("[Live] You: \(micLivePartial)")
        }
        let joined = lines.joined(separator: "\n")
        if joined.count > maxCharacters {
            return String(joined.suffix(maxCharacters))
        }
        return joined
    }
    
    // MARK: - Permissions
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Microphone Transcription
    
    private func startMicrophoneTranscription() {
        stopMicrophoneTranscription()
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else { return }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        
        do {
            engine.prepare()
            try engine.start()
            self.audioEngine = engine
            self.micRecognitionRequest = request
            
            self.micRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                Task { @MainActor in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        self.micLivePartial = text
                        if result.isFinal {
                            self.commitPartialIfNeeded(speaker: "You", partial: &self.micLivePartial)
                        }
                    }
                    if error != nil && self.isListening {
                        self.commitPartialIfNeeded(speaker: "You", partial: &self.micLivePartial)
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        if self.isListening {
                            self.startMicrophoneTranscription()
                        }
                    }
                }
            }
        } catch {
            statusMessage = "Mic error: \(error.localizedDescription)"
        }
    }
    
    private func stopMicrophoneTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        micRecognitionRequest?.endAudio()
        micRecognitionRequest = nil
        micRecognitionTask?.cancel()
        micRecognitionTask = nil
    }
    
    // MARK: - System Audio Transcription (ScreenCaptureKit)
    
    private func startSystemAudioTranscription() async {
        await stopSystemAudioTranscription()
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 16000
            config.channelCount = 1
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if #available(macOS 13.0, *) {
                request.addsPunctuation = true
            }
            self.systemRecognitionRequest = request
            
            let outputHandler = SystemAudioStreamOutput { [weak self] sampleBuffer in
                self?.systemRecognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
            }
            self.systemAudioOutput = outputHandler
            
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(outputHandler, type: .audio, sampleHandlerQueue: audioQueue)
            try await stream.startCapture()
            self.scStream = stream
            
            startSystemRecognitionTask(with: recognizer, request: request)
        } catch {
            statusMessage = "Mic active (Grant Screen Recording for System Audio)"
        }
    }
    
    private func startSystemRecognitionTask(with recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest) {
        self.systemRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.systemLivePartial = text
                    if result.isFinal {
                        self.commitPartialIfNeeded(speaker: "Interviewer", partial: &self.systemLivePartial)
                    }
                }
                if error != nil && self.isListening {
                    self.commitPartialIfNeeded(speaker: "Interviewer", partial: &self.systemLivePartial)
                    // Restart recognition request on existing SCStream
                    let newRequest = SFSpeechAudioBufferRecognitionRequest()
                    newRequest.shouldReportPartialResults = true
                    if #available(macOS 13.0, *) {
                        newRequest.addsPunctuation = true
                    }
                    self.systemRecognitionRequest = newRequest
                    if let recognizer = self.speechRecognizer {
                        self.startSystemRecognitionTask(with: recognizer, request: newRequest)
                    }
                }
            }
        }
    }
    
    private func stopSystemAudioTranscription() async {
        if let stream = scStream {
            try? await stream.stopCapture()
        }
        scStream = nil
        systemAudioOutput = nil
        systemRecognitionRequest?.endAudio()
        systemRecognitionRequest = nil
        systemRecognitionTask?.cancel()
        systemRecognitionTask = nil
    }
    
    private func commitPartialIfNeeded(speaker: String, partial: inout String) {
        let trimmed = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        segments.append(TranscriptSegment(speaker: speaker, text: trimmed, timestamp: Date()))
        if segments.count > 60 {
            segments.removeFirst(segments.count - 60)
        }
        partial = ""
    }
}

private final class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private let onAudioBuffer: (CMSampleBuffer) -> Void
    
    init(onAudioBuffer: @escaping (CMSampleBuffer) -> Void) {
        self.onAudioBuffer = onAudioBuffer
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        onAudioBuffer(sampleBuffer)
    }
}
