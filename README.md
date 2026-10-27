# CluelyForMacOS

A native, lightweight, screen-share-invisible AI Interview, Coding & Meeting Copilot for macOS built with **Swift, SwiftUI, AppKit (`NSPanel`), ScreenCaptureKit, Apple Vision, and Speech**.

Runs **100% free on-device** with Apple Silicon-optimized **Ollama** models (`gemma4:26b` MoE, `gemma4:e4b` Multimodal, `qwen3-coder-64k`, `Qwen3.8-27B`, `qwen3.6:27b-coding`), with optional support for **Google Gemini** and **OpenAI / Groq** APIs.

---

## Key Features

1. **Native Screen-Share Stealth (`NSWindow.SharingType.none`)**
   - Uses a custom borderless, non-activating `StealthPanel` (`NSPanel`) with `sharingType = .none`, `level = .screenSaver`, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`.
   - **Invisible** to Zoom, Google Meet, Microsoft Teams, WebEx, OBS, QuickTime recordings, and macOS screenshots.
   - Runs as an `.accessory` Menu Bar app (`LSUIElement = true`)—hidden from the Dock and `Cmd+Tab` application switcher, and never steals focus from your active IDE or browser.
   - Includes **Ghost Click-Through Mode (`⌘⇧G`)** (`ignoresMouseEvents = true`) so mouse clicks pass straight through the translucent HUD to the window underneath.

2. **Real-Time Dual-Stream Audio Transcription (System + Microphone)**
   - Captures **System / Meeting Audio** (Interviewer on Zoom/Meet/Browser) via `ScreenCaptureKit` (`SCStream`) and **Microphone Audio** via `AVAudioEngine`.
   - Streams both channels through on-device `SFSpeechRecognizer` into a rolling diarized transcript (`INTERVIEWER` vs `YOU`).

3. **On-Demand Screen & Code Capture (`⌘⇧S`)**
   - Silently captures the active display via `SCScreenshotManager` (automatically excluding the HUD itself).
   - Runs on-device **Apple Vision (`VNRecognizeTextRequest`)** in `<150ms` to extract all visible code, LeetCode/HackerRank problem prompts, and diagrams, and attaches the multimodal JPEG frame for Vision LLMs (`gemma4:26b`, `gemma4:e4b`, `qwen2.5vl`).

4. **Smart Multi-Model Local Router ($0/Token)**
   - Automatically routes requests to the best installed local model for each mode:
     - **Coding / OA Solver (`⌘⇧S`)** → `qwen3-coder-64k:latest` / `qwen3.6:27b-coding` / `gemma4:26b`
     - **System Design** → `gemma4:26b` / `Qwen3.8-27B`
     - **Live Interview Copilot (`⌘⇧Space`)** → `gemma4:26b` / `gemma4:e4b` (with Fast Direct Mode `"think": false` for `<250ms` time-to-first-token)
   - Includes a built-in **1-Click Model Puller** inside the HUD to download new models directly from Ollama with live progress bars.

5. **Custom Context Injection**
   - Pre-loaded with your candidate resume, work experience, and project bank, plus an editable **Target Job Description / Meeting Notes** drawer injected into every prompt.

---

## Global Hotkeys

| Shortcut | Action |
| :--- | :--- |
| **`⌘ + ⇧ + Space`** | **Ask AI Now** — Instant answer & talking points using live audio transcript + custom context |
| **`⌘ + ⇧ + S`** | **Snap & Solve Code** — Captures active screen, runs Apple Vision OCR + VLM, and streams optimal code solution + complexity |
| **`⌘ + ⇧ + M`** | **Toggle Audio Listening** — Starts/pauses real-time System + Microphone transcription |
| **`⌘ + ⇧ + G`** | **Toggle Ghost Click-Through** — Lets mouse clicks pass directly through the HUD |
| **`⌘ + ⇧ + H`** | **Hide / Show HUD** — Instantly hides or summons the overlay anywhere |
| **`⌘ + ⇧ + K`** | **Clear Session** — Resets current response, screen snapshot, and transcript |
| **`⌘ + ⇧ + Arrows`** | **Nudge HUD Position** — Moves the HUD window across the screen without touching the mouse |

---

## Build & Run

```bash
chmod +x build_app.sh
./build_app.sh
open CluelyForMacOS.app
```
