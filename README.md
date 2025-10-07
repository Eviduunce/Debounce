# KCBforMac - Keyboard Chatter Blocker for macOS

macOS port of FreneticLLC's Windows Keyboard Chatter Blocker application.

See https://github.com/FreneticLLC/KeyboardChatterBlocker for more info.

## 🚀 Quick Start

### 1. Grant Accessibility Permissions

**CRITICAL**: The app MUST have Accessibility permissions to intercept keyboard events.

1. **First time**: When you run the app, macOS will prompt you for accessibility permissions
2. Go to **System Settings** → **Privacy & Security** → **Accessibility**
3. Find **KCBforMac** in the list
4. Toggle it **ON**

### 3. Enable Chatter Blocking

1. Look for the **keyboard icon** in your menu bar (top-right of screen)
2. Click the icon
3. Click **"Enable"** in the menu
4. The icon should change from hollow to filled

### 4. Configure Settings

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

### App doesn't appear to block chatter

**Common Issues:**
1. **No accessibility permissions** → Check System Settings → Accessibility
2. **Blocker not enabled** → Check menu bar icon (should be filled, not hollow)
3. **Threshold too low** → Increase global threshold or add per-key threshold
4. **App not running** → Check Activity Monitor for "KCBforMac" process

### Can't find the app

This is a **menu bar app** (not a Dock app). Look in the top-right corner of your screen for a keyboard icon.

### Keyboard events not detected

Make sure accessibility permissions are granted in System Settings → Privacy & Security → Accessibility.

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

## 📝 Known Issues

- **Menu bar icon sometimes doesn't appear**: Restart the app or check Activity Monitor
- **macOS 13.0+ required**: Uses newer SwiftUI APIs
- **Accessibility permissions**: May need to be re-granted after rebuilding the app
- **Info.plist warning**: Xcode may show a warning about Info.plist in Copy Bundle Resources (this is harmless)

## 🔧 Requirements

- macOS 14.0 or later

### Key Files
- `EventInterceptor.swift` - CGEventTap implementation
- `ChatterBlocker.swift` - Core blocking logic
- `ConfigManager.swift` - Settings persistence
- `KCBforMacApp.swift` - Menu bar app & main logic

## 📜 License

Based on the original Windows Keyboard Chatter Blocker:
https://github.com/FreneticLLC/KeyboardChatterBlocker

The MIT License (MIT)

Copyright (c) 2019-2024 Alex "mcmonkey" Goodwin
Copyright (c) 2024-2025 Frenetic LLC

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
