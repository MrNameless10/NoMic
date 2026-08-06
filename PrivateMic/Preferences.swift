import Carbon
import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let defaultShortcut = Shortcut(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: UInt32(controlKey | optionKey),
        key: "M"
    )

    var isValid: Bool {
        keyCode <= UInt32(UInt16.max)
            && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && modifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey) != 0
    }

    var displayName: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + key.uppercased()
    }
}

struct AppPreferences: Codable, Equatable {
    var shortcut = Shortcut.defaultShortcut
    var launchAtLogin = false
    var keepMutedWhenDeviceChanges = false
    var showNotification = false
    var playSound = false
    var previousVolumes: [String: DeviceVolumeSnapshot] = [:]

    static let defaults = AppPreferences()
}

protocol PreferencesStoring: AnyObject {
    var preferences: AppPreferences { get set }
    func reset()
}

final class UserDefaultsPreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "PrivateMic.preferences") {
        self.defaults = defaults
        self.key = key
    }

    var preferences: AppPreferences {
        get {
            guard let data = defaults.data(forKey: key),
                  let value = try? decoder.decode(AppPreferences.self, from: data) else {
                return .defaults
            }
            return value
        }
        set {
            guard let data = try? encoder.encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
