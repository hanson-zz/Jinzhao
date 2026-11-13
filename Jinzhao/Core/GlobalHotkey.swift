import AppKit
import Carbon

/// A system-wide Option+Space hotkey, registered through the Carbon hotkey API.
/// Unlike a key-event monitor, RegisterEventHotKey does not require Input Monitoring permission.
final class JZGlobalHotkey {
    static let shared = JZGlobalHotkey()
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private init() {}

    func install() {
        guard hotkey == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .jinzhaoQuickLaunch, object: nil)
            }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { return }

        let identifier = EventHotKeyID(signature: OSType(0x4A5A484F), id: 1) // JZHO
        let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey),
                                         identifier, GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            NSLog("Jinzhao: Option+Space global shortcut unavailable (code %d)", result)
        }
    }

    deinit {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
