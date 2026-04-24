# Changelog

All notable changes to Debounce are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[SemVer](https://semver.org/spec/v2.0.0.html).

## [1.2] — 2026-04-24

### Fixed
- Accessibility permission alert was silently suppressed after the first
  time it had ever been shown. Clicking **Enable** in the menu bar without
  granted permission now reliably surfaces the alert every time, instead of
  being a no-op.

### Changed
- Lowered minimum macOS requirement from 26 (Tahoe) to 14 (Sonoma).
- Settings copy clarified: the "minimum chatter time" field now describes
  itself as ignored by chatter detection rather than always-blocked.

### Internal
- The event-tap-died notification now requests notification authorization
  before posting, so the notification reliably appears on first occurrence.

## [1.1] — 2026-02-03

### Added
- Auto-save settings on change (manual Save button removed).
- Reset to Defaults with confirmation dialog.
- Launch at Login via system service.
- Menu bar icon flashes when chatter is blocked.
- Colored status text (green when enabled).
- Statistics persist across app launches (saved every 30s and on quit).
- Copy Log button for exporting the chatter log.
- Search/filter for statistics when many keys are tracked.
- Duplicate key detection in per-key threshold capture, with option to
  update the existing threshold.
- System notification when the event tap dies, with automatic re-enable
  attempt on recoverable failures.

### Changed
- Menu updates in-place instead of rebuilding.
- Menu bar icon uses a lighter weight matching system style.
- Larger key capture sheet with animation feedback.

### Fixed
- "ms" label appearing twice and breaking across lines in Settings form.
- Menu bar icon being too thick compared to system icons.

## [1.0] — 2026-02-03

Initial public release. Keyboard chatter blocker for macOS with global
and per-key thresholds, live log, per-key statistics, and a menu bar UI.
