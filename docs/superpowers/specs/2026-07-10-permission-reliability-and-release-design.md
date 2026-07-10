# Permission Reliability and Release Design

**Date:** 2026-07-10
**Release:** 1.3

## Goal

Make Debounce reliably recognize and recover Accessibility permission, prevent development builds from invalidating release permissions, address high-impact audit findings, and produce a deterministic signed and notarized DMG.

## Confirmed Root Cause

macOS TCC logs show that the saved Accessibility decision for `com.leisengang.Debounce` requires the Apple Development certificate `TA86545USJ`. The installed 1.2 application uses the Developer ID certificate for team `ZH6399Z6NR`. TCC rejects the installed binary because its code requirement does not match the saved development-build requirement, even while System Settings displays an enabled Debounce entry.

Debug and Release currently use the same bundle identifier, so running the app from Xcode can create this collision. The release script also locates an arbitrary existing Release product in DerivedData and re-signs it in place, which makes the packaged input stale and non-deterministic.

## Architecture

### Build Identity Separation

The Release configuration retains `com.leisengang.Debounce`. The Debug configuration uses `com.leisengang.Debounce.debug`, ensuring that Apple Development and Developer ID builds have independent TCC records. The Debug application will use a distinct display name so both entries are understandable in System Settings.

### Permission State and Recovery

Permission checking remains based on `AXIsProcessTrustedWithOptions`, the system API that reports whether the current process is a trusted Accessibility client. Production code will wrap the system call behind an injectable boundary so state transitions can be unit tested without modifying the machine's TCC database.

When blocking is enabled:

1. Debounce checks the current process's Accessibility trust.
2. If trusted, it creates and enables the event tap.
3. If untrusted, it requests the native macOS Accessibility prompt and shows Debounce's recovery alert.
4. The alert offers normal access to Privacy & Security settings and an explicit stale-entry repair action.
5. The repair action runs `/usr/bin/tccutil reset Accessibility <current bundle identifier>`, only after the user selects it, then requests permission again and opens the Accessibility pane.
6. When Debounce becomes active after the user visits System Settings, it rechecks trust and automatically completes the pending enable request.

The app will never silently modify TCC state. Resetting is limited to Debounce's current bundle identifier and occurs only through the user-labeled repair action.

### Event Interceptor Results

Starting the interceptor will return a typed result rather than a bare Boolean:

- started successfully;
- Accessibility permission required;
- event tap creation failed;
- run-loop source creation failed.

This lets the app show accurate guidance instead of reporting every failure as missing permission. Partially created tap resources will be cleaned up before failure is returned.

### Application State

The requested enabled state and actual interceptor state will remain consistent. A failed startup disables and persists the setting unless a permission grant is pending. Menu text, icon state, settings state, and saved configuration will be refreshed together. Granting permission during the pending flow starts blocking automatically.

## Audit Fixes in Scope

- Return borrowed keyboard events without adding an unmanaged retain, preventing one leak per passed event.
- Clean up the event tap when run-loop source creation fails.
- Persist the disabled state after unrecoverable startup or tap failure.
- Preserve a configured global threshold of `0` across relaunches by distinguishing an absent preference from a stored zero.
- Surface launch-at-login registration errors and restore the toggle to the real service state.
- Ensure permission and event-tap failures produce different user-facing messages.
- Connect the existing untracked chatter tests to an XCTest target without discarding or overwriting them.

Unrelated visual redesigns and low-impact feature changes are outside this release.

## Testing

The project will gain a macOS XCTest target. Work proceeds test-first.

Automated coverage will include:

- the existing chatter timing cases with an injectable monotonic clock;
- a stored global threshold of zero loading as zero;
- permission already granted starting immediately;
- permission missing returning the permission-required result;
- failed event-tap and run-loop-source creation returning distinct errors and cleaning up resources;
- pending permission enablement retrying after trust changes;
- saved enabled state matching the actual running state.

The complete test suite, Debug build, Release build, and static analyzer must pass before packaging.

## Release Packaging

Version and build numbers advance to 1.3 and 3. The DMG script will:

1. clean and build a fresh universal Release product for `arm64` and `x86_64` into a project-controlled build directory;
2. verify that the built bundle reports version 1.3 and uses `com.leisengang.Debounce`;
3. sign the application with the configured Developer ID identity and hardened runtime;
4. verify the application signature and Gatekeeper assessment;
5. create a DMG containing `Debounce.app` and an Applications symlink;
6. sign and notarize the DMG with the configured keychain profile;
7. staple and validate the notarization ticket;
8. verify the disk image and its contained application before reporting the artifact path.

Signing identity and notary profile remain configurable through environment variables, with the current developer values as defaults. The script will not search or mutate DerivedData.

## Acceptance Criteria

- Xcode Debug and Developer ID Release builds no longer share a TCC identity.
- An existing stale Accessibility record leads to a clear, user-triggered repair flow.
- Granting permission allows a pending enable request to complete without repeatedly toggling Debounce.
- Non-permission event-tap failures are not mislabeled as permission failures.
- All automated tests, analysis, and Debug and universal Release builds pass.
- `build/Debounce-1.3.dmg` is signed, notarized, stapled, mountable, and contains the verified version 1.3 application.
