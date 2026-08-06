import Carbon
import XCTest
@testable import PrivateMic

final class ShortcutTests: XCTestCase {
    func testDefaultShortcutIsControlOptionM() {
        let shortcut = Shortcut.defaultShortcut

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_M))
        XCTAssertNotEqual(shortcut.modifiers & UInt32(controlKey), 0)
        XCTAssertNotEqual(shortcut.modifiers & UInt32(optionKey), 0)
        XCTAssertEqual(shortcut.displayName, "⌃⌥M")
        XCTAssertTrue(shortcut.isValid)
    }

    func testPlainCharacterIsRejected() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: 0, key: "A")

        XCTAssertFalse(shortcut.isValid)
    }
}
