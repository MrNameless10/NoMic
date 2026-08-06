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
}
