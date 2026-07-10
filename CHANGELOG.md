# Changelog

All notable changes to Debounce are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[SemVer](https://semver.org/spec/v2.0.0.html).

## [1.3] — 2026-07-10

### Added
- A bundle-scoped **Repair Permission** action removes a stale Accessibility
  entry, requests access again, and opens the Accessibility settings panel.
- Automated tests for chatter timing, configuration persistence, event-tap
  failure mapping and cleanup, permission repair, and blocking-state
  transitions.

### Fixed
- Accessibility permission recovery now uses the native macOS prompt and
  automatically retries a pending enable when Debounce becomes active again.
- Missing Accessibility permission, event-tap creation failure, and run-loop
  source failure are reported as distinct outcomes instead of one generic
  failure.
- Event callbacks now return borrowed events without retaining them, avoiding
  passed-event leaks. Failed taps and run-loop resources are cleaned up
  correctly.
- A global threshold of `0` now survives relaunch instead of being replaced by
  the default value.
- Blocking's persisted and visible enabled state now remains consistent when
  permission or event-tap startup fails.
- Launch at Login errors are surfaced to the user. Pending Login Items approval
  is not treated as enabled and links directly to the relevant System Settings
  panel.

### Changed
- Xcode Debug builds are now **Debounce Debug** with bundle identifier
  `com.leisengang.Debounce.debug`; release builds remain **Debounce** with
  `com.leisengang.Debounce`. Their Accessibility permissions no longer collide.
- Release metadata is now version 1.3, build 3. Clean universal Release-build
  verification prepares deterministic packaging without reusing arbitrary
  DerivedData products.

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
