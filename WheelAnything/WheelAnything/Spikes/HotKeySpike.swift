#if DEBUG
import Carbon.HIToolbox

/// Spike 3: a global hot key through Carbon's `RegisterEventHotKey`, inside the sandbox.
///
/// Per the CarbonEvents.h documentation, hot keys are non-exclusive by default: several
/// apps may register the same combination and all of them are notified. Only an
/// exclusive registration that clashes with another exclusive one returns
/// `eventHotKeyExistsErr`. The header also says the API is not thread safe, so all
/// calls stay on the main actor.
@MainActor
enum HotKeySpike {
    /// Called on the main thread with the ID of the pressed hot key.
    static var onPress: ((UInt32) -> Void)?
    private static var handlerInstalled = false
    /// Registrations are kept alive for the life of the app; dropping a ref does not unregister.
    private static var registrations: [EventHotKeyRef] = []
    /// Four-character code identifying our hot keys: 'WHLA'.
    private static let signature: OSType = 0x5748_4C41

    @discardableResult
    static func register(id: UInt32, keyCode: Int, modifiers: Int, label: String, exclusive: Bool = false) -> OSStatus {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(), exclusive ? OptionBits(kEventHotKeyExclusive) : 0, &ref)
        if let ref { registrations.append(ref) }
        SpikeLog.line("HOTKEY register \(label) id=\(id) exclusive=\(exclusive): status=\(status)\(name(of: status))")
        return status
    }

    private static func name(of status: OSStatus) -> String {
        switch status {
        case noErr: " (noErr)"
        case OSStatus(eventHotKeyExistsErr): " (eventHotKeyExistsErr)"
        case OSStatus(eventHotKeyInvalidErr): " (eventHotKeyInvalidErr)"
        default: ""
        }
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            // Carbon dispatches application events from the main run loop, so this C
            // callback runs on the main thread. assumeIsolated verifies that at runtime.
            MainActor.assumeIsolated { HotKeySpike.onPress?(hotKeyID.id) }
            return noErr
        }, 1, &eventType, nil, nil)
        SpikeLog.line("HOTKEY InstallEventHandler status=\(status)")
    }

    /// Headless: exclusively hold ⌃⌥⌘J for `seconds`, so a second process can try to
    /// take the same combination and we can record the exact error.
    static func holdExclusive(seconds: Double) {
        register(id: 9, keyCode: kVK_ANSI_J, modifiers: cmdKey | optionKey | controlKey, label: "⌃⌥⌘J", exclusive: true)
        if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
    }
}
#endif
