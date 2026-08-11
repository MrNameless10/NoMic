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

enum AudioFeedback: String, Codable, CaseIterable, Identifiable {
    case none
    case tink
    case pop
    case glass
    case basso
    case spoken

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .tink: return "Tink"
        case .pop: return "Pop"
        case .glass: return "Glass"
        case .basso: return "Basso"
        case .spoken: return "Spoken announcement"
        }
    }

    var soundName: String? {
        switch self {
        case .tink: return "Tink"
        case .pop: return "Pop"
        case .glass: return "Glass"
        case .basso: return "Basso"
        case .none, .spoken: return nil
        }
    }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable {
    case microphone
    case microphoneOutline
    case stateBadge
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .microphone: return "Filled microphone"
        case .microphoneOutline: return "Outline microphone"
        case .stateBadge: return "Status badge"
        case .text: return "Text status"
        }
    }

    var previewSymbol: String {
        switch self {
        case .microphone: return "mic.fill"
        case .microphoneOutline: return "mic"
        case .stateBadge: return "checkmark.circle.fill"
        case .text: return "textformat"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var shortcut = Shortcut.defaultShortcut
    var launchAtLogin = false
    var keepMutedWhenDeviceChanges = false
    var showNotification = false
    var mutedFeedback = AudioFeedback.none
    var unmutedFeedback = AudioFeedback.none
    var menuBarIconStyle = MenuBarIconStyle.microphone
    var previousVolumes: [String: DeviceVolumeSnapshot] = [:]

    static let defaults = AppPreferences()

    private enum CodingKeys: String, CodingKey {
        case shortcut
        case launchAtLogin
        case keepMutedWhenDeviceChanges
        case showNotification
        case mutedFeedback
        case unmutedFeedback
        case menuBarIconStyle
        case previousVolumes
        case playSound
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortcut = try container.decodeIfPresent(Shortcut.self, forKey: .shortcut)
            ?? .defaultShortcut
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)
            ?? false
        keepMutedWhenDeviceChanges = try container.decodeIfPresent(
            Bool.self, forKey: .keepMutedWhenDeviceChanges
        ) ?? false
        showNotification = try container.decodeIfPresent(Bool.self, forKey: .showNotification)
            ?? false

        let legacyPlaySound = try container.decodeIfPresent(Bool.self, forKey: .playSound)
            ?? false
        mutedFeedback = try container.decodeIfPresent(
            AudioFeedback.self, forKey: .mutedFeedback
        ) ?? (legacyPlaySound ? .tink : .none)
        unmutedFeedback = try container.decodeIfPresent(
            AudioFeedback.self, forKey: .unmutedFeedback
        ) ?? (legacyPlaySound ? .pop : .none)
        menuBarIconStyle = try container.decodeIfPresent(
            MenuBarIconStyle.self, forKey: .menuBarIconStyle
        ) ?? .microphone
        previousVolumes = try container.decodeIfPresent(
            [String: DeviceVolumeSnapshot].self, forKey: .previousVolumes
        ) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shortcut, forKey: .shortcut)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(keepMutedWhenDeviceChanges, forKey: .keepMutedWhenDeviceChanges)
        try container.encode(showNotification, forKey: .showNotification)
        try container.encode(mutedFeedback, forKey: .mutedFeedback)
        try container.encode(unmutedFeedback, forKey: .unmutedFeedback)
        try container.encode(menuBarIconStyle, forKey: .menuBarIconStyle)
        try container.encode(previousVolumes, forKey: .previousVolumes)
    }
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
