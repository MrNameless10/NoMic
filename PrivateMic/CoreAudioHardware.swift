import AudioToolbox
import CoreAudio
import Foundation
import OSLog

final class CoreAudioHardware: AudioHardwareClient {
    private let logger = Logger(subsystem: "com.local.PrivateMic", category: "CoreAudio")
    private let listenerQueue = DispatchQueue(label: "com.local.PrivateMic.core-audio-listeners")
    private let listenerQueueKey = DispatchSpecificKey<Void>()
    private var systemListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var deviceListeners: [(AudioDeviceID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var changeHandler: (@Sendable () -> Void)?

    init() {
        listenerQueue.setSpecific(key: listenerQueueKey, value: ())
    }

    deinit {
        stopMonitoring()
    }

    func defaultInputDevice() throws -> AudioDevice? {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(operation: "Reading the default input device", status: status)
        }
        guard deviceID != kAudioObjectUnknown else { return nil }
        return try makeInputDevice(deviceID)
    }

    func inputDevices() throws -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(
                operation: "Reading available audio devices",
                status: status
            )
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var deviceIDs = Array(
            repeating: AudioDeviceID(kAudioObjectUnknown),
            count: count
        )
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(
                operation: "Reading available audio devices",
                status: status
            )
        }

        return deviceIDs
            .filter { inputChannelCount($0) > 0 }
            .compactMap { try? makeInputDevice($0) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        guard inputChannelCount(deviceID) > 0 else {
            throw AudioHardwareError.disconnected
        }
        var selectedID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &selectedID
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(
                operation: "Changing the default input device",
                status: status
            )
        }

        guard try defaultInputDevice()?.id == deviceID else {
            throw AudioHardwareError.verificationFailed
        }
    }

    private func makeInputDevice(_ deviceID: AudioDeviceID) throws -> AudioDevice {
        let uid = try stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
        let name = try stringProperty(deviceID, selector: kAudioObjectPropertyName)
        let channelCount = inputChannelCount(deviceID)
        let channelElements: [AudioObjectPropertyElement] =
            channelCount > 0 ? Array(1...channelCount) : []
        let elements = [kAudioObjectPropertyElementMain] + channelElements
        let muteElements = writableElements(
            deviceID, selector: kAudioDevicePropertyMute, candidates: elements
        )
        let volumeElements = writableElements(
            deviceID, selector: kAudioDevicePropertyVolumeScalar, candidates: elements
        )
        return AudioDevice(
            id: deviceID,
            uid: uid,
            name: name,
            muteElements: preferredControlElements(muteElements),
            volumeElements: preferredControlElements(volumeElements)
        )
    }

    func readMute(
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws -> [AudioObjectPropertyElement: Bool] {
        try Dictionary(uniqueKeysWithValues: elements.map { element in
            var value: UInt32 = 0
            try readUInt32(deviceID, selector: kAudioDevicePropertyMute, element: element, value: &value)
            return (element, value != 0)
        })
    }

    func writeMute(
        _ muted: Bool,
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws {
        for element in elements {
            var value: UInt32 = muted ? 1 : 0
            try writeUInt32(deviceID, selector: kAudioDevicePropertyMute, element: element, value: &value)
        }
    }

    func readVolume(
        deviceID: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) throws -> [AudioObjectPropertyElement: Float] {
        try Dictionary(uniqueKeysWithValues: elements.map { element in
            var value: Float32 = 0
            try readFloat32(
                deviceID, selector: kAudioDevicePropertyVolumeScalar, element: element, value: &value
            )
            return (element, value)
        })
    }

    func writeVolume(
        _ values: [AudioObjectPropertyElement: Float],
        deviceID: AudioDeviceID
    ) throws {
        for (element, storedValue) in values {
            var value = Float32(storedValue)
            try writeFloat32(
                deviceID, selector: kAudioDevicePropertyVolumeScalar, element: element, value: &value
            )
        }
    }

    func startMonitoring(_ handler: @escaping @Sendable () -> Void) throws {
        stopMonitoring()
        try onListenerQueue {
            changeHandler = handler
            let selectors: [AudioObjectPropertySelector] = [
                kAudioHardwarePropertyDefaultInputDevice,
                kAudioHardwarePropertyDevices
            ]
            for selector in selectors {
                var address = AudioObjectPropertyAddress(
                    mSelector: selector,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                    guard let self else { return }
                    self.rebuildDeviceListenersOnQueue()
                    let handler = self.changeHandler
                    DispatchQueue.main.async { handler?() }
                }
                let status = AudioObjectAddPropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block
                )
                guard status == noErr else {
                    removeListenersOnQueue()
                    throw AudioHardwareError.coreAudio(
                        operation: "Starting audio monitoring", status: status
                    )
                }
                systemListeners.append((address, block))
            }
            rebuildDeviceListenersOnQueue()
        }
    }

    func stopMonitoring() {
        onListenerQueue {
            removeListenersOnQueue()
        }
    }

    private func removeListenersOnQueue() {
        for (deviceID, storedAddress, block) in deviceListeners {
            var address = storedAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, listenerQueue, block)
        }
        deviceListeners.removeAll()
        for (storedAddress, block) in systemListeners {
            var address = storedAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, block
            )
        }
        systemListeners.removeAll()
        changeHandler = nil
    }

    private func rebuildDeviceListenersOnQueue() {
        for (deviceID, storedAddress, block) in deviceListeners {
            var address = storedAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, listenerQueue, block)
        }
        deviceListeners.removeAll()

        guard let device = try? defaultInputDevice() else { return }
        let controls: [(AudioObjectPropertySelector, [AudioObjectPropertyElement])] = [
            (kAudioDevicePropertyMute, device.muteElements),
            (kAudioDevicePropertyVolumeScalar, device.volumeElements)
        ]
        for (selector, elements) in controls {
            for element in elements {
                var address = AudioObjectPropertyAddress(
                    mSelector: selector,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: element
                )
                let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                    guard let self else { return }
                    let handler = self.changeHandler
                    DispatchQueue.main.async { handler?() }
                }
                let status = AudioObjectAddPropertyListenerBlock(
                    device.id, &address, listenerQueue, block
                )
                if status == noErr {
                    deviceListeners.append((device.id, address, block))
                } else {
                    logger.error("Could not monitor an audio property: \(status)")
                }
            }
        }
    }

    private func onListenerQueue<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: listenerQueueKey) != nil {
            return try work()
        }
        return try listenerQueue.sync(execute: work)
    }

    private func preferredControlElements(
        _ elements: [AudioObjectPropertyElement]
    ) -> [AudioObjectPropertyElement] {
        elements.contains(kAudioObjectPropertyElementMain)
            ? [kAudioObjectPropertyElementMain]
            : elements
    }

    private func writableElements(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        candidates: [AudioObjectPropertyElement]
    ) -> [AudioObjectPropertyElement] {
        candidates.filter { element in
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { return false }
            var settable = DarwinBoolean(false)
            return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr
                && settable.boolValue
        }
    }

    private func inputChannelCount(_ deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size > 0 else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { memory.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, memory) == noErr else {
            return 0
        }
        let list = memory.bindMemory(to: AudioBufferList.self, capacity: 1)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + $1.mNumberChannels }
    }

    private func stringProperty(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr, let value else {
            throw AudioHardwareError.coreAudio(operation: "Reading microphone information", status: status)
        }
        return value.takeUnretainedValue() as String
    }

    private func readUInt32(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement,
        value: inout UInt32
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(operation: "Reading a microphone property", status: status)
        }
    }

    private func readFloat32(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement,
        value: inout Float32
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(operation: "Reading a microphone property", status: status)
        }
    }

    private func writeUInt32(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement,
        value: inout UInt32
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(operation: "Changing a microphone property", status: status)
        }
    }

    private func writeFloat32(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement,
        value: inout Float32
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value
        )
        guard status == noErr else {
            throw AudioHardwareError.coreAudio(operation: "Changing a microphone property", status: status)
        }
    }
}
