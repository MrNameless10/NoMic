import XCTest
@testable import PrivateMic

@MainActor
final class AppStateTests: XCTestCase {
    func testToggleUsesFeedbackSelectedForResultingState() {
        let hardware = MockAudioHardware()
        hardware.device = .native()
        hardware.muteValues = [0: false]
        var preferences = AppPreferences.defaults
        preferences.mutedFeedback = .spoken
        preferences.unmutedFeedback = .glass
        let feedback = MockNotificationManager()
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(preferences),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: feedback
        )

        state.toggleMute()

        XCTAssertEqual(state.microphoneState, .muted)
        XCTAssertEqual(feedback.feedback, .muted)
        XCTAssertEqual(feedback.audioFeedback, .spoken)
    }

    func testSelectingInputDeviceUpdatesDefaultWithoutMutingIt() {
        let first = AudioDevice.native(id: 1, uid: "first")
        let second = AudioDevice.native(id: 2, uid: "second")
        let hardware = MockAudioHardware()
        hardware.device = first
        hardware.devices = [first, second]
        hardware.muteValues = [0: false]
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )

        state.selectInputDevice(second)

        XCTAssertEqual(state.audioDeviceManager.currentDevice?.uid, "second")
        XCTAssertEqual(state.microphoneState, .unmuted)
        XCTAssertEqual(hardware.muteValues[0], false)
    }

    func testSelectingInputDeviceKeepsNewDeviceMutedWhenEnabled() {
        let first = AudioDevice.native(id: 1, uid: "first")
        let second = AudioDevice.native(id: 2, uid: "second")
        let hardware = MockAudioHardware()
        hardware.device = first
        hardware.devices = [first, second]
        hardware.muteValues = [0: true]
        var preferences = AppPreferences.defaults
        preferences.keepMutedWhenDeviceChanges = true
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(preferences),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )

        state.selectInputDevice(second)

        XCTAssertEqual(state.audioDeviceManager.currentDevice?.uid, "second")
        XCTAssertEqual(state.microphoneState, .muted)
        XCTAssertEqual(hardware.muteValues[0], true)
        XCTAssertTrue(
            hardware.muteWrites.contains {
                $0.deviceID == second.id && $0.muted
            }
        )
    }

    private enum TestError: Error {
        case failed
    }

    func testKeepMutedMutesNewDefaultDevice() async {
        let hardware = MockAudioHardware()
        hardware.device = .native(id: 1, uid: "first")
        hardware.muteValues = [0: true]
        var preferences = AppPreferences.defaults
        preferences.keepMutedWhenDeviceChanges = true
        let store = MemoryPreferencesStore(preferences)
        let state = AppState(
            hardware: hardware,
            preferencesStore: store,
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )
        XCTAssertEqual(state.microphoneState, .muted)

        hardware.device = .native(id: 2, uid: "second")
        hardware.muteValues = [0: false]
        hardware.emitChange()
        await Task.yield()

        XCTAssertEqual(state.audioDeviceManager.currentDevice?.uid, "second")
        XCTAssertEqual(hardware.muteValues[0], true)
        XCTAssertEqual(state.microphoneState, .muted)
    }

    func testDeviceChangeDoesNotAlterNewDeviceByDefault() async {
        let hardware = MockAudioHardware()
        hardware.device = .native(id: 1, uid: "first")
        hardware.muteValues = [0: true]
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: MockLoginItemManager(),
            notificationManager: MockNotificationManager()
        )

        hardware.device = .native(id: 2, uid: "second")
        hardware.muteValues = [0: false]
        hardware.emitChange()
        await Task.yield()

        XCTAssertEqual(hardware.muteValues[0], false)
        XCTAssertEqual(state.microphoneState, .unmuted)
    }

    func testLaunchAtLoginUsesManagerState() {
        let hardware = MockAudioHardware()
        let login = MockLoginItemManager()
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: login,
            notificationManager: MockNotificationManager()
        )

        state.setLaunchAtLogin(true)

        XCTAssertEqual(login.state, .enabled)
        XCTAssertTrue(state.preferences.launchAtLogin)
    }

    func testLaunchAtLoginFailureKeepsActualDisabledState() {
        let hardware = MockAudioHardware()
        let login = MockLoginItemManager()
        login.error = TestError.failed
        let state = AppState(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(),
            shortcutManager: MockShortcutManager(),
            loginItemManager: login,
            notificationManager: MockNotificationManager()
        )

        state.setLaunchAtLogin(true)

        XCTAssertEqual(login.state, .disabled)
        XCTAssertFalse(state.preferences.launchAtLogin)
        XCTAssertNotNil(state.errorMessage)
    }
}
