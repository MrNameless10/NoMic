import SwiftUI

@MainActor
struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case general
        case feedback
        case shortcut
        case device
    }

    @EnvironmentObject private var appState: AppState
    @State private var showingResetConfirmation = false
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            generalPane
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            feedbackPane
                .tabItem {
                    Label("Feedback", systemImage: "bell")
                }
                .tag(SettingsTab.feedback)

            shortcutPane
                .tabItem {
                    Label("Shortcut", systemImage: "command")
                }
                .tag(SettingsTab.shortcut)

            devicePane
                .tabItem {
                    Label("Device", systemImage: "mic")
                }
                .tag(SettingsTab.device)
        }
        .padding(12)
        .frame(width: 520, height: 500)
        .confirmationDialog(
            "Reset all PrivateMic settings?",
            isPresented: $showingResetConfirmation
        ) {
            Button("Reset Settings", role: .destructive) {
                appState.resetSettings()
            }
        }
    }

    private var generalPane: some View {
        Form {
            Section {
                statusCard
            }

            Section("Startup") {
                Toggle(
                    "Launch PrivateMic at Login",
                    isOn: binding(
                        \.launchAtLogin,
                        setter: { appState.setLaunchAtLogin($0) }
                    )
                )
                if appState.loginItemState == .requiresApproval {
                    Label(
                        "Approval is required in System Settings → General → Login Items.",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Section("Menu Bar") {
                Picker("Indicator style", selection: iconStyleSelection) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.previewSymbol)
                            .tag(style)
                    }
                }
                Text("The indicator changes immediately and always follows the microphone state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("No audio recording or audio sample processing", systemImage: "waveform.slash")
                Label("No analytics, tracking, or network requests", systemImage: "network.slash")
                    .foregroundStyle(.secondary)
            }

            errorSection

            Section {
                Button("Reset All Settings…", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
    }

    private var feedbackPane: some View {
        Form {
            Section("Notifications") {
                Toggle(
                    "Show a notification after toggling",
                    isOn: binding(
                        \.showNotification,
                        setter: { appState.setShowNotification($0) }
                    )
                )
            }

            Section("Audio Feedback") {
                feedbackPicker(
                    title: "When microphone turns off",
                    state: .muted,
                    selection: mutedFeedbackSelection
                )
                feedbackPicker(
                    title: "When microphone turns on",
                    state: .unmuted,
                    selection: unmutedFeedbackSelection
                )
            }

            Section {
                Label(
                    "Spoken feedback says “Microphone off” or “Microphone on” using macOS speech.",
                    systemImage: "speaker.wave.2"
                )
                Text("Mute and unmute sounds are selected independently. Everything plays locally and no microphone permission is needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            errorSection
        }
        .formStyle(.grouped)
    }

    private var shortcutPane: some View {
        Form {
            Section("Global Shortcut") {
                LabeledContent("Mute or unmute") {
                    ShortcutRecorderView(
                        shortcut: appState.preferences.shortcut,
                        onChange: appState.updateShortcut
                    )
                    .frame(width: 160, height: 26)
                }
                Text("Click the field, then press a shortcut containing at least one modifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu-Bar Controls") {
                Label("Left-click opens the PrivateMic controls.", systemImage: "cursorarrow.click")
                Label("Right-click mutes or unmutes immediately.", systemImage: "computermouse")
            }

            errorSection
        }
        .formStyle(.grouped)
    }

    private var devicePane: some View {
        Form {
            Section("Current Input Device") {
                Picker("Default microphone", selection: deviceSelection) {
                    if appState.audioDeviceManager.availableDevices.isEmpty {
                        Text("No input device").tag("")
                    } else {
                        ForEach(appState.audioDeviceManager.availableDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                }
                .disabled(appState.audioDeviceManager.availableDevices.isEmpty)
                LabeledContent("Status", value: appState.microphoneState.title)
                LabeledContent("Mute method", value: muteMethodName)
            }

            Section("Connected Inputs") {
                if appState.audioDeviceManager.availableDevices.isEmpty {
                    Label("No input devices found", systemImage: "mic.slash")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.audioDeviceManager.availableDevices) { device in
                        Button {
                            appState.selectInputDevice(device)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: device.muteMethod == .unsupported
                                    ? "exclamationmark.triangle"
                                    : "mic")
                                    .foregroundStyle(device.muteMethod == .unsupported
                                        ? .orange
                                        : .secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .foregroundStyle(.primary)
                                    Text(device.muteMethod.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if device.uid == appState.audioDeviceManager.currentDevice?.uid {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Device Changes") {
                Toggle(
                    "Keep muted when microphone changes",
                    isOn: binding(
                        \.keepMutedWhenDeviceChanges,
                        setter: { appState.setKeepMutedWhenDeviceChanges($0) }
                    )
                )
                Text(
                    "When disabled, connecting AirPods, USB audio, or another input device "
                        + "does not silently change that device."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Compatibility") {
                compatibilityLabel
                Text(compatibilityExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            errorSection
        }
        .formStyle(.grouped)
    }

    private var deviceSelection: Binding<String> {
        Binding(
            get: { appState.audioDeviceManager.currentDevice?.uid ?? "" },
            set: { uid in
                guard let device = appState.audioDeviceManager.availableDevices.first(
                    where: { $0.uid == uid }
                ) else { return }
                appState.selectInputDevice(device)
            }
        )
    }

    private var iconStyleSelection: Binding<MenuBarIconStyle> {
        Binding(
            get: { appState.preferences.menuBarIconStyle },
            set: { appState.setMenuBarIconStyle($0) }
        )
    }

    private var mutedFeedbackSelection: Binding<AudioFeedback> {
        Binding(
            get: { appState.preferences.mutedFeedback },
            set: { appState.setMutedFeedback($0) }
        )
    }

    private var unmutedFeedbackSelection: Binding<AudioFeedback> {
        Binding(
            get: { appState.preferences.unmutedFeedback },
            set: { appState.setUnmutedFeedback($0) }
        )
    }

    private func feedbackPicker(
        title: String,
        state: MicrophoneState,
        selection: Binding<AudioFeedback>
    ) -> some View {
        HStack {
            Picker(title, selection: selection) {
                ForEach(AudioFeedback.allCases) { feedback in
                    Text(feedback.displayName).tag(feedback)
                }
            }
            Button("Preview") {
                appState.previewFeedback(selection.wrappedValue, state: state)
            }
            .disabled(selection.wrappedValue == .none)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: statusSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(statusHeadline)
                    .font(.headline)
                Text(appState.audioDeviceManager.currentDevice?.name ?? "No input device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(appState.microphoneState.title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(statusColor.opacity(0.12)))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = appState.errorMessage {
            Section {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }
    }

    private var compatibilityLabel: some View {
        Label(
            muteMethodName,
            systemImage: isCompatible
                ? "checkmark.circle.fill"
                : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(isCompatible ? .green : .orange)
    }

    private var isCompatible: Bool {
        guard let method = appState.audioDeviceManager.currentDevice?.muteMethod else {
            return false
        }
        return method != .unsupported
    }

    private var muteMethodName: String {
        appState.audioDeviceManager.currentDevice?.muteMethod.displayName
            ?? MuteMethod.unsupported.displayName
    }

    private var compatibilityExplanation: String {
        switch appState.audioDeviceManager.currentDevice?.muteMethod {
        case .nativeMute:
            return "This microphone provides a native mute control that PrivateMic verifies after use."
        case .inputVolume:
            return "PrivateMic uses verified input-volume control and restores a value saved only for this device."
        case .unsupported, nil:
            return "This microphone does not currently expose a reliable writable mute or input-volume control."
        }
    }

    private func binding(
        _ keyPath: KeyPath<AppPreferences, Bool>,
        setter: @escaping @MainActor @Sendable (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { setter($0) }
        )
    }

    private var statusSymbol: String {
        switch appState.microphoneState {
        case .muted: return "mic.slash.fill"
        case .unmuted: return "mic.fill"
        case .unsupported, .unavailable: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch appState.microphoneState {
        case .muted: return .red
        case .unmuted: return .green
        case .unsupported, .unavailable: return .orange
        }
    }

    private var statusHeadline: String {
        switch appState.microphoneState {
        case .muted: return "Microphone muted"
        case .unmuted: return "Microphone is live"
        case .unsupported: return "Mute unavailable"
        case .unavailable: return "No microphone found"
        }
    }
}
