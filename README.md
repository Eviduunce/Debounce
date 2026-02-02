# KCBforMac - Keyboard Chatter Blocker for macOS

Stop annoying double-typing caused by mechanical keyboard chatter.

KCBforMac prevents unwanted repeated keystrokes by blocking key presses that occur too quickly in succession. Set a global threshold or configure individual keys that misbehave.

## 🚀 Quick Start

### 1. Grant Accessibility Permissions

**CRITICAL**: The app MUST have Accessibility permissions to intercept keyboard events.

1. **First time**: When you run the app, macOS will prompt you for accessibility permissions
2. Go to **System Settings** → **Privacy & Security** → **Accessibility**
3. Find **KCBforMac** in the list
4. Toggle it **ON**

### 2. Enable Chatter Blocking

1. Look for the **keyboard icon** in your menu bar (top-right of screen)
2. Click the icon
3. Click **"Enable"** in the menu
4. The icon should change from hollow to filled

### 3. Configure Settings

1. Click the menu bar icon
2. Select **"Settings..."**
3. **Settings Tab**: Adjust global threshold (default: 100ms)
4. **Keys Tab**: Add per-key thresholds for problematic keys
5. **Statistics Tab**: Shows statistics of all keys, including blocked keystrokes
6. **Log Tab**: View real-time chatter blocking events

## 📊 How It Works

- **Global Threshold**: Blocks any key press that occurs within X milliseconds of the previous press
- **Per-Key Threshold**: Set custom thresholds for specific keys that chatter more
- **Timing**: Measures from last key press (or release, if configured)

## 🔍 Troubleshooting

### Can't find the app

This is a **menu bar app** (not a Dock app). Look in the top-right corner of your screen for a keyboard icon.

### Chatter blocking not working

1. **Check accessibility permissions**: Go to System Settings → Privacy & Security → Accessibility and make sure KCBforMac is enabled
2. **Enable the blocker**: Click the menu bar icon and select "Enable" (icon should be filled, not hollow)
3. **Adjust threshold**: Try increasing the global threshold in Settings, or add a custom threshold for specific problematic keys

## ⚙️ Configuration Tips

### Example for a chattering 'H' key:

1. Open Settings → Keys tab
2. Click "Add Key"
3. Press the 'H' key when prompted (ESC to cancel)
4. Set a custom threshold (e.g., 150ms)
5. Click "Add" to save

### Testing chatter detection:

1. Open Settings → Log tab
2. Type naturally
3. Watch for entries showing blocked events with time deltas

## 📝 Requirements

- macOS 14.0 or later
- Accessibility permissions (app will prompt on first launch)

## 🔧 Development

### Build Requirements
- macOS 14.0 or later
- Xcode 15.0 or later
- App Sandbox **DISABLED** (required for CGEventTap)

### Key Files
- `EventInterceptor.swift` - CGEventTap implementation
- `ChatterBlocker.swift` - Core blocking logic
- `ConfigManager.swift` - Settings persistence
- `KCBforMacApp.swift` - Menu bar app & main logic

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.

Inspired by the original Windows [Keyboard Chatter Blocker](https://github.com/FreneticLLC/KeyboardChatterBlocker) by Alex "mcmonkey" Goodwin / Frenetic LLC.
