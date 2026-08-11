#!/bin/zsh
set -euo pipefail

if (( $# != 1 )); then
    print -u2 "Usage: $0 vMAJOR.MINOR.PATCH"
    exit 64
fi

tag="$1"
if [[ ! "$tag" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Release tags must use vMAJOR.MINOR.PATCH, for example v1.1.0."
    exit 1
fi

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$(mktemp -d /tmp/PrivateMicVersionData.XXXXXX)"
trap 'rm -rf "$derived_data"' EXIT
cd "$repository_root"

project_version="$(
    xcodebuild \
        -project PrivateMic.xcodeproj \
        -scheme PrivateMic \
        -configuration Release \
        -derivedDataPath "$derived_data" \
        -showBuildSettings 2>/dev/null \
        | awk '/ MARKETING_VERSION = / { print $3; exit }'
)"

tag_version="${tag#v}"
if [[ "$project_version" != "$tag_version" ]]; then
    print -u2 "Tag ${tag} does not match MARKETING_VERSION ${project_version:-missing}."
    exit 1
fi

print "Release tag ${tag} matches PrivateMic ${project_version}."
