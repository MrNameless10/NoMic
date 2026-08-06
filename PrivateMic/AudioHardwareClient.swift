import AudioToolbox
import Foundation

protocol AudioHardwareClient: AnyObject {
    func defaultInputDevice() throws -> AudioDevice?
    func inputDevices() throws -> [AudioDevice]
    func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws
    func readMute(deviceID: AudioDeviceID, elements: [AudioObjectPropertyElement]) throws -> [AudioObjectPropertyElement: Bool]
    func writeMute(_ muted: Bool, deviceID: AudioDeviceID, elements: [AudioObjectPropertyElement]) throws
    func readVolume(deviceID: AudioDeviceID, elements: [AudioObjectPropertyElement]) throws -> [AudioObjectPropertyElement: Float]
    func writeVolume(_ values: [AudioObjectPropertyElement: Float], deviceID: AudioDeviceID) throws
    func startMonitoring(_ handler: @escaping @Sendable () -> Void) throws
    func stopMonitoring()
}

enum AudioHardwareError: LocalizedError, Equatable {
    case coreAudio(operation: String, status: OSStatus)
    case deviceChanged
    case disconnected
    case writeRejected
    case verificationFailed
    case invalidSavedVolume
    case unsupported

    var errorDescription: String? {
        switch self {
        case .coreAudio(let operation, _):
            return "\(operation) failed."
        case .deviceChanged:
            return "The microphone changed while the operation was in progress. Please try again."
        case .disconnected:
            return "The microphone is no longer available."
        case .writeRejected:
            return "This microphone rejected the requested change."
        case .verificationFailed:
            return "The microphone did not apply the requested change."
        case .invalidSavedVolume:
            return "The previous volume for this microphone is unavailable or invalid."
        case .unsupported:
            return "This microphone does not provide a reliable mute or input-volume control."
        }
    }
}
