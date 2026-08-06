import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var stateObservation: AnyCancellable?

    private(set) var isInstalled = false
    private(set) var currentSymbolName = "exclamationmark.triangle"

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.popover = NSPopover()

        configurePopover()
        configureStatusButton()

        stateObservation = appState.$microphoneState
            .sink { [weak self] state in
                self?.updateIcon(for: state)
            }
        updateIcon(for: appState.microphoneState)
        isInstalled = statusItem.button != nil
    }

    func invalidate() {
        popover.close()
        stateObservation = nil
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

    private func updateIcon(for state: MicrophoneState) {
        let symbolName: String
        let accessibilityValue: String
        switch state {
        case .muted:
            symbolName = "mic.slash.fill"
            accessibilityValue = "Muted"
        case .unmuted:
            symbolName = "mic.fill"
            accessibilityValue = "Unmuted"
        case .unsupported, .unavailable:
            symbolName = "exclamationmark.triangle"
            accessibilityValue = state.title
        }

        currentSymbolName = symbolName
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
        let configuration = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .medium
        )
        let configuredImage = image?.withSymbolConfiguration(configuration)
        configuredImage?.isTemplate = true
        statusItem.button?.image = configuredImage
        statusItem.button?.toolTip = tooltip(for: state)
        statusItem.button?.setAccessibilityValue(accessibilityValue)
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
