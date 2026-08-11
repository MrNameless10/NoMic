import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var presentationObservation: AnyCancellable?

    private(set) var isInstalled = false
    private(set) var currentSymbolName = "exclamationmark.triangle"
    private(set) var currentTitle = ""

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.popover = NSPopover()

        configurePopover()
        configureStatusButton()

        presentationObservation = Publishers.CombineLatest(
            appState.$microphoneState,
            appState.$preferences
        )
            .sink { [weak self] state, preferences in
                self?.updateIcon(
                    for: state,
                    style: preferences.menuBarIconStyle
                )
            }
        updateIcon(
            for: appState.microphoneState,
            style: appState.preferences.menuBarIconStyle
        )
        isInstalled = statusItem.button != nil
    }

    func invalidate() {
        popover.close()
        presentationObservation = nil
        if isInstalled {
            NSStatusBar.system.removeStatusItem(statusItem)
            isInstalled = false
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 328, height: 350)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(appState)
        )
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("PrivateMic")
        button.setAccessibilityHelp(
            "Left-click for controls. Right-click to mute or unmute."
        )
        button.imagePosition = .imageOnly
    }

    private func updateIcon(
        for state: MicrophoneState,
        style: MenuBarIconStyle
    ) {
        let accessibilityValue: String
        switch state {
        case .muted: accessibilityValue = "Muted"
        case .unmuted: accessibilityValue = "Unmuted"
        case .unsupported, .unavailable: accessibilityValue = state.title
        }

        guard let button = statusItem.button else { return }
        statusItem.length = style == .text
            ? NSStatusItem.variableLength
            : NSStatusItem.squareLength

        if style == .text {
            let title: String
            switch state {
            case .muted: title = "MUTE"
            case .unmuted: title = "MIC"
            case .unsupported, .unavailable: title = "!"
            }
            currentSymbolName = ""
            currentTitle = title
            button.image = nil
            button.title = title
            button.font = .systemFont(ofSize: 10, weight: .semibold)
        } else {
            let symbolName = symbolName(for: state, style: style)
            currentSymbolName = symbolName
            currentTitle = ""
            button.title = ""
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            ) ?? NSImage(
                systemSymbolName: "mic.fill",
                accessibilityDescription: nil
            )
            let configuration = NSImage.SymbolConfiguration(
                pointSize: 15,
                weight: .medium
            )
            let configuredImage = image?.withSymbolConfiguration(configuration)
            configuredImage?.isTemplate = true
            button.image = configuredImage
        }

        button.toolTip = tooltip(for: state)
        button.setAccessibilityValue(accessibilityValue)
    }

    private func symbolName(
        for state: MicrophoneState,
        style: MenuBarIconStyle
    ) -> String {
        if state == .unsupported || state == .unavailable {
            return "exclamationmark.triangle"
        }

        switch style {
        case .microphone:
            return state == .muted ? "mic.slash.fill" : "mic.fill"
        case .microphoneOutline:
            return state == .muted ? "mic.slash" : "mic"
        case .stateBadge:
            return state == .muted ? "xmark.circle.fill" : "checkmark.circle.fill"
        case .text:
            return ""
        }
    }

    @objc
    private func statusItemClicked() {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            appState.toggleMute()
            return
        }

        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        }
    }

    private func tooltip(for state: MicrophoneState) -> String {
        let nextAction = state == .muted ? "unmute" : "mute"
        return "PrivateMic — \(state.title)\nLeft-click for controls. Right-click to \(nextAction)."
    }
}
