import AppKit
import SwiftUI

/// A custom floating, non-activating NSPanel that hides itself from screen capture,
/// screen sharing (Zoom, Meet, Teams, WebEx, OBS), and system screenshots via `sharingType = .none`.
final class StealthPanel: NSPanel {
    
    override var canBecomeKey: Bool {
        return !ignoresMouseEvents
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )
        
        configureStealthWindow()
    }
    
    private func configureStealthWindow() {
        // Core Cluely mechanism: exclude window buffer from WindowServer capture streams
        self.sharingType = .none
        
        // Float above all normal and full-screen windows
        self.level = .screenSaver
        
        // Appear on all Spaces/desktops, over full-screen apps, and excluded from Cmd+Tab / Expose cycle
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }
    
    /// Enables or disables screen-share stealth (`NSWindow.SharingType.none` vs `.readOnly`).
    func setStealthMode(_ enabled: Bool) {
        self.sharingType = enabled ? .none : .readOnly
    }
    
    /// Enables or disables Ghost Mode (mouse clicks pass straight through to underlying windows).
    func setGhostClickThrough(_ enabled: Bool) {
        self.ignoresMouseEvents = enabled
    }
    
    /// Moves the HUD panel on screen via keyboard shortcuts without touching the mouse.
    func nudge(dx: CGFloat, dy: CGFloat) {
        var frame = self.frame
        frame.origin.x += dx
        frame.origin.y += dy
        self.setFrame(frame, display: true, animate: true)
    }
}
