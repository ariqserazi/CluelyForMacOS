import AppKit
import Carbon

enum GlobalHotKeyAction: UInt32 {
    case askAI          = 1 // Cmd + Shift + Space
    case snapAndSolve   = 2 // Cmd + Shift + S
    case toggleVisibility = 3 // Cmd + Shift + H
    case toggleAudio    = 4 // Cmd + Shift + M
    case toggleGhost    = 5 // Cmd + Shift + G
    case clearSession   = 6 // Cmd + Shift + K
    case nudgeUp        = 7 // Cmd + Shift + Up
    case nudgeDown      = 8 // Cmd + Shift + Down
    case nudgeLeft      = 9 // Cmd + Shift + Left
    case nudgeRight     = 10 // Cmd + Shift + Right
}

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    var onAction: ((GlobalHotKeyAction) -> Void)?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    
    private init() {}
    
    func registerAll() {
        unregisterAll()
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr, let action = GlobalHotKeyAction(rawValue: hotKeyID.id) {
                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        manager.onAction?(action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
        
        let modifiers = UInt32(cmdKey | shiftKey)
        
        registerHotKey(action: .askAI, keyCode: UInt32(kVK_Space), modifiers: modifiers)
        registerHotKey(action: .snapAndSolve, keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
        registerHotKey(action: .toggleVisibility, keyCode: UInt32(kVK_ANSI_H), modifiers: modifiers)
        registerHotKey(action: .toggleAudio, keyCode: UInt32(kVK_ANSI_M), modifiers: modifiers)
        registerHotKey(action: .toggleGhost, keyCode: UInt32(kVK_ANSI_G), modifiers: modifiers)
        registerHotKey(action: .clearSession, keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers)
        registerHotKey(action: .nudgeUp, keyCode: UInt32(kVK_UpArrow), modifiers: modifiers)
        registerHotKey(action: .nudgeDown, keyCode: UInt32(kVK_DownArrow), modifiers: modifiers)
        registerHotKey(action: .nudgeLeft, keyCode: UInt32(kVK_LeftArrow), modifiers: modifiers)
        registerHotKey(action: .nudgeRight, keyCode: UInt32(kVK_RightArrow), modifiers: modifiers)
    }
    
    private func registerHotKey(action: GlobalHotKeyAction, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5545), id: action.rawValue) // 'CLUE'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        }
    }
    
    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
