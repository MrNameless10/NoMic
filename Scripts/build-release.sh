#!/bin/zsh
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$(mktemp -d /tmp/PrivateMicDerivedData.XXXXXX)"
dmg_staging="$(mktemp -d /tmp/PrivateMicDMG.XXXXXX)"

cleanup() {
    rm -rf "$derived_data" "$dmg_staging"
}
trap cleanup EXIT

cd "$repository_root"

version="$(
    xcodebuild \
        -project PrivateMic.xcodeproj \
        -scheme PrivateMic \
        -configuration Release \
        -derivedDataPath "$derived_data" \
        -showBuildSettings 2>/dev/null \
        | awk '/ MARKETING_VERSION = / { print $3; exit }'
)"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Invalid MARKETING_VERSION: ${version:-missing}. Expected MAJOR.MINOR.PATCH."
    exit 1
fi

xcodebuild \
    -quiet \
    -project PrivateMic.xcodeproj \
    -scheme PrivateMic \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$derived_data" \
    build \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM=

app_path="$derived_data/Build/Products/Release/PrivateMic.app"

# Xcode's local identity can add a development entitlement. Re-sign with the
# project's intentionally empty entitlements and retain the hardened runtime.
codesign \
    --force \
    --sign - \
    --options runtime \
    --entitlements PrivateMic/PrivateMic.entitlements \
    --timestamp=none \
    "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"

ditto --noextattr --noqtn "$app_path" "$dmg_staging/PrivateMic.app"
ln -s /Applications "$dmg_staging/Applications"

mkdir -p Dist
dmg_path="Dist/PrivateMic-${version}.dmg"
hdiutil create \
    -volname PrivateMic \
    -srcfolder "$dmg_staging" \
    -ov \
    -format UDZO \
    "$dmg_path"

hdiutil verify "$dmg_path"
shasum -a 256 "$dmg_path"
print "$dmg_path"
