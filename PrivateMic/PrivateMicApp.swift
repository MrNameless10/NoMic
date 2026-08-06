import AppKit
import SwiftUI

@main
struct PrivateMicApp: App {
    @NSApplicationDelegateAdaptor(PrivateMicAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class PrivateMicAppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let state = AppState()
        appState = state
        statusItemController = StatusItemController(appState: state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.invalidate()
        appState?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }
}
