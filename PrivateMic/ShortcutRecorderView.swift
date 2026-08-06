import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: Shortcut
    let onChange: (Shortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onShortcut = onChange
        field.stringValue = shortcut.displayName
        return field
    }

    func updateNSView(_ field: ShortcutRecorderField, context: Context) {
        field.onShortcut = onChange
        if field.window?.firstResponder !== field {
            field.stringValue = shortcut.displayName
        }
    }
}

final class ShortcutRecorderField: NSTextField {
    var onShortcut: ((Shortcut) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isSelectable = false
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        focusRingType = .exterior
        toolTip = "Click, then press a key combination."
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        stringValue = "Press shortcut"
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }
        let modifiers = carbonModifiers(event.modifierFlags)
        guard modifiers != 0,
              let characters = event.charactersIgnoringModifiers,
              !characters.isEmpty else {
            NSSound.beep()
            stringValue = "Include a modifier"
            return
        }
        let shortcut = Shortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            key: displayKey(event.keyCode, characters: characters)
        )
        stringValue = shortcut.displayName
        onShortcut?(shortcut)
        window?.makeFirstResponder(nil)
    }

    private func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    private func displayKey(_ keyCode: UInt16, characters: String) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return characters.uppercased()
        }
    }
}
