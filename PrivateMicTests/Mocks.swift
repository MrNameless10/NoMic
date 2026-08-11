import AudioToolbox
import Foundation
@testable import PrivateMic

final class MemoryPreferencesStore: PreferencesStoring {
    var preferences: AppPreferences

    init(_ preferences: AppPreferences = .defaults) {
        self.preferences = preferences
    }

    func reset() {
        preferences = .defaults
    }
}

class MockAudioHardware: AudioHardwareClient {
    var device: AudioDevice?
    var devices: [AudioDevice] = []
    var muteValues: [AudioObjectPropertyElement: Bool] = [:]
    var muteWrites: [(deviceID: AudioDeviceID, muted: Bool)] = []
    var volumeValues: [AudioObjectPropertyElement: Float] = [:]
    var appliesWrites = true
    var monitor: (@Sendable () -> Void)?

    func defaultInputDevice() throws -> AudioDevice? { device }

    func inputDevices() throws -> [AudioDevice] {
        if !devices.isEmpty { return devices }
        return device.map { [$0] } ?? []
    }

    func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        guard let selected = try inputDevices().first(where: { $0.id == deviceID }) else {
            throw AudioHardwareError.disconnected
        }
        device = selected
    }

    func readMute(
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws -> [AudioObjectPropertyElement: Bool] {
        Dictionary(uniqueKeysWithValues: elements.compactMap { element in
            muteValues[element].map { (element, $0) }
        })
    }

    func writeMute(
        _ muted: Bool,
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws {
        muteWrites.append((deviceID, muted))
        guard appliesWrites else { return }
        elements.forEach { muteValues[$0] = muted }
    }

    func readVolume(
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws -> [AudioObjectPropertyElement: Float] {
        Dictionary(uniqueKeysWithValues: elements.compactMap { element in
            volumeValues[element].map { (element, $0) }
        })
    }

    func writeVolume(
        _ values: [AudioObjectPropertyElement: Float],
        deviceID: AudioDeviceID
    ) throws {
        guard appliesWrites else { return }
        volumeValues.merge(values) { _, new in new }
    }

    func startMonitoring(_ handler: @escaping @Sendable () -> Void) throws {
        monitor = handler
    }

    func stopMonitoring() {
        monitor = nil
    }

    func emitChange() {
        monitor?()
    }
}

final class MockShortcutManager: GlobalShortcutManaging {
    var registered: Shortcut?
    var action: (@MainActor @Sendable () -> Void)?
    var error: Error?

    @MainActor
    func register(
        _ shortcut: Shortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) throws {
        if let error { throw error }
        registered = shortcut
        self.action = action
    }

    @MainActor
    func unregister() {
        registered = nil
        action = nil
    }
}

final class MockLoginItemManager: LoginItemManaging {
    var state: LoginItemState = .disabled
    var error: Error?

    func setEnabled(_ enabled: Bool) throws {
        if let error { throw error }
        state = enabled ? .enabled : .disabled
    }
}

final class MockNotificationManager: NotificationManaging {
    var authorizationGranted = true
    var feedback: MicrophoneState?
    var audioFeedback: AudioFeedback?
    var notificationRequested = false

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        completion(authorizationGranted)
    }

    func provideFeedback(
        state: MicrophoneState,
        notification: Bool,
        audio: AudioFeedback
    ) {
        feedback = state
        audioFeedback = audio
        notificationRequested = notification
    }
}

extension AudioDevice {
    static func native(id: AudioDeviceID = 1, uid: String = "native") -> AudioDevice {
        AudioDevice(id: id, uid: uid, name: "Test microphone", muteElements: [0], volumeElements: [])
    }

    static func volume(id: AudioDeviceID = 2, uid: String = "volume") -> AudioDevice {
        AudioDevice(id: id, uid: uid, name: "Volume microphone", muteElements: [], volumeElements: [1, 2])
    }
}
