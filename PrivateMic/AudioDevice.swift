import AudioToolbox
import Foundation

enum MuteMethod: String, Codable, Equatable {
    case nativeMute
    case inputVolume
    case unsupported

    var displayName: String {
        switch self {
        case .nativeMute: return "Native mute"
        case .inputVolume: return "Input-volume fallback"
        case .unsupported: return "Unsupported"
        }
    }
}

struct AudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let muteElements: [AudioObjectPropertyElement]
    let volumeElements: [AudioObjectPropertyElement]

    var muteMethod: MuteMethod {
        if !muteElements.isEmpty { return .nativeMute }
        if !volumeElements.isEmpty { return .inputVolume }
        return .unsupported
    }
}

enum MicrophoneState: Equatable {
    case muted
    case unmuted
    case unsupported
    case unavailable

    var title: String {
        switch self {
        case .muted: return "Muted"
        case .unmuted: return "Unmuted"
        case .unsupported: return "Unsupported"
        case .unavailable: return "No microphone"
        }
    }
}

struct DeviceVolumeSnapshot: Codable, Equatable {
    var values: [String: Float]

    init(_ values: [AudioObjectPropertyElement: Float]) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { (String($0.key), $0.value) })
    }

    var elementValues: [AudioObjectPropertyElement: Float]? {
        var result: [AudioObjectPropertyElement: Float] = [:]
        for (key, value) in values {
            guard let element = AudioObjectPropertyElement(key),
                  value.isFinite, (0...1).contains(value) else {
                return nil
            }
            result[element] = value
        }
        return result
    }
}
