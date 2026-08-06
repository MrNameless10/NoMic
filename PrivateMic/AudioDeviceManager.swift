import Combine
import Foundation

@MainActor
final class AudioDeviceManager: ObservableObject {
    @Published private(set) var currentDevice: AudioDevice?
    @Published private(set) var availableDevices: [AudioDevice] = []
    @Published private(set) var errorMessage: String?

    private let hardware: AudioHardwareClient
    var onHardwareChange: (() -> Void)?

    init(hardware: AudioHardwareClient) {
        self.hardware = hardware
    }

    func start() {
        refresh()
        do {
            try hardware.startMonitoring { [weak self] in
                Task { @MainActor in self?.onHardwareChange?() }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        hardware.stopMonitoring()
    }

    @discardableResult
    func refresh() -> (old: AudioDevice?, new: AudioDevice?) {
        let old = currentDevice
        do {
            availableDevices = try hardware.inputDevices()
            currentDevice = try hardware.defaultInputDevice()
            errorMessage = nil
        } catch {
            currentDevice = nil
            availableDevices = []
            errorMessage = error.localizedDescription
        }
        return (old, currentDevice)
    }

    @discardableResult
    func selectDefaultDevice(
        _ device: AudioDevice
    ) throws -> (old: AudioDevice?, new: AudioDevice?) {
        guard availableDevices.contains(where: { $0.uid == device.uid }) else {
            throw AudioHardwareError.disconnected
        }
        try hardware.setDefaultInputDevice(device.id)
        let change = refresh()
        guard change.new?.uid == device.uid else {
            throw AudioHardwareError.verificationFailed
        }
        return change
    }
}
