#!/usr/bin/env bash
# Stamp the build: set application/config/version in game/project.godot to "<X.Y.Z>+<sha>" (BuildInfo reads it; the
# title, the game menu and saves show / record it). Changes that one line and nothing else.
# Usage: bash tools/release/stamp_version.sh <tag> <sha>
#   <tag>  the release tag or number: v0.56.0-some-label, v0.56.0 or 0.56.0 (the label is not part of the stamp)
#   <sha>  the short sha of the commit being released (the one the tag would otherwise go on), e.g. 4959094
# Release routine: stamp with HEAD's short sha, commit "chore(release): stamp v0.56.0", tag that commit, export.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/../../game/project.godot"

[ $# -eq 2 ] || { echo "usage: stamp_version.sh <tag> <sha>" >&2; exit 2; }
num="$(echo "$1" | sed -E 's/^v//; s/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
sha="$(echo "$2" | tr 'A-F' 'a-f')"
echo "$num" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "stamp: '$1' does not start with a version X.Y.Z" >&2; exit 2; }
echo "$sha" | grep -Eq '^[0-9a-f]{7,40}$' || { echo "stamp: '$2' is not a commit sha" >&2; exit 2; }
sha="${sha:0:7}"
stamp="$num+$sha"

if grep -q '^config/version=' "$PROJECT"; then
  sed -i "s/^config\/version=.*/config\/version=\"$stamp\"/" "$PROJECT"
else
  # first stamp: the line goes straight under config/name in [application]
  sed -i "/^config\/name=/a config\/version=\"$stamp\"" "$PROJECT"
fi
grep -q "^config/version=\"$stamp\"\$" "$PROJECT" || { echo "stamp: failed to write $PROJECT" >&2; exit 1; }
echo "stamp: application/config/version = \"$stamp\""
