import Foundation
import XCTest
@testable import PrivateMic

final class PreferencesTests: XCTestCase {
    func testPreferencesRoundTrip() {
        let suite = "PrivateMicTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPreferencesStore(defaults: defaults)
        var value = AppPreferences.defaults
        value.keepMutedWhenDeviceChanges = true
        value.mutedFeedback = .spoken
        value.unmutedFeedback = .glass
        value.menuBarIconStyle = .stateBadge
        value.previousVolumes["device-a"] = DeviceVolumeSnapshot([1: 0.42])

        store.preferences = value

        XCTAssertEqual(store.preferences, value)
    }

    func testResetRestoresDefaults() {
        let suite = "PrivateMicTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPreferencesStore(defaults: defaults)
        var value = AppPreferences.defaults
        value.mutedFeedback = .basso
        store.preferences = value

        store.reset()

        XCTAssertEqual(store.preferences, .defaults)
    }

    func testVolumeSnapshotsAreSeparatePerDevice() {
        var preferences = AppPreferences.defaults
        preferences.previousVolumes["device-a"] = DeviceVolumeSnapshot([1: 0.25])
        preferences.previousVolumes["device-b"] = DeviceVolumeSnapshot([1: 0.75])

        XCTAssertEqual(preferences.previousVolumes["device-a"]?.elementValues?[1], 0.25)
        XCTAssertEqual(preferences.previousVolumes["device-b"]?.elementValues?[1], 0.75)
    }

    func testLegacySoundPreferenceMigratesToSeparateFeedback() throws {
        let suite = "PrivateMicTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = try JSONSerialization.data(withJSONObject: [
            "shortcut": ["keyCode": 46, "modifiers": 6144, "key": "M"],
            "launchAtLogin": false,
            "keepMutedWhenDeviceChanges": false,
            "showNotification": false,
            "playSound": true,
            "previousVolumes": [:]
        ])
        defaults.set(data, forKey: "PrivateMic.preferences")

        let preferences = UserDefaultsPreferencesStore(defaults: defaults).preferences

        XCTAssertEqual(preferences.mutedFeedback, .tink)
        XCTAssertEqual(preferences.unmutedFeedback, .pop)
        XCTAssertEqual(preferences.menuBarIconStyle, .microphone)
    }
}
