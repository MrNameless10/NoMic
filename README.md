# PrivateMic

PrivateMic is a small, native macOS menu-bar application that toggles the current default input device. It is designed for personal, offline use and has no analytics, accounts, updater, telemetry, advertising, or network code.

Requirements: macOS 13 Ventura or later and Xcode 14.1 or later. The temporary product name is `PrivateMic`, the bundle identifier is `com.local.PrivateMic`, and the default shortcut is Control–Option–M (`⌃⌥M`).

## Ready-to-install build

The locally signed universal Release build is packaged at `Dist/PrivateMic-1.0.dmg`. Open the DMG and drag PrivateMic onto its Applications shortcut. It supports both Apple silicon and Intel Macs and retains the hardened runtime with intentionally empty entitlements.

The original icon master and its transparency-preparation source are in `Artwork/`. The complete macOS icon set is compiled from `PrivateMic/Assets.xcassets/AppIcon.appiconset`.

To reproduce the signed app and DMG after changing the source, run:

```sh
./Scripts/build-release.sh
```

The script uses only Xcode and built-in macOS tools. It creates temporary build directories under `/tmp`, verifies the application signature and disk-image checksum, and writes the finished DMG under `Dist/`.

## Architecture

- `CoreAudioHardware` discovers the default input device, reads and writes controls, and owns all Core Audio property listeners.
- `AudioDeviceManager` presents the current device and converts hardware callbacks into main-thread updates.
- `MuteController` selects native mute or volume fallback, verifies writes, and guards against device changes during an operation.
- `CarbonGlobalShortcutManager` registers exactly one global chord using the public Carbon hot-key API.
- `LoginItemManager`, `NotificationManager`, and `UserDefaultsPreferencesStore` wrap the other system services.
- `StatusItemController` owns an explicit AppKit `NSStatusItem` so the microphone icon remains in the macOS menu bar, and anchors the SwiftUI flyout popover to it.
- `AppState` is the `@MainActor` coordinator used by `MenuBarView` and `SettingsView`.

The protocols around hardware, preferences, shortcuts, login items, and feedback make the behavior testable without physical audio hardware.

Left-click the menu-bar icon to open PrivateMic's controls. Right-click the icon
to mute or unmute immediately. The icon intentionally remains compact so it does
not compete with monitoring tools and other menu-bar applications for space.

## How muting works

For the current default input device, PrivateMic first looks for a writable Core Audio `kAudioDevicePropertyMute` control in the input scope. A writable master control is preferred; otherwise all writable input-channel controls are used. It writes the requested value and reads every control back.

If native mute is unavailable, PrivateMic looks for writable `kAudioDevicePropertyVolumeScalar` input controls. Before muting, it stores the current nonzero values in `UserDefaults`, keyed by the device's stable Core Audio UID and by channel element. It writes zero and reads the values back. On unmute it restores only a valid snapshot for the same UID and the same control elements, then verifies the restored values. A saved value from another microphone is never used.

If neither control is writable, the device is shown as **Unsupported**. Some devices expose controls that appear writable but reject or ignore changes; read-back verification turns this into a visible error.

The app listens for changes to the system default input device, the hardware device list, and the active device's mute or volume properties. A new default device is not changed automatically unless **Keep muted when microphone changes** is enabled and the previous device was muted.

PrivateMic lists all currently connected devices that expose input channels. You
can change the system default microphone from the menu-bar flyout or the Device
tab in Settings. Core Audio reads the selected device back before PrivateMic
reports that the switch succeeded.

## Global shortcut

macOS does not provide a SwiftUI global-shortcut API. PrivateMic uses the stable, public Carbon `RegisterEventHotKey` API. It registers only the selected chord and does not install a global event tap, inspect ordinary typing, or require Accessibility/Input Monitoring access. A registration error is used to detect conflicts where macOS reports one; macOS cannot identify which other application owns a conflicting shortcut.

Click the shortcut field in Settings and press a new chord. At least one of Control, Option, Shift, or Command is required. If registration fails, the previous working shortcut remains registered.

## Permissions and privacy

PrivateMic does not record or process audio and does not open an audio input stream. Reading and changing Core Audio device-control properties does not require microphone-capture permission. It also does not need Accessibility, Input Monitoring, administrator access, a privileged helper, App Sandbox capabilities, or network entitlements.

If **Show notification when muting** is enabled, macOS asks for notification permission. That permission is used only for local mute/unmute notifications. Sound feedback uses local system sounds and needs no permission.

All preferences remain in the local preferences domain for `com.local.PrivateMic`. System logs contain only operational error descriptions, not audio, keystrokes, or personal data. The source contains no URL loading, sockets, analytics, crash-reporting SDK, package dependencies, or updater.

## Build and run

1. Install Xcode for free from the Mac App Store. A paid Apple Developer account is not required.
2. Open `PrivateMic.xcodeproj` in Xcode.
3. Select the **PrivateMic** scheme and **My Mac** as the run destination.
4. Open the project editor, choose the PrivateMic target, then **Signing & Capabilities**.
5. Leave **Automatically manage signing** enabled. Select your free **Personal Team** if Xcode offers one. For a build run only on the same Mac, **Sign to Run Locally** or ad-hoc signing also works.
6. Press Command-R. PrivateMic launches silently into the menu bar; it does not show a Dock icon or open Settings automatically.
7. Run unit tests with Command-U.

There are no packages to download and the application builds offline after Xcode is installed.

### Release build and installation

In Xcode, select **Product → Scheme → Edit Scheme**, choose **Run**, and select the Release build configuration, then choose **Product → Build**. A normal Release product is under:

```text
~/Library/Developer/Xcode/DerivedData/PrivateMic-*/Build/Products/Release/PrivateMic.app
```

To reveal the exact result, expand **Products** in Xcode's project navigator, right-click `PrivateMic.app`, and choose **Show in Finder**. Quit any running copy, then drag or copy the app into `/Applications`. Open `/Applications/PrivateMic.app` once and keep that installed copy; moving a registered login item later can require registering it again.

For a conventional archived build, choose **Product → Archive**, select the archive in Organizer, choose **Distribute App → Custom → Copy App**, and copy the exported app to `/Applications`. This local workflow does not require App Store submission or a paid account.

### Gatekeeper and signing troubleshooting

- Build the app yourself in Xcode and open it from `/Applications`; locally built development-signed apps normally open without further steps.
- If macOS blocks it, Control-click the app in Finder, choose **Open**, then confirm **Open**. Alternatively use **System Settings → Privacy & Security → Open Anyway** after one blocked launch.
- If signing fails, select a valid Personal Team, make the bundle identifier unique (for example `com.yourname.PrivateMic`), then use **Product → Clean Build Folder** and build again.
- If the app was modified after signing, rebuild it. Do not disable Gatekeeper or System Integrity Protection.
- A warning shown when transferring the app to another Mac is expected for a locally signed, non-notarized build. Notarization generally requires a paid developer membership; it is unnecessary for personal use on the build Mac.

## Launch at Login

Enable **Launch at Login** in PrivateMic Settings. The app calls `SMAppService.mainApp.register()` and then displays the service's real registration state. If macOS requires approval, open **System Settings → General → Login Items**, find PrivateMic, and allow it. Disable the setting to unregister it.

Launch at Login works most reliably after the finished app has been copied to `/Applications`. The app always launches directly into the menu bar.

## Changing the name or bundle identifier

To rename the app, select the PrivateMic target in Xcode and change **Product Name** under Build Settings. Rename the scheme and source folder only if desired; they do not determine the installed display name.

To change the bundle identifier, edit **Signing & Capabilities → Bundle Identifier**, or change `PRODUCT_BUNDLE_IDENTIFIER` in both target build configurations. If tests are retained, also give the test target a matching unique test identifier. The logger subsystem strings and the UserDefaults domain are currently `com.local.PrivateMic`; change those literal strings if settings and logs should move to the new identity. Changing identity creates a separate preferences domain and requires Launch at Login to be enabled again.

## Known limitations

- Hardware and drivers decide which Core Audio controls exist. A microphone with neither writable mute nor writable input volume cannot be muted reliably.
- A volume-only device that is already at zero before PrivateMic sees a nonzero level has no safe volume to restore. PrivateMic reports an error instead of guessing.
- On a volume-fallback device, another application can also set input volume to zero. Core Audio does not expose ownership of that change, so zero is displayed as muted.
- Some Bluetooth devices temporarily vanish or replace their Core Audio device identity while reconnecting. PrivateMic displays no device during that interval and refreshes when Core Audio reports the device again.
- Hot-key conflicts can be reported when registration fails, but public APIs do not reveal the owning application and cannot detect every application-specific shortcut policy.
- Local notifications depend on the user's macOS notification settings and Focus mode.
- This project is locally signed and not notarized by default, so moving it to a different Mac can produce a Gatekeeper warning.

## Manual testing checklist

Before relying on PrivateMic in calls, test the devices you use:

- [ ] Build and run on macOS 13 or later; verify there is a menu-bar icon and no Dock icon.
- [ ] Built-in microphone: mute, verify the icon/status, unmute, and confirm input returns.
- [ ] AirPods: connect, select as default input, mute/unmute, disconnect, and reconnect.
- [ ] Bluetooth headset: repeat mute/unmute during a normal connection and after reconnection.
- [ ] Wired headset microphone: connect, select, toggle, and disconnect while the menu is open.
- [ ] USB microphone: test both native mute and volume-fallback reporting, if supported by the hardware.
- [ ] Unsupported device: verify the warning is clear and the mute action is disabled.
- [ ] No input device: verify **No microphone** appears without a crash.
- [ ] Change the default input device while unmuted; verify the new device is not changed.
- [ ] Change devices while muted with **Keep muted when microphone changes** disabled; verify the new device is not changed.
- [ ] Repeat with that setting enabled; verify the new device is muted or a clear error appears.
- [ ] Change mute or input volume outside PrivateMic; verify the menu status updates.
- [ ] Unplug a device during a toggle; verify an error appears and no other device's volume is restored.
- [ ] Record a new valid shortcut and test it while another application is active.
- [ ] Try a plain letter with no modifier and verify it is rejected.
- [ ] Try an already registered global shortcut and verify the previous shortcut remains active.
- [ ] Enable notification feedback, approve permission, and verify muted/unmuted notices.
- [ ] Enable and disable sound feedback independently.
- [ ] Copy the Release app to `/Applications`, enable Launch at Login, log out and in, and verify silent menu-bar launch.
- [ ] Restart the Mac and repeat the login-item check.
- [ ] Reset settings and verify the default shortcut/options return and the login item is disabled.

## Automated tests

The XCTest target covers preference serialization/reset, per-device volume isolation, native and fallback mute transitions, write verification, device changes, shortcut validation, and launch-at-login behavior through mocks. The tests do not need an actual microphone.
