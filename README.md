# Debounce

A macOS menu bar utility that blocks keyboard chatter — the unintended duplicate keystrokes caused by mechanical switch contact bounce. It uses a `CGEventTap` to intercept key events system-wide and suppresses repeated presses that occur within a configurable time threshold.

Inspired by the Windows [Keyboard Chatter Blocker](https://github.com/FreneticLLC/KeyboardChatterBlocker).

## Important: Accessibility Permission

Debounce requires **Accessibility permission** to intercept keyboard events system-wide via `CGEventTap`. Without it, chatter blocking cannot run. macOS prompts on first use, or you can enable it manually:

**System Settings → Privacy & Security → Accessibility → Debounce → ON**

If Debounce already appears enabled there but still reports that permission is missing:

1. Click **Enable** in Debounce again.
2. In the permission alert, choose **Repair Permission**. This removes only Debounce's stale Accessibility entry, asks macOS for access again, and opens the correct settings panel.
3. Turn Debounce on in Accessibility settings, then return to the app. Debounce rechecks access and finishes enabling automatically.

Moving or replacing the app can cause macOS to revoke access. If that happens, grant permission again or use **Repair Permission**.

## Installation

1. Download the `.dmg` from the [latest release](https://github.com/Eviduunce/Debounce/releases/latest)
2. Open the DMG and drag `Debounce.app` to the Applications folder
3. Launch the app — it runs in the menu bar (no Dock icon)
4. Grant Accessibility permissions when prompted (see above)
5. Click the keyboard icon in the menu bar and select **Enable**

## Features

- **Global threshold** — blocks repeated presses of any key within a configurable window (default: 100ms)
- **Per-key thresholds** — set different thresholds for individual keys
- **Measurement mode** — measure interval from last key press or last key release
- **Minimum chatter time** — ignore ultra-fast events in chatter detection (for buggy hardware)
- **Statistics** — tracks press counts and blocked chatter per key
- **Live log** — shows blocked events with timestamps and time deltas

## How It Works

The app installs a `CGEventTap` at the session level (`headInsertEventTap`) that intercepts `keyDown` and `keyUp` events. For each key press, it checks the time elapsed since the previous press (or release) of the same key. If the interval is below the threshold, the event is dropped by returning `nil` from the tap callback. Key-held (repeat) events are detected via state tracking and passed through.

## Configuration

Settings are accessible from the menu bar icon → **Settings...**

| Tab | Description |
|-----|-------------|
| Settings | Global threshold slider (0–500ms), minimum chatter time, measurement mode |
| Keys | Add/remove per-key custom thresholds |
| Statistics | Press and blocked counts per key, sorted by most blocked |
| Log | Real-time list of blocked chatter events |

Settings persist via `UserDefaults`.

## Tested Hardware

- ASUS ROG Azoth — 100ms global threshold, no per-key overrides needed

## Requirements

- macOS 14.0+
- Accessibility permissions
- App Sandbox is disabled (required for `CGEventTap`)

## Building

- Xcode 15.0+
- Open `Debounce.xcodeproj` and build

Debug builds use the display name **Debounce Debug** and bundle identifier `com.leisengang.Debounce.debug`. The installed release remains **Debounce** with bundle identifier `com.leisengang.Debounce`. macOS tracks Accessibility consent by code identity, so Debug and Release appear as separate entries and must each be granted permission. This prevents an Xcode-signed development build from invalidating or reusing the installed release's permission.

### Project Structure

| File | Purpose |
|------|---------|
| `DebounceApp.swift` | App entry point, menu bar setup, `AppDelegate` |
| `EventInterceptor.swift` | `CGEventTap` creation and event routing |
| `ChatterBlocker.swift` | Core chatter detection logic |
| `ConfigManager.swift` | `UserDefaults` persistence |
| `SettingsView.swift` | SwiftUI settings UI (4 tabs) |
| `ChatterLogView.swift` | Live blocked-event log view |
| `KeyCodeMapper.swift` | Key code to human-readable name mapping |
| `PermissionHelper.swift` | Accessibility permission checks and prompts |

## License

MIT — see [LICENSE](LICENSE).
