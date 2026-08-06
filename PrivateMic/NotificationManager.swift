import AppKit
import Foundation
import UserNotifications

protocol NotificationManaging: AnyObject {
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    func provideFeedback(state: MicrophoneState, notification: Bool, sound: Bool)
}

final class NotificationManager: NotificationManaging {
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) {
            granted, _ in
            completion(granted)
        }
    }

    func provideFeedback(state: MicrophoneState, notification: Bool, sound: Bool) {
        guard state == .muted || state == .unmuted else { return }
        if notification {
            let content = UNMutableNotificationContent()
            content.title = state == .muted ? "Microphone muted" : "Microphone unmuted"
            content.body = "PrivateMic changed the current input device."
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
        if sound {
            let name = state == .muted ? "Tink" : "Pop"
            if NSSound(named: NSSound.Name(name))?.play() != true {
                NSSound.beep()
            }
        }
    }
}
