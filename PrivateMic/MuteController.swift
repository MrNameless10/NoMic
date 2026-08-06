import AudioToolbox
import Foundation

final class MuteController {
    private let hardware: AudioHardwareClient
    private let preferencesStore: PreferencesStoring
    private let zeroTolerance: Float = 0.0001

    init(hardware: AudioHardwareClient, preferencesStore: PreferencesStoring) {
        self.hardware = hardware
        self.preferencesStore = preferencesStore
    }

    func state(of device: AudioDevice?) throws -> MicrophoneState {
        guard let device else { return .unavailable }
        switch device.muteMethod {
        case .nativeMute:
            let values = try hardware.readMute(
                deviceID: device.id, elements: device.muteElements
            )
            return values.values.allSatisfy { $0 } ? .muted : .unmuted
        case .inputVolume:
            let values = try hardware.readVolume(
                deviceID: device.id, elements: device.volumeElements
            )
            return values.values.allSatisfy { $0 <= zeroTolerance } ? .muted : .unmuted
        case .unsupported:
            return .unsupported
        }
    }

    @discardableResult
    func toggle(device: AudioDevice) throws -> MicrophoneState {
        let targetMuted = try state(of: device) != .muted
        try setMuted(targetMuted, device: device)
        return targetMuted ? .muted : .unmuted
    }

    func setMuted(_ muted: Bool, device: AudioDevice) throws {
        try confirmCurrent(device)
        switch device.muteMethod {
        case .nativeMute:
            try hardware.writeMute(
                muted, deviceID: device.id, elements: device.muteElements
            )
            try confirmCurrent(device)
            let readBack = try hardware.readMute(
                deviceID: device.id, elements: device.muteElements
            )
            guard readBack.count == device.muteElements.count,
                  readBack.values.allSatisfy({ $0 == muted }) else {
                throw AudioHardwareError.verificationFailed
            }
        case .inputVolume:
            try setVolumeMuted(muted, device: device)
        case .unsupported:
            throw AudioHardwareError.unsupported
        }
    }

    private func setVolumeMuted(_ muted: Bool, device: AudioDevice) throws {
        if muted {
            let current = try hardware.readVolume(
                deviceID: device.id, elements: device.volumeElements
            )
            guard current.count == device.volumeElements.count else {
                throw AudioHardwareError.disconnected
            }
            if current.values.contains(where: { $0 > zeroTolerance }) {
                var preferences = preferencesStore.preferences
                preferences.previousVolumes[device.uid] = DeviceVolumeSnapshot(current)
                preferencesStore.preferences = preferences
            }
            try hardware.writeVolume(
                Dictionary(uniqueKeysWithValues: device.volumeElements.map { ($0, 0) }),
                deviceID: device.id
            )
            try confirmCurrent(device)
            let readBack = try hardware.readVolume(
                deviceID: device.id, elements: device.volumeElements
            )
            guard readBack.values.allSatisfy({ $0 <= zeroTolerance }) else {
                throw AudioHardwareError.verificationFailed
            }
        } else {
            let preferences = preferencesStore.preferences
            guard let snapshot = preferences.previousVolumes[device.uid],
                  let saved = snapshot.elementValues,
                  Set(saved.keys) == Set(device.volumeElements),
                  saved.values.contains(where: { $0 > zeroTolerance }) else {
                throw AudioHardwareError.invalidSavedVolume
            }
            try hardware.writeVolume(saved, deviceID: device.id)
            try confirmCurrent(device)
            let readBack = try hardware.readVolume(
                deviceID: device.id, elements: device.volumeElements
            )
            guard saved.allSatisfy({ element, value in
                guard let actual = readBack[element] else { return false }
                return abs(actual - value) <= 0.01
            }) else {
                throw AudioHardwareError.verificationFailed
            }
        }
    }

    private func confirmCurrent(_ device: AudioDevice) throws {
        guard let current = try hardware.defaultInputDevice() else {
            throw AudioHardwareError.disconnected
        }
        guard current.id == device.id, current.uid == device.uid else {
            throw AudioHardwareError.deviceChanged
        }
    }
}
