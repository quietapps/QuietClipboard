import AppKit
import Carbon.HIToolbox

final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    private var refs: [AppShortcutAction: EventHotKeyRef] = [:]
    private var ids: [UInt32: AppShortcutAction] = [:]
    private var nextID: UInt32 = 1
    private var handlerRef: EventHandlerRef?
    private(set) var settings: ShortcutSettings = ShortcutSettings()

    var onAction: ((AppShortcutAction) -> Void)?

    private init() {}

    private var installed = false
    func install() {
        guard !installed else { return }
        installed = true
        installHandler()
        register(all: settings.bindings)
    }

    func reload() {
        unregisterAll()
        register(all: settings.bindings)
    }

    func updateBinding(_ combo: KeyCombo?, for action: AppShortcutAction) {
        settings.set(combo, for: action)
        unregister(action: action)
        if let combo {
            register(action: action, combo: combo)
        }
    }

    func resetDefaults() {
        settings.resetToDefaults()
        reload()
    }

    private func installHandler() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, ptr -> OSStatus in
            guard let event, let ptr else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(ptr).takeUnretainedValue()
            var hkID = EventHotKeyID()
            let status = GetEventParameter(event,
                                            EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID),
                                            nil,
                                            MemoryLayout<EventHotKeyID>.size,
                                            nil,
                                            &hkID)
            guard status == noErr else { return status }
            DispatchQueue.main.async {
                if let action = manager.ids[hkID.id] {
                    manager.onAction?(action)
                }
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    private func register(all bindings: [AppShortcutAction: KeyCombo]) {
        for (action, combo) in bindings {
            register(action: action, combo: combo)
        }
    }

    private func register(action: AppShortcutAction, combo: KeyCombo) {
        let id = nextID
        nextID += 1
        let hkID = EventHotKeyID(signature: OSType(0x51434C50), id: id) // 'QCLP'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode,
                                          combo.carbonModifiers,
                                          hkID,
                                          GetEventDispatcherTarget(),
                                          0,
                                          &ref)
        if status == noErr, let ref {
            refs[action] = ref
            ids[id] = action
        } else {
            NSLog("RegisterEventHotKey failed for \(action) status=\(status)")
        }
    }

    private func unregister(action: AppShortcutAction) {
        if let ref = refs.removeValue(forKey: action) {
            UnregisterEventHotKey(ref)
        }
        ids = ids.filter { $0.value != action }
    }

    private func unregisterAll() {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        ids.removeAll()
    }
}
