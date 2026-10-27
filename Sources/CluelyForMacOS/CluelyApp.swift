import AppKit
import SwiftUI

@main
struct CluelyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: StealthPanel!
    private var statusItem: NSStatusItem!
    private let viewModel = AppViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon and Cmd+Tab entry for true Cluely stealth
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBarItem()
        setupStealthHUDPanel()
        setupBindingsAndHotKeys()
    }
    
    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash.circle.fill", accessibilityDescription: "CluelyForMacOS")
            button.toolTip = "CluelyForMacOS (Stealth AI Copilot)"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle HUD Overlay (⌘⇧H)", action: #selector(toggleHUD), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Ask AI Now (⌘⇧Space)", action: #selector(triggerAskAI), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Screen & Solve Code (⌘⇧S)", action: #selector(triggerSnapAndSolve), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Live Audio Listen (⌘⇧M)", action: #selector(triggerToggleAudio), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Ghost Click-Through (⌘⇧G)", action: #selector(triggerToggleGhost), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Screen-Share Stealth", action: #selector(triggerToggleStealth), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CluelyForMacOS", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    private func setupStealthHUDPanel() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelWidth: CGFloat = 680
        let panelHeight: CGFloat = 460
        let originX = screenFrame.midX - (panelWidth / 2)
        let originY = screenFrame.maxY - panelHeight - 24
        
        let rect = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
        panel = StealthPanel(contentRect: rect)
        panel.minSize = NSSize(width: 500, height: 320)
        
        let hostingView = NSHostingView(rootView: HUDView(viewModel: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: rect.size)
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }
    
    private func setupBindingsAndHotKeys() {
        viewModel.onStealthModeChanged = { [weak self] enabled in
            self?.panel.setStealthMode(enabled)
            self?.viewModel.statusBanner = enabled
                ? "Stealth Active — Hidden from Zoom, Meet, Teams & Screenshots"
                : "Stealth Disabled — HUD is currently visible to screen capture"
        }
        
        viewModel.onGhostModeChanged = { [weak self] enabled in
            self?.panel.setGhostClickThrough(enabled)
            self?.viewModel.statusBanner = enabled
                ? "Ghost Mode ON — Mouse clicks pass through HUD (Press ⌘⇧G to interact)"
                : "Ghost Mode OFF — HUD interactive"
        }
        
        viewModel.onToggleHUDVisibility = { [weak self] in
            self?.toggleHUD()
        }
        
        viewModel.onNudgeWindow = { [weak self] dx, dy in
            self?.panel.nudge(dx: dx, dy: dy)
        }
        
        HotKeyManager.shared.onAction = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .askAI:
                if !self.panel.isVisible { self.panel.orderFrontRegardless() }
                self.viewModel.askAI(captureFreshScreenIfNeeded: false)
            case .snapAndSolve:
                if !self.panel.isVisible { self.panel.orderFrontRegardless() }
                self.viewModel.snapScreenAndSolve()
            case .toggleVisibility:
                self.toggleHUD()
            case .toggleAudio:
                self.viewModel.audioManager.toggleListening()
            case .toggleGhost:
                self.viewModel.isGhostClickThrough.toggle()
            case .clearSession:
                self.viewModel.clearSession()
            case .nudgeUp:
                self.panel.nudge(dx: 0, dy: 45)
            case .nudgeDown:
                self.panel.nudge(dx: 0, dy: -45)
            case .nudgeLeft:
                self.panel.nudge(dx: -45, dy: 0)
            case .nudgeRight:
                self.panel.nudge(dx: 45, dy: 0)
            }
        }
        
        HotKeyManager.shared.registerAll()
    }
    
    @objc private func toggleHUD() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
    
    @objc private func triggerAskAI() {
        if !panel.isVisible { panel.orderFrontRegardless() }
        viewModel.askAI(captureFreshScreenIfNeeded: false)
    }
    
    @objc private func triggerSnapAndSolve() {
        if !panel.isVisible { panel.orderFrontRegardless() }
        viewModel.snapScreenAndSolve()
    }
    
    @objc private func triggerToggleAudio() {
        viewModel.audioManager.toggleListening()
    }
    
    @objc private func triggerToggleGhost() {
        viewModel.isGhostClickThrough.toggle()
    }
    
    @objc private func triggerToggleStealth() {
        viewModel.isStealthMode.toggle()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
