import XCTest
@testable import PrivateMic

final class MuteControllerTests: XCTestCase {
    func testNativeMuteIsWrittenAndVerified() throws {
        let hardware = MockAudioHardware()
        hardware.device = .native()
        hardware.muteValues = [0: false]
        let controller = MuteController(
            hardware: hardware, preferencesStore: MemoryPreferencesStore()
        )

        try controller.setMuted(true, device: hardware.device!)

        XCTAssertEqual(try controller.state(of: hardware.device), .muted)
    }

    func testRejectedNativeMuteFailsVerification() {
        let hardware = MockAudioHardware()
        hardware.device = .native()
        hardware.muteValues = [0: false]
        hardware.appliesWrites = false
        let controller = MuteController(
            hardware: hardware, preferencesStore: MemoryPreferencesStore()
        )

        XCTAssertThrowsError(try controller.setMuted(true, device: hardware.device!)) {
            XCTAssertEqual($0 as? AudioHardwareError, .verificationFailed)
        }
    }

    func testVolumeMuteSavesAndRestoresPerDeviceValues() throws {
        let hardware = MockAudioHardware()
        hardware.device = .volume()
        hardware.volumeValues = [1: 0.3, 2: 0.7]
        let store = MemoryPreferencesStore()
        let controller = MuteController(hardware: hardware, preferencesStore: store)

        try controller.setMuted(true, device: hardware.device!)
        XCTAssertEqual(hardware.volumeValues, [1: 0, 2: 0])
        XCTAssertEqual(store.preferences.previousVolumes["volume"]?.elementValues, [1: 0.3, 2: 0.7])

        try controller.setMuted(false, device: hardware.device!)
        XCTAssertEqual(hardware.volumeValues, [1: 0.3, 2: 0.7])
    }

    func testDoesNotRestoreAnotherDevicesVolume() throws {
        let hardware = MockAudioHardware()
        hardware.device = .volume(uid: "device-b")
        hardware.volumeValues = [1: 0, 2: 0]
        var preferences = AppPreferences.defaults
        preferences.previousVolumes["device-a"] = DeviceVolumeSnapshot([1: 0.4, 2: 0.4])
        let controller = MuteController(
            hardware: hardware,
            preferencesStore: MemoryPreferencesStore(preferences)
        )

        XCTAssertThrowsError(try controller.setMuted(false, device: hardware.device!)) {
            XCTAssertEqual($0 as? AudioHardwareError, .invalidSavedVolume)
        }
    }

    func testDeviceChangeDuringOperationIsRejected() {
        let hardware = ChangingAudioHardware()
        let original = AudioDevice.native(id: 1, uid: "first")
        hardware.device = original
        let controller = MuteController(
            hardware: hardware, preferencesStore: MemoryPreferencesStore()
        )

        XCTAssertThrowsError(try controller.setMuted(true, device: original)) {
            XCTAssertEqual($0 as? AudioHardwareError, .deviceChanged)
        }
    }
}

private final class ChangingAudioHardware: MockAudioHardware {
    private var reads = 0

    override func defaultInputDevice() throws -> AudioDevice? {
        reads += 1
        if reads > 1 { return .native(id: 9, uid: "second") }
        return device
    }
}
