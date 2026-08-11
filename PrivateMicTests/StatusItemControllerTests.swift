import XCTest
@testable import PrivateMic

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testControllerInstallsExplicitStatusBarButton() {
        let state = AppState(
            hardware: MockAudioHardware(),
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )
        let controller = StatusItemController(appState: state)

        XCTAssertTrue(controller.isInstalled)
        XCTAssertEqual(controller.currentSymbolName, "exclamationmark.triangle")

        controller.invalidate()
        XCTAssertFalse(controller.isInstalled)
    }

    func testChangingIconStyleUpdatesStatusItemImmediately() {
        let hardware = MockAudioHardware()
        hardware.device = .native()
        hardware.muteValues = [0: false]
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )
        let controller = StatusItemController(appState: state)

        state.setMenuBarIconStyle(.stateBadge)
        XCTAssertEqual(controller.currentSymbolName, "checkmark.circle.fill")

        state.setMenuBarIconStyle(.text)
        XCTAssertEqual(controller.currentSymbolName, "")
        XCTAssertEqual(controller.currentTitle, "MIC")

        controller.invalidate()
    }
}
