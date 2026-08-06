import AppKit
import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var microphoneState: MicrophoneState = .unavailable
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var errorMessage: String?
    @Published private(set) var loginItemState: LoginItemState = .disabled

    let audioDeviceManager: AudioDeviceManager

    private let logger = Logger(subsystem: "com.local.PrivateMic", category: "Application")
    private let preferencesStore: PreferencesStoring
    private let muteController: MuteController
    private let shortcutManager: GlobalShortcutManaging
    private let loginItemManager: LoginItemManaging
    private let notificationManager: NotificationManaging
    private var settingsWindowController: NSWindowController?

    init(
        hardware: AudioHardwareClient = CoreAudioHardware(),
        preferencesStore: PreferencesStoring = UserDefaultsPreferencesStore(),
        shortcutManager: GlobalShortcutManaging? = nil,
        loginItemManager: LoginItemManaging = LoginItemManager(),
        notificationManager: NotificationManaging = NotificationManager()
    ) {
        self.preferencesStore = preferencesStore
        self.preferences = preferencesStore.preferences
        self.muteController = MuteController(
            hardware: hardware, preferencesStore: preferencesStore
        )
        self.shortcutManager = shortcutManager ?? CarbonGlobalShortcutManager()
        self.loginItemManager = loginItemManager
        self.notificationManager = notificationManager
        self.audioDeviceManager = AudioDeviceManager(hardware: hardware)
        self.loginItemState = loginItemManager.state

        audioDeviceManager.onHardwareChange = { [weak self] in
            self?.handleHardwareChange()
        }
        registerShortcut(preferences.shortcut, preservingOld: nil)
        synchronizeLoginPreference()
        audioDeviceManager.start()
        refreshMicrophoneState()
    }

    func toggleMute() {
        guard let device = audioDeviceManager.currentDevice else {
            setError("No input microphone is currently available.")
            return
        }
        do {
            microphoneState = try muteController.toggle(device: device)
            preferences = preferencesStore.preferences
            errorMessage = nil
            notificationManager.provideFeedback(
                state: microphoneState,
                notification: preferences.showNotification,
                sound: preferences.playSound
            )
        } catch {
            setError(error.localizedDescription)
            audioDeviceManager.refresh()
            refreshMicrophoneState()
        }
    }

    func updateShortcut(_ shortcut: Shortcut) {
        guard shortcut.isValid else {
            setError(GlobalShortcutError.invalid.localizedDescription)
            return
        }
        let oldShortcut = preferences.shortcut
        registerShortcut(shortcut, preservingOld: oldShortcut)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemManager.setEnabled(enabled)
            loginItemState = loginItemManager.state
            updatePreferences { $0.launchAtLogin = enabled }
            if loginItemState == .requiresApproval {
                setError(
                    "Launch at Login needs approval in System Settings → General → Login Items."
                )
            } else {
                errorMessage = nil
            }
        } catch {
            loginItemState = loginItemManager.state
            synchronizeLoginPreference()
            setError("Launch at Login could not be changed. \(error.localizedDescription)")
        }
    }

    func setKeepMutedWhenDeviceChanges(_ enabled: Bool) {
        updatePreferences { $0.keepMutedWhenDeviceChanges = enabled }
    }

    func setShowNotification(_ enabled: Bool) {
        guard enabled else {
            updatePreferences { $0.showNotification = false }
            return
        }
        notificationManager.requestAuthorization { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.updatePreferences { $0.showNotification = true }
                    self.errorMessage = nil
                } else {
                    self.updatePreferences { $0.showNotification = false }
                    self.setError(
                        "Notifications are disabled for PrivateMic in System Settings."
                    )
                }
            }
        }
    }

    func setPlaySound(_ enabled: Bool) {
        updatePreferences { $0.playSound = enabled }
    }

    func selectInputDevice(_ device: AudioDevice) {
        guard audioDeviceManager.currentDevice?.uid != device.uid else { return }
        let wasMuted = microphoneState == .muted

        do {
            let change = try audioDeviceManager.selectDefaultDevice(device)
            if wasMuted,
               preferences.keepMutedWhenDeviceChanges,
               let newDevice = change.new {
                try muteController.setMuted(true, device: newDevice)
                microphoneState = .muted
                preferences = preferencesStore.preferences
            } else {
                refreshMicrophoneState()
            }
            errorMessage = nil
        } catch {
            audioDeviceManager.refresh()
            refreshMicrophoneState()
            setError("The input microphone could not be changed. \(error.localizedDescription)")
        }
    }

    func resetSettings() {
        var loginError: String?
        do {
            try loginItemManager.setEnabled(false)
        } catch {
            logger.error("Could not disable login item while resetting: \(error.localizedDescription)")
            loginError = "Launch at Login could not be disabled. \(error.localizedDescription)"
        }
        shortcutManager.unregister()
        preferencesStore.reset()
        preferences = .defaults
        loginItemState = loginItemManager.state
        registerShortcut(preferences.shortcut, preservingOld: nil)
        synchronizeLoginPreference()
        if let loginError {
            setError(loginError)
        }
    }

    func openSettings() {
        if settingsWindowController == nil {
            let rootView = SettingsView().environmentObject(self)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "PrivateMic Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func quit() {
        shutdown()
        NSApplication.shared.terminate(nil)
    }

    func shutdown() {
        audioDeviceManager.stop()
        shortcutManager.unregister()
    }

    private func handleHardwareChange() {
        let wasMuted = microphoneState == .muted
        let change = audioDeviceManager.refresh()
        let changedDevice = change.old?.uid != change.new?.uid

        if changedDevice,
           wasMuted,
           preferences.keepMutedWhenDeviceChanges,
           let newDevice = change.new {
            do {
                try muteController.setMuted(true, device: newDevice)
                microphoneState = .muted
                preferences = preferencesStore.preferences
                errorMessage = nil
            } catch {
                setError(
                    "The new microphone could not be kept muted. \(error.localizedDescription)"
                )
                refreshMicrophoneState()
            }
        } else {
            refreshMicrophoneState()
        }
    }

    private func refreshMicrophoneState() {
        do {
            microphoneState = try muteController.state(of: audioDeviceManager.currentDevice)
            if let deviceError = audioDeviceManager.errorMessage {
                setError(deviceError)
            }
        } catch {
            microphoneState = audioDeviceManager.currentDevice == nil ? .unavailable : .unsupported
            setError("The microphone state could not be read. \(error.localizedDescription)")
        }
    }

    private func registerShortcut(_ shortcut: Shortcut, preservingOld old: Shortcut?) {
        do {
            try shortcutManager.register(shortcut) { [weak self] in self?.toggleMute() }
            updatePreferences { $0.shortcut = shortcut }
            errorMessage = nil
        } catch {
            if let old {
                try? shortcutManager.register(old) { [weak self] in self?.toggleMute() }
            }
            setError(error.localizedDescription)
        }
    }

    private func synchronizeLoginPreference() {
        loginItemState = loginItemManager.state
        let registered = loginItemState == .enabled || loginItemState == .requiresApproval
        updatePreferences { $0.launchAtLogin = registered }
    }

    private func updatePreferences(_ change: (inout AppPreferences) -> Void) {
        var latest = preferencesStore.preferences
        change(&latest)
        preferencesStore.preferences = latest
        preferences = latest
    }

    private func setError(_ message: String) {
        errorMessage = message
        logger.error("\(message, privacy: .public)")
    }
}
