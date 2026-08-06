import Carbon
import Foundation

protocol GlobalShortcutManaging: AnyObject {
    @MainActor
    func register(_ shortcut: Shortcut, action: @escaping @MainActor @Sendable () -> Void) throws
    @MainActor
    func unregister()
}

enum GlobalShortcutError: LocalizedError, Equatable {
    case invalid
    case conflict
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalid:
            return "Choose a shortcut that includes Control, Option, Shift, or Command."
        case .conflict:
            return "That shortcut is already in use. Choose a different shortcut."
        case .registrationFailed:
            return "The keyboard shortcut could not be registered. Try a different shortcut."
        }
    }
}

final class CarbonGlobalShortcutManager: GlobalShortcutManaging, @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (@MainActor @Sendable () -> Void)?

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @MainActor
    func register(
        _ shortcut: Shortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) throws {
        guard shortcut.isValid else { throw GlobalShortcutError.invalid }
        unregister()
        try installHandlerIfNeeded()
        self.action = action
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x504D4943, id: 1) // "PMIC"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else {
            self.action = nil
            if status == eventHotKeyExistsErr { throw GlobalShortcutError.conflict }
            throw GlobalShortcutError.registrationFailed(status)
        }
        hotKeyRef = reference
    }

    @MainActor
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        action = nil
    }

    @MainActor
    private func installHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID(signature: 0, id: 0)
            var actualSize = 0
            let parameterStatus = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                &actualSize,
                &identifier
            )
            guard parameterStatus == noErr,
                  identifier.signature == 0x504D4943,
                  identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<CarbonGlobalShortcutManager>
                .fromOpaque(userData)
                .takeUnretainedValue()
            DispatchQueue.main.async { manager.action?() }
            return noErr
        }
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard status == noErr else {
            throw GlobalShortcutError.registrationFailed(status)
        }
        eventHandlerRef = handler
    }
}
