# Permission Reliability and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent Accessibility permission identity collisions, provide a reliable stale-permission recovery flow, fix high-impact audit findings, and ship a verified Debounce 1.3 DMG.

**Architecture:** Separate Debug and Release TCC identities at the build-setting level. Isolate macOS permission and event-tap APIs behind small injectable interfaces, return typed start failures, and centralize enable/disable transitions in `AppDelegate`. Build releases from a clean project-controlled directory and verify every signing and notarization boundary.

**Tech Stack:** Swift 5, SwiftUI/AppKit, ApplicationServices Accessibility APIs, CoreGraphics event taps, ServiceManagement, XCTest, Xcode 26 command-line tools, codesign, notarytool, stapler, hdiutil.

---

## File Map

- Modify `Debounce.xcodeproj/project.pbxproj`: add the XCTest target, separate Debug identity/display name, and bump Release version/build settings.
- Modify `Debounce/Info.plist`: make the display name configuration-specific.
- Modify `Debounce/ChatterBlocker.swift`: inject the monotonic clock required by the existing tests.
- Modify `Debounce/ConfigManager.swift`: make defaults injectable, preserve zero, and propagate launch-at-login errors.
- Modify `Debounce/SettingsView.swift`: bind blocking through the centralized transition callback and display launch-at-login failures.
- Modify `Debounce/PermissionHelper.swift`: wrap trust checks, native prompting, explicit TCC reset, and Settings navigation.
- Modify `Debounce/EventInterceptor.swift`: introduce typed results and an injectable event-tap driver; fix event ownership and cleanup.
- Modify `Debounce/DebounceApp.swift`: centralize blocking state, pending permission retries, and failure presentation.
- Preserve `DebounceTests/ChatterBlockerTests.swift`: connect the user's existing regression tests without replacing them.
- Create `DebounceTests/ConfigManagerTests.swift`: cover stored-zero behavior.
- Create `DebounceTests/EventInterceptorTests.swift`: cover permission and driver result mapping.
- Create `DebounceTests/BlockingControllerTests.swift`: cover pending permission and persisted enabled-state transitions in an extracted controller.
- Create `DebounceTests/PermissionHelperTests.swift`: cover bundle-scoped reset command construction without touching TCC.
- Modify `scripts/create-dmg.sh`: perform a clean deterministic universal build and full artifact verification.
- Modify `README.md`: document Debug/Release permission isolation and stale-entry recovery.
- Modify `CHANGELOG.md`: add the 1.3 release notes.

### Task 1: Connect the Existing Tests to Xcode

**Files:**
- Modify: `Debounce.xcodeproj/project.pbxproj`
- Preserve: `DebounceTests/ChatterBlockerTests.swift`

- [ ] **Step 1: Preserve the user's starting tests in git**

Run:

```bash
git add DebounceTests/ChatterBlockerTests.swift
git commit -m "test: preserve chatter blocker regressions"
```

Expected: only `DebounceTests/ChatterBlockerTests.swift` is committed; `docs/plans/` remains untracked.

- [ ] **Step 2: Add a macOS unit-test target**

Add a `DebounceTests` native target with product type `com.apple.product-type.bundle.unit-test`, a dependency on `Debounce`, a Sources phase backed by a filesystem-synchronized `DebounceTests` group, and these target build settings:

```text
BUNDLE_LOADER = "$(TEST_HOST)";
GENERATE_INFOPLIST_FILE = YES;
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_BUNDLE_IDENTIFIER = com.leisengang.DebounceTests;
SWIFT_VERSION = 5.0;
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Debounce.app/Contents/MacOS/Debounce";
```

Add `DebounceTests` to the shared scheme's Test action. If Xcode does not generate a shared scheme automatically, create `Debounce.xcodeproj/xcshareddata/xcschemes/Debounce.xcscheme` containing both the app build action entry and the `DebounceTests.xctest` testable reference.

- [ ] **Step 3: Run the test and verify RED**

Run:

```bash
xcodebuild test \
  -project Debounce.xcodeproj \
  -scheme Debounce \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DebounceTestsDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure at `ChatterBlocker(now:)` because the production initializer does not exist yet. This proves the existing test is connected.

### Task 2: Make Chatter Timing Deterministic

**Files:**
- Modify: `Debounce/ChatterBlocker.swift`
- Test: `DebounceTests/ChatterBlockerTests.swift`

- [ ] **Step 1: Add the minimal injected clock**

Add:

```swift
private let now: () -> UInt64

init(now: @escaping () -> UInt64 = {
    UInt64(ProcessInfo.processInfo.systemUptime * 1_000)
}) {
    self.now = now
}

private func getCurrentTime() -> UInt64 {
    now()
}
```

Remove the hard-coded `ProcessInfo` implementation from `getCurrentTime()`.

- [ ] **Step 2: Run the connected tests and verify GREEN**

Run the Task 1 test command.

Expected: all three `ChatterBlockerTests` pass.

- [ ] **Step 3: Commit the timing seam**

```bash
git add Debounce/ChatterBlocker.swift Debounce.xcodeproj
git commit -m "test: make chatter timing deterministic"
```

### Task 3: Fix Configuration Persistence and Login Errors

**Files:**
- Create: `DebounceTests/ConfigManagerTests.swift`
- Modify: `Debounce/ConfigManager.swift`
- Modify: `Debounce/SettingsView.swift`

- [ ] **Step 1: Write a failing stored-zero regression test**

Create:

```swift
import XCTest
@testable import Debounce

final class ConfigManagerTests: XCTestCase {
    func testLoadsStoredZeroGlobalThreshold() {
        let suiteName = "ConfigManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(0, forKey: "globalThreshold")

        let blocker = ChatterBlocker()
        blocker.globalThreshold = 100
        let manager = ConfigManager(defaults: defaults, migrateLegacySettings: false)

        manager.loadSettings(into: blocker)

        XCTAssertEqual(blocker.globalThreshold, 0)
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcodebuild test \
  -project Debounce.xcodeproj \
  -scheme Debounce \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DebounceTestsDerivedData \
  -only-testing:DebounceTests/ConfigManagerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because the injectable initializer is missing.

- [ ] **Step 3: Make defaults injectable and distinguish missing from zero**

Change the manager setup to:

```swift
private let defaults: UserDefaults

init(defaults: UserDefaults = .standard, migrateLegacySettings: Bool = true) {
    self.defaults = defaults
    if migrateLegacySettings {
        migrateFromOldBundleIfNeeded()
    }
}
```

Load the threshold only when the key exists:

```swift
if defaults.object(forKey: Keys.globalThreshold) != nil {
    blocker.globalThreshold = UInt64(max(0, defaults.integer(forKey: Keys.globalThreshold)))
}
```

- [ ] **Step 4: Propagate login registration errors**

Change:

```swift
func setStartAtLogin(_ enabled: Bool) throws {
    if enabled {
        try SMAppService.mainApp.register()
    } else {
        try SMAppService.mainApp.unregister()
    }
}
```

In `SettingsView`, add `@State private var launchAtLoginError: String?`, catch the error from the toggle, restore `launchAtLogin = configManager.getStartAtLogin()`, and present an alert with the error's localized description.

- [ ] **Step 5: Verify GREEN and commit**

Run the full test command from Task 1, then:

```bash
git add Debounce/ConfigManager.swift Debounce/SettingsView.swift DebounceTests/ConfigManagerTests.swift
git commit -m "fix: preserve configuration values and login errors"
```

### Task 4: Return Typed Event-Interceptor Results

**Files:**
- Create: `DebounceTests/EventInterceptorTests.swift`
- Modify: `Debounce/EventInterceptor.swift`
- Modify: `Debounce/PermissionHelper.swift`

- [ ] **Step 1: Write failing coordinator tests**

Create test doubles and tests with this public behavior:

```swift
private struct StubPermissionChecker: AccessibilityPermissionChecking {
    let trusted: Bool
    func isAccessibilityTrusted(prompt: Bool) -> Bool { trusted }
}

private final class StubEventTapDriver: EventTapDriving {
    let result: EventTapDriverStartResult
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var onTapDied: (() -> Void)?

    init(result: EventTapDriverStartResult) { self.result = result }
    func start() -> EventTapDriverStartResult { startCount += 1; return result }
    func stop() { stopCount += 1 }
}

final class EventInterceptorTests: XCTestCase {
    func testMissingPermissionDoesNotAttemptTapCreation() {
        let driver = StubEventTapDriver(result: .started)
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: false),
            driver: driver
        )

        XCTAssertEqual(interceptor.start(), .accessibilityPermissionRequired)
        XCTAssertEqual(driver.startCount, 0)
    }

    func testMapsTapCreationFailure() {
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: StubEventTapDriver(result: .tapCreationFailed)
        )

        XCTAssertEqual(interceptor.start(), .eventTapCreationFailed)
    }

    func testMapsRunLoopSourceFailure() {
        let interceptor = EventInterceptor(
            chatterBlocker: ChatterBlocker(),
            permissionChecker: StubPermissionChecker(trusted: true),
            driver: StubEventTapDriver(result: .runLoopSourceCreationFailed)
        )

        XCTAssertEqual(interceptor.start(), .runLoopSourceCreationFailed)
    }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run `-only-testing:DebounceTests/EventInterceptorTests` using the Task 3 command.

Expected: compile failures for the new protocols, enums, and initializer.

- [ ] **Step 3: Add the permission-checking boundary**

Define:

```swift
protocol AccessibilityPermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
}
```

Make `PermissionHelper` conform using `AXIsProcessTrustedWithOptions` and `kAXTrustedCheckOptionPrompt`.

- [ ] **Step 4: Extract the CoreGraphics driver**

Define:

```swift
enum EventTapDriverStartResult: Equatable {
    case started
    case tapCreationFailed
    case runLoopSourceCreationFailed
}

protocol EventTapDriving: AnyObject {
    var onTapDied: (() -> Void)? { get set }
    func start() -> EventTapDriverStartResult
    func stop()
}

enum EventInterceptorStartResult: Equatable {
    case started
    case accessibilityPermissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed
}
```

Move CoreGraphics tap ownership and the callback into `CoreGraphicsEventTapDriver`. Its source-failure path must invalidate and clear the newly created tap before returning `.runLoopSourceCreationFailed`.

`EventInterceptor.start()` must check trust first, stop the prior driver, start the driver, and map its typed result.

- [ ] **Step 5: Fix event ownership**

Every callback path that passes through the borrowed event must return:

```swift
Unmanaged.passUnretained(event)
```

Blocked events continue to return `nil`. Do not use `passRetained`.

- [ ] **Step 6: Verify GREEN and commit**

Run the full test suite, then:

```bash
git add Debounce/EventInterceptor.swift Debounce/PermissionHelper.swift DebounceTests/EventInterceptorTests.swift
git commit -m "fix: distinguish permission and event tap failures"
```

### Task 5: Implement Explicit Permission Recovery

**Files:**
- Create: `DebounceTests/PermissionHelperTests.swift`
- Modify: `Debounce/PermissionHelper.swift`

- [ ] **Step 1: Write a failing bundle-scoped reset test**

Create:

```swift
import XCTest
@testable import Debounce

final class PermissionHelperTests: XCTestCase {
    func testResetIsScopedToCurrentBundleIdentifier() throws {
        var capturedArguments: [String] = []
        let helper = PermissionHelper(
            bundleIdentifier: "com.example.Debounce",
            resetRunner: { arguments in
                capturedArguments = arguments
                return 0
            }
        )

        try helper.resetAccessibilityPermission()

        XCTAssertEqual(capturedArguments, ["reset", "Accessibility", "com.example.Debounce"])
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run `-only-testing:DebounceTests/PermissionHelperTests`.

Expected: compile failure because the initializer and reset API are missing.

- [ ] **Step 3: Implement reset and alert actions**

Add:

```swift
enum PermissionAlertAction {
    case openSettings
    case repairPermission
    case cancel
}
```

Inject `bundleIdentifier` and a reset runner. The production runner must execute `/usr/bin/tccutil` directly with the argument array, wait for completion, and throw a localized error for a nonzero exit status. `showPermissionAlert()` returns one of the three actions and explains that Repair is for an entry that already appears enabled.

`openAccessibilityPreferences()` remains scoped to `Privacy_Accessibility`. The Open Settings and Repair branches request the native prompt by checking with `prompt: true` before navigating.

- [ ] **Step 4: Verify GREEN and commit**

Run the full suite, then:

```bash
git add Debounce/PermissionHelper.swift DebounceTests/PermissionHelperTests.swift
git commit -m "fix: add stale accessibility permission recovery"
```

### Task 6: Centralize Blocking State and Retry Pending Permission

**Files:**
- Create: `DebounceTests/BlockingControllerTests.swift`
- Modify: `Debounce/DebounceApp.swift`
- Modify: `Debounce/SettingsView.swift`

- [ ] **Step 1: Write failing transition tests**

Write tests against this interface:

```swift
protocol EventIntercepting: AnyObject {
    var onTapDied: (() -> Void)? { get set }
    func start() -> EventInterceptorStartResult
    func stop()
}

enum BlockingTransition: Equatable {
    case enabled
    case disabled
    case permissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed
}

final class BlockingController {
    private let blocker: ChatterBlocker
    private let interceptor: EventIntercepting
    private let persist: (ChatterBlocker) -> Void
    private(set) var pendingPermissionEnable = false

    init(
        blocker: ChatterBlocker,
        interceptor: EventIntercepting,
        persist: @escaping (ChatterBlocker) -> Void
    )

    func setEnabled(_ enabled: Bool) -> BlockingTransition
    func retryPendingPermission() -> BlockingTransition
}
```

Use a stub interceptor with a mutable sequence of `EventInterceptorStartResult` values and a persistence closure that appends `blocker.isEnabled` to an array. Test these transitions:

```swift
func testPermissionFailureCreatesPendingEnableWithoutClaimingEnabled()
func testRetryAfterPermissionGrantStartsAndPersistsEnabledState()
func testTapFailureDisablesAndPersistsDisabledState()
func testExplicitDisableClearsPendingPermissionAndStopsInterceptor()
```

Each test must assert `blocker.isEnabled`, `pendingPermissionEnable`, driver calls, and the last persisted value.

- [ ] **Step 2: Run the tests and verify RED**

Run `-only-testing:DebounceTests/BlockingControllerTests`.

Expected: compile failure because `BlockingController` and its protocols do not exist.

- [ ] **Step 3: Implement the transition controller**

`setEnabled(true)` maps the interceptor result as follows:

```text
started                          -> enabled=true, pending=false, persist true
accessibilityPermissionRequired -> enabled=false, pending=true, persist false
eventTapCreationFailed          -> enabled=false, pending=false, persist false, return distinct error
runLoopSourceCreationFailed     -> enabled=false, pending=false, persist false, return distinct error
```

`setEnabled(false)` stops the interceptor, clears timing state and pending permission, sets enabled false, and persists false. `retryPendingPermission()` only calls the true transition while pending.

- [ ] **Step 4: Integrate with the menu and settings**

Replace direct `chatterBlocker.isEnabled.toggle()` and the SwiftUI `.onChange(of: blocker.isEnabled)` loop with one callback that requests the desired state. Use a custom Toggle binding:

```swift
Toggle("Enable Chatter Blocking", isOn: Binding(
    get: { blocker.isEnabled },
    set: { onToggleBlocking($0) }
))
```

After each transition, update the icon and menu once. On `.accessibilityPermissionRequired`, show the permission action alert. Keep pending true only for Open Settings or successful Repair; clear it for Cancel or reset failure.

Observe `NSApplication.didBecomeActiveNotification` and call `retryPendingPermission()`; a successful retry starts blocking without another manual toggle. Present tap/source creation failures with accurate, separate alerts.

- [ ] **Step 5: Verify GREEN and commit**

Run the full suite, then:

```bash
git add Debounce/DebounceApp.swift Debounce/SettingsView.swift DebounceTests/BlockingControllerTests.swift
git commit -m "fix: keep blocking and permission state consistent"
```

### Task 7: Separate Build Identities and Prepare Version 1.3

**Files:**
- Modify: `Debounce.xcodeproj/project.pbxproj`
- Modify: `Debounce/Info.plist`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [ ] **Step 1: Add configuration-specific identity settings**

Set Debug target values:

```text
APP_DISPLAY_NAME = "Debounce Debug";
PRODUCT_BUNDLE_IDENTIFIER = com.leisengang.Debounce.debug;
```

Set Release target values:

```text
APP_DISPLAY_NAME = Debounce;
PRODUCT_BUNDLE_IDENTIFIER = com.leisengang.Debounce;
MARKETING_VERSION = 1.3;
CURRENT_PROJECT_VERSION = 3;
```

Set both Debug and Release to `MARKETING_VERSION = 1.3` and `CURRENT_PROJECT_VERSION = 3` so test-host metadata is consistent. Add this Info.plist entry:

```xml
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```

- [ ] **Step 2: Verify the resolved settings**

Run:

```bash
xcodebuild -project Debounce.xcodeproj -scheme Debounce -configuration Debug -showBuildSettings | \
  rg 'APP_DISPLAY_NAME|PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION|CURRENT_PROJECT_VERSION'
xcodebuild -project Debounce.xcodeproj -scheme Debounce -configuration Release -showBuildSettings | \
  rg 'APP_DISPLAY_NAME|PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION|CURRENT_PROJECT_VERSION'
```

Expected: Debug resolves to `Debounce Debug` / `.debug`; Release resolves to `Debounce` / `com.leisengang.Debounce`; both report 1.3 (3).

- [ ] **Step 3: Document recovery and release changes**

Add a 1.3 changelog section covering TCC identity separation, stale-entry repair, typed event-tap failures, memory ownership, zero persistence, tests, and deterministic packaging. Update README permission troubleshooting to use the Repair action and explain why Xcode and release permissions are separate.

- [ ] **Step 4: Run tests and builds**

Run:

```bash
xcodebuild test -project Debounce.xcodeproj -scheme Debounce -destination 'platform=macOS' -derivedDataPath /tmp/DebounceTestsDerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project Debounce.xcodeproj -scheme Debounce -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/DebounceDebugDerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild clean build -project Debounce.xcodeproj -scheme Debounce -configuration Release -destination 'generic/platform=macOS' -derivedDataPath /tmp/DebounceReleaseDerivedData ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
xcodebuild analyze -project Debounce.xcodeproj -scheme Debounce -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/DebounceAnalyzeDerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: every command exits 0 with no test failures.

- [ ] **Step 5: Commit release metadata**

```bash
git add Debounce.xcodeproj/project.pbxproj Debounce/Info.plist README.md CHANGELOG.md
git commit -m "release: prepare Debounce 1.3"
```

### Task 8: Build and Verify the DMG Deterministically

**Files:**
- Modify: `scripts/create-dmg.sh`
- Output: `build/Debounce-1.3.dmg`

- [ ] **Step 1: Replace DerivedData discovery with a clean build**

Use these configurable defaults:

```bash
IDENTITY="${IDENTITY:-Developer ID Application: Timo Leisengang (ZH6399Z6NR)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-debounce}"
RELEASE_ROOT="$BUILD_DIR/release-$VERSION"
DERIVED_DATA="$RELEASE_ROOT/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Debounce.app"
```

Remove only `"$RELEASE_ROOT"`, then run a fresh generic macOS Release build with `ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO`, and `CODE_SIGNING_ALLOWED=NO`.

- [ ] **Step 2: Validate metadata and sign the application**

Before packaging, compare the built `CFBundleShortVersionString` to the requested version and require `CFBundleIdentifier` to equal `com.leisengang.Debounce`. Require `lipo -archs` to include both `arm64` and `x86_64`.

Sign with:

```bash
codesign --force --timestamp --options runtime \
  --sign "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=4 "$APP_PATH"
```

- [ ] **Step 3: Create, sign, notarize, and staple the DMG**

Stage the signed app and Applications symlink in a temporary directory. Create `build/Debounce-1.3.dmg` as UDZO, sign it with a secure timestamp, submit it with `notarytool --wait`, then run:

```bash
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
hdiutil verify "$DMG_PATH"
codesign --verify --verbose=4 "$DMG_PATH"
spctl -a -vv --type open --context context:primary-signature "$DMG_PATH"
```

- [ ] **Step 4: Mount and verify the contained app**

Attach the image read-only at a temporary mount point, verify the contained app's version, identifier, architectures, strict code signature, and Gatekeeper execution assessment, then detach it in the cleanup trap.

- [ ] **Step 5: Run the release script**

Run:

```bash
./scripts/create-dmg.sh 1.3
```

Expected: notarization reports `Accepted`; stapler validation succeeds; the final line reports the absolute `build/Debounce-1.3.dmg` path.

- [ ] **Step 6: Commit the packaging rewrite**

```bash
git add scripts/create-dmg.sh
git commit -m "build: make DMG release deterministic"
```

### Task 9: Final Verification and Audit Handoff

**Files:**
- Verify all modified files and `build/Debounce-1.3.dmg`

- [ ] **Step 1: Run fresh end-to-end verification**

Run the full test, Debug build, universal Release build, analyzer, script syntax check, git whitespace check, app signature checks, DMG integrity, stapler validation, and Gatekeeper assessments again. Do not reuse earlier output.

- [ ] **Step 2: Check repository scope**

Run:

```bash
git status --short
git diff --check HEAD~8..HEAD
git log --oneline --decorate -12
```

Expected: only the user's pre-existing `docs/plans/` remains untracked; generated `build/` output stays ignored.

- [ ] **Step 3: Report the permission repair needed on this Mac**

Explain that the current stale 1.2 Accessibility record still targets the Apple Development requirement. Do not reset it without an explicit in-app Repair selection or direct user approval. The 1.3 app and DMG prevent future Debug/Release collisions but the existing record must be repaired once.

- [ ] **Step 4: Use the finishing-development-branch workflow**

After all evidence is fresh and green, invoke `superpowers:finishing-a-development-branch` and present the permitted integration options without pushing or opening a PR unless requested.
