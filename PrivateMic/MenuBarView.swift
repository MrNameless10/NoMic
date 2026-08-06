import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: statusSymbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusHeadline)
                            .font(.headline)
                        Text(deviceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    appState.toggleMute()
                } label: {
                    Label(primaryActionTitle, systemImage: primaryActionSymbol)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(primaryActionColor)
                .disabled(!canToggle)
                .keyboardShortcut(.space, modifiers: [])

                VStack(spacing: 8) {
                    devicePickerRow
                    Divider()
                    detailRow(
                        title: "Shortcut",
                        value: appState.preferences.shortcut.displayName,
                        symbol: "keyboard"
                    )
                    Divider()
                    detailRow(
                        title: "Mute method",
                        value: muteMethod,
                        symbol: "waveform"
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                if let error = appState.errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.09))
                    )
                }
            }
            .padding(16)

            Divider()

            HStack {
                Button {
                    appState.openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Right-click icon to toggle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    appState.quit()
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit PrivateMic")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
        .frame(width: 328)
    }

    private var deviceName: String {
        appState.audioDeviceManager.currentDevice?.name ?? "No input device"
    }

    private var muteMethod: String {
        appState.audioDeviceManager.currentDevice?.muteMethod.displayName
            ?? MuteMethod.unsupported.displayName
    }

    private var canToggle: Bool {
        appState.microphoneState != .unsupported
            && appState.microphoneState != .unavailable
    }

    private var primaryActionTitle: String {
        appState.microphoneState == .muted ? "Turn Microphone On" : "Mute Microphone"
    }

    private var primaryActionSymbol: String {
        appState.microphoneState == .muted ? "mic.fill" : "mic.slash.fill"
    }

    private var primaryActionColor: Color {
        appState.microphoneState == .muted ? .green : .red
    }

    private var statusHeadline: String {
        switch appState.microphoneState {
        case .muted: return "Microphone muted"
        case .unmuted: return "Microphone is live"
        case .unsupported: return "Mute unavailable"
        case .unavailable: return "No microphone found"
        }
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

    private var devicePickerRow: some View {
        Menu {
            if appState.audioDeviceManager.availableDevices.isEmpty {
                Text("No input devices")
            } else {
                ForEach(appState.audioDeviceManager.availableDevices) { device in
                    Button {
                        appState.selectInputDevice(device)
                    } label: {
                        if device.uid == appState.audioDeviceManager.currentDevice?.uid {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text("Input device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(deviceName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .disabled(appState.audioDeviceManager.availableDevices.isEmpty)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .lineLimit(1)
        }
    }
}
