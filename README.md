# KCBforMac

A macOS menu bar utility that blocks keyboard chatter — the unintended duplicate keystrokes caused by mechanical switch contact bounce. It uses a `CGEventTap` to intercept key events system-wide and suppresses repeated presses that occur within a configurable time threshold.

Inspired by the Windows [Keyboard Chatter Blocker](https://github.com/FreneticLLC/KeyboardChatterBlocker).

## Setup

The app requires **Accessibility permissions** to intercept keyboard events via `CGEventTap`.

1. Launch the app — it runs in the menu bar (no Dock icon)
2. macOS will prompt for accessibility access, or grant it manually:
   **System Settings → Privacy & Security → Accessibility → KCBforMac → ON**
3. Click the keyboard icon in the menu bar and select **Enable**

## Features

- **Global threshold** — blocks repeated presses of any key within a configurable window (default: 100ms)
- **Per-key thresholds** — set different thresholds for individual keys
- **Measurement mode** — measure interval from last key press or last key release
- **Minimum chatter time** — ignore events faster than a floor value (for buggy hardware)
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
- Open `KCBforMac.xcodeproj` and build

### Project Structure

| File | Purpose |
|------|---------|
| `KCBforMacApp.swift` | App entry point, menu bar setup, `AppDelegate` |
| `EventInterceptor.swift` | `CGEventTap` creation and event routing |
| `ChatterBlocker.swift` | Core chatter detection logic |
| `ConfigManager.swift` | `UserDefaults` persistence |
| `SettingsView.swift` | SwiftUI settings UI (4 tabs) |
| `ChatterLogView.swift` | Live blocked-event log view |
| `KeyCodeMapper.swift` | Key code to human-readable name mapping |
| `PermissionHelper.swift` | Accessibility permission checks and prompts |

## License

MIT — see [LICENSE](LICENSE).
