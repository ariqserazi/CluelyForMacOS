import AppKit
import ScreenCaptureKit
import Vision

struct ScreenSnapshot {
    let image: NSImage
    let base64JPEG: String
    let extractedText: String
    let timestamp: Date
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    private init() {}
    
    /// Captures the main display using ScreenCaptureKit (excluding CluelyForMacOS itself)
    /// and immediately performs on-device Apple Vision OCR + Base64 JPEG encoding.
    func captureScreenAndRecognizeText() async throws -> ScreenSnapshot {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = shareableContent.displays.first else {
            throw NSError(domain: "ScreenCaptureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active display found."])
        }
        
        // Exclude our own process so the HUD never appears in the captured frame
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let excludedApps = shareableContent.applications.filter { $0.processID == currentPID }
        
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )
        
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.showsCursor = false
        config.capturesAudio = false
        
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))
        let ocrText = await recognizeText(from: cgImage)
        let base64 = encodeJPEG(from: cgImage, maxDimension: 1600)
        
        return ScreenSnapshot(
            image: nsImage,
            base64JPEG: base64,
            extractedText: ocrText,
            timestamp: Date()
        )
    }
    
    /// Runs high-accuracy Apple Vision OCR (`VNRecognizeTextRequest`) on the captured `CGImage`.
    private func recognizeText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Sort observations top-to-bottom (Vision coordinates have origin at bottom-left)
                let sorted = observations.sorted { a, b in
                    let ay = a.boundingBox.origin.y
                    let by = b.boundingBox.origin.y
                    if abs(ay - by) > 0.012 {
                        return ay > by
                    }
                    return a.boundingBox.origin.x < b.boundingBox.origin.x
                }
                
                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    /// Encodes `CGImage` to compressed JPEG Base64 string for multimodal LLM requests.
    private func encodeJPEG(from cgImage: CGImage, maxDimension: CGFloat) -> String {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let scale = min(1.0, maxDimension / max(width, height))
        let targetSize = NSSize(width: round(width * scale), height: round(height * scale))
        
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            .draw(in: NSRect(origin: .zero, size: targetSize))
        resizedImage.unlockFocus()
        
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) else {
            return ""
        }
        return jpegData.base64EncodedString()
    }
}
