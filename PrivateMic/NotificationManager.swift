import AppKit
import Foundation
import UserNotifications

protocol NotificationManaging: AnyObject {
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    func provideFeedback(
        state: MicrophoneState,
        notification: Bool,
        audio: AudioFeedback
    )
}

final class NotificationManager: NotificationManaging {
    private let speechSynthesizer = NSSpeechSynthesizer()

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) {
            granted, _ in
            completion(granted)
        }
    }

    func provideFeedback(
        state: MicrophoneState,
        notification: Bool,
        audio: AudioFeedback
    ) {
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
        play(audio, for: state)
    }

    private func play(_ audio: AudioFeedback, for state: MicrophoneState) {
        if audio == .spoken {
            speechSynthesizer.stopSpeaking()
            speechSynthesizer.startSpeaking(
                state == .muted ? "Microphone off" : "Microphone on"
            )
            return
        }

        guard let name = audio.soundName else { return }
        if NSSound(named: NSSound.Name(name))?.play() != true {
            NSSound.beep()
        }
    }
}
