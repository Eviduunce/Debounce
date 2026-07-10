#!/bin/bash
set -euo pipefail

APP_NAME="Debounce"
EXPECTED_BUNDLE_ID="com.leisengang.Debounce"
IDENTITY="${IDENTITY:-Developer ID Application: Timo Leisengang (ZH6399Z6NR)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-debounce}"

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s <version>\n' "$0" >&2
    printf 'Example: %s 1.3\n' "$0" >&2
    exit 64
fi

VERSION="$1"
case "$VERSION" in
    ''|*[!0-9.]*|.*|*.|*..*)
        printf 'Error: version must contain dot-separated numeric components.\n' >&2
        exit 64
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
PROJECT="$PROJECT_DIR/Debounce.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_ROOT="$BUILD_DIR/release-$VERSION"
DERIVED_DATA="$RELEASE_ROOT/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
ENTITLEMENTS="$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
WORK_DMG_PATH="$RELEASE_ROOT/$DMG_NAME"

STAGING_DIR=""
MOUNT_POINT=""
MOUNT_REALPATH=""
MOUNT_DEVICE=""
MOUNT_ATTACHED=0
EXPECTED_BUILD_VERSION=""

cleanup() {
    local exit_code=$?
    local detach_target
    trap - EXIT INT TERM
    set +e

    if [ "$MOUNT_ATTACHED" -eq 1 ]; then
        detach_target="$MOUNT_DEVICE"
        if [ -z "$detach_target" ]; then
            detach_target="$MOUNT_REALPATH"
        fi
        if [ -z "$detach_target" ]; then
            detach_target="$MOUNT_POINT"
        fi
        hdiutil detach "$detach_target" -force >/dev/null 2>&1
    fi

    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf -- "$STAGING_DIR"
    fi
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        rmdir "$MOUNT_POINT" >/dev/null 2>&1
    fi

    exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

plist_value() {
    local plist_path="$1"
    local plist_key="$2"
    /usr/libexec/PlistBuddy -c "Print :$plist_key" "$plist_path"
}

require_architecture() {
    local architecture_list="$1"
    local required_architecture="$2"
    case " $architecture_list " in
        *" $required_architecture "*) ;;
        *) die "missing $required_architecture architecture in: $architecture_list" ;;
    esac
}

validate_app_metadata() {
    local app="$1"
    local info_plist="$app/Contents/Info.plist"
    local built_version
    local built_build_version
    local bundle_id
    local executable_name
    local executable
    local architectures

    [ -d "$app" ] || die "application bundle not found: $app"
    [ -f "$info_plist" ] || die "application Info.plist not found: $info_plist"

    built_version="$(plist_value "$info_plist" CFBundleShortVersionString)"
    if ! built_build_version="$(plist_value "$info_plist" CFBundleVersion)"; then
        die "application CFBundleVersion is missing: $info_plist"
    fi
    bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
    executable_name="$(plist_value "$info_plist" CFBundleExecutable)"
    executable="$app/Contents/MacOS/$executable_name"

    [ "$built_version" = "$VERSION" ] || \
        die "built version $built_version does not match requested version $VERSION"
    [ -n "$built_build_version" ] || die "application CFBundleVersion is empty: $info_plist"
    [ "$built_build_version" = "$EXPECTED_BUILD_VERSION" ] || \
        die "built CFBundleVersion $built_build_version does not match resolved Release build $EXPECTED_BUILD_VERSION"
    [ "$bundle_id" = "$EXPECTED_BUNDLE_ID" ] || \
        die "built bundle identifier $bundle_id does not match $EXPECTED_BUNDLE_ID"
    [ -f "$executable" ] || die "application executable not found: $executable"

    architectures="$(lipo -archs "$executable")"
    require_architecture "$architectures" arm64
    require_architecture "$architectures" x86_64

    printf 'Verified app metadata: version=%s build=%s bundle-id=%s architectures=%s\n' \
        "$built_version" "$built_build_version" "$bundle_id" "$architectures"
}

detach_mounted_image() {
    if [ "$MOUNT_ATTACHED" -ne 1 ]; then
        return
    fi

    if ! hdiutil detach "$MOUNT_DEVICE"; then
        hdiutil detach "$MOUNT_DEVICE" -force
    fi
    MOUNT_ATTACHED=0
    MOUNT_DEVICE=""
}

for required_command in \
    awk \
    codesign \
    ditto \
    grep \
    hdiutil \
    lipo \
    mktemp \
    plutil \
    readlink \
    security \
    shasum \
    spctl \
    stat \
    xcodebuild \
    xcrun
do
    require_command "$required_command"
done

[ -d "$PROJECT" ] || die "Xcode project not found: $PROJECT"
[ -f "$ENTITLEMENTS" ] || die "entitlements file not found: $ENTITLEMENTS"
[ -x /usr/libexec/PlistBuddy ] || die "PlistBuddy is unavailable"
plutil -lint "$ENTITLEMENTS" >/dev/null

if ! security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null; then
    die "Developer ID signing identity is unavailable: $IDENTITY"
fi

EXPECTED_BUILD_VERSION="$(
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$APP_NAME" \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -showBuildSettings | \
        awk '$1 == "CURRENT_PROJECT_VERSION" && !found { print $3; found = 1 }'
)"
[ -n "$EXPECTED_BUILD_VERSION" ] || die "could not resolve Release CURRENT_PROJECT_VERSION"
printf 'Resolved Release build version: %s\n' "$EXPECTED_BUILD_VERSION"

mkdir -p "$BUILD_DIR"
rm -rf -- "$RELEASE_ROOT"
mkdir -p "$RELEASE_ROOT"

printf 'Building clean universal Release app in %s\n' "$DERIVED_DATA"
xcodebuild clean build \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO

validate_app_metadata "$APP_PATH"

printf 'Signing app with %s\n' "$IDENTITY"
codesign --force --timestamp --options runtime \
    --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"
codesign --verify --deep --strict --verbose=4 "$APP_PATH"
codesign --display --verbose=4 "$APP_PATH"

STAGING_DIR="$(mktemp -d "$RELEASE_ROOT/staging.XXXXXX")"
printf 'Staging signed app in %s\n' "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
codesign --verify --deep --strict --verbose=4 "$STAGING_DIR/$APP_NAME.app"

printf 'Creating compressed disk image\n'
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$WORK_DMG_PATH"

printf 'Signing disk image with %s\n' "$IDENTITY"
codesign --force --timestamp --sign "$IDENTITY" "$WORK_DMG_PATH"
codesign --verify --verbose=4 "$WORK_DMG_PATH"
codesign --display --verbose=4 "$WORK_DMG_PATH"

printf 'Submitting disk image for notarization with profile %s\n' "$NOTARY_PROFILE"
NOTARY_RESULT=""
if ! NOTARY_RESULT="$(
    xcrun notarytool submit "$WORK_DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        --output-format json
)"; then
    die "notarytool submission failed"
fi
printf '%s\n' "$NOTARY_RESULT"

SUBMISSION_ID="$(
    printf '%s' "$NOTARY_RESULT" | plutil -extract id raw -o - -
)"
NOTARY_STATUS="$(
    printf '%s' "$NOTARY_RESULT" | plutil -extract status raw -o - -
)"
[ -n "$SUBMISSION_ID" ] || die "notarytool did not return a submission identifier"

if [ "$NOTARY_STATUS" != "Accepted" ]; then
    printf 'Notarization status: %s\n' "$NOTARY_STATUS" >&2
    printf 'Submission ID: %s\n' "$SUBMISSION_ID" >&2
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
    die "notarization was not accepted"
fi

printf 'Notarization accepted: submission-id=%s\n' "$SUBMISSION_ID"
xcrun stapler staple "$WORK_DMG_PATH"
xcrun stapler validate "$WORK_DMG_PATH"
hdiutil verify "$WORK_DMG_PATH"
codesign --verify --verbose=4 "$WORK_DMG_PATH"
spctl -a -vv --type open --context context:primary-signature "$WORK_DMG_PATH"

MOUNT_POINT="$(mktemp -d "${TMPDIR:-/tmp}/Debounce-mount.XXXXXX")"
MOUNT_REALPATH="$(cd "$MOUNT_POINT" && pwd -P)"
printf 'Mounting disk image read-only at %s\n' "$MOUNT_POINT"
ATTACH_OUTPUT="$(
    hdiutil attach \
        -readonly \
        -nobrowse \
        -mountpoint "$MOUNT_POINT" \
        "$WORK_DMG_PATH"
)"
MOUNT_ATTACHED=1
printf '%s\n' "$ATTACH_OUTPUT"
MOUNT_DEVICE="$(
    printf '%s\n' "$ATTACH_OUTPUT" | \
        awk -v mount_point="$MOUNT_REALPATH" 'index($0, mount_point) { print $1; exit }'
)"
[ -n "$MOUNT_DEVICE" ] || die "could not determine mounted disk device"

MOUNTED_APP="$MOUNT_POINT/$APP_NAME.app"
validate_app_metadata "$MOUNTED_APP"
[ -L "$MOUNT_POINT/Applications" ] || die "Applications symlink is missing from disk image"
[ "$(readlink "$MOUNT_POINT/Applications")" = "/Applications" ] || \
    die "Applications symlink does not point to /Applications"
codesign --verify --deep --strict --verbose=4 "$MOUNTED_APP"
codesign --display --verbose=4 "$MOUNTED_APP"
spctl -a -vv --type execute "$MOUNTED_APP"

detach_mounted_image
rmdir "$MOUNT_POINT"
MOUNT_POINT=""
MOUNT_REALPATH=""

mv -f "$WORK_DMG_PATH" "$DMG_PATH"

DMG_SIZE_BYTES="$(stat -f '%z' "$DMG_PATH")"
DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"

printf 'Notarization status: %s\n' "$NOTARY_STATUS"
printf 'Submission ID: %s\n' "$SUBMISSION_ID"
printf 'Artifact size: %s bytes\n' "$DMG_SIZE_BYTES"
printf 'Artifact SHA-256: %s\n' "$DMG_SHA256"
printf 'Created: %s\n' "$DMG_PATH"
