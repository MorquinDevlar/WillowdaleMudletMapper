#!/usr/bin/env bash
#
# Cut a Willowdale Mudlet Mapper release. Usage: tools/release.sh X.Y.Z
#
# PUBLISHING THE GITHUB RELEASE IS DEPLOYING - pushing main is not. The game
# server subscribes to this repo's *release* events, and when one is published
# it downloads that release's two assets into its own static/resources/mapper/,
# which is the only place an installed client ever looks:
#   WillowdaleMudletMapper.mpackage -> .../static/resources/mapper/WillowdaleMudletMapper.mpackage
#   releases.json                   -> .../static/resources/mapper/releases.json
#
# That is why nothing generated is committed: build/ and releases/ are ignored
# and the feed is built into a temp file here. A release is a deliberate act
# with a deliberate payload, so an ordinary commit - or a mistaken one - can
# never reach a player. It also means the tag format (vX.Y.Z) and the two ASSET
# BASENAMES are a contract with the server's release handler, which looks
# assets up by name. Rename either and a published release deploys nothing.
#
# The feed is generated from CHANGELOG.md (tools/changelog_to_releases.lua), so
# the notes a player is shown and the notes in the repo cannot drift apart.
# Never hand-edit releases.json.
#
# Only mfile carries the version: muddler substitutes __VERSION__ into
# mapper.version at build time, so there is no second constant to keep in step.

set -euo pipefail

die() {
    printf 'release: %s\n' "$*" >&2
    exit 1
}

step() {
    printf '==> %s\n' "$*"
}

# Everything from the bump onwards is undone on failure, so a botched run
# leaves the tree exactly as clean as it was found.
restore_and_die() {
    git checkout -- mfile CHANGELOG.md
    die "$*"
}

[ $# -eq 1 ] || die "usage: tools/release.sh X.Y.Z"
version=$1
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z, got '$version'"
tag="v$version"

repo_root=$(git rev-parse --show-toplevel) || die "not inside a git repository"
cd "$repo_root"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
notes_file="$tmpdir/notes.md"
feed_file="$tmpdir/releases.json"

step "Checking prerequisites"
for tool in git gh lua5.1 muddle; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool not on PATH: $tool"
done
# An unauthenticated gh would only fail at the very end, after the tag is
# already pushed - a half-made release. Fail here instead.
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run 'gh auth login' first"

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = main ] || die "releases are cut from main, but HEAD is on '$branch'"
[ -z "$(git status --porcelain)" ] || die "working tree is not clean; commit or stash first"

step "Fetching origin"
git fetch origin
# Being ahead of origin is fine - the script pushes main itself. Being behind is
# the hazard: the push would be rejected after the release commit and tag exist.
git merge-base --is-ancestor origin/main main ||
    die "main is behind origin/main; pull first"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    die "tag $tag already exists locally"
fi
if [ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]; then
    die "tag $tag already exists on origin"
fi
if gh release view "$tag" >/dev/null 2>&1; then
    die "a GitHub release for $tag already exists"
fi

[ -f CHANGELOG.md ] || die "CHANGELOG.md is missing"
grep -q '^## Unreleased[[:space:]]*$' CHANGELOG.md || die "CHANGELOG.md has no '## Unreleased' heading"
if ! awk '/^## Unreleased[[:space:]]*$/ { inside = 1; next }
          inside && /^## / { exit }
          inside' CHANGELOG.md | grep -q '[^[:space:]]'; then
    die "the '## Unreleased' section is empty; write the release notes under '## Unreleased' first"
fi

step "Bumping version to $version"
sed "s/\"version\": \"[^\"]*\"/\"version\": \"$version\"/" mfile >"$tmpdir/mfile"
mv "$tmpdir/mfile" mfile
grep -q "\"version\": \"$version\"" mfile || restore_and_die "failed to bump the version in mfile"

step "Promoting the changelog"
today=$(date +%F)
heading="## $version - $today"
awk -v heading="$heading" '
    !promoted && /^## Unreleased[[:space:]]*$/ {
        print "## Unreleased"
        print ""
        print heading
        promoted = 1
        next
    }
    { print }
' CHANGELOG.md >"$tmpdir/CHANGELOG.md"
mv "$tmpdir/CHANGELOG.md" CHANGELOG.md
# The section body, minus leading and trailing blank lines, is the release note
# on GitHub. The same text reaches players through the generated feed below.
awk -v heading="$heading" '
    $0 == heading { inside = 1; next }
    inside && /^## / { exit }
    inside
' CHANGELOG.md | awk '
    /[^[:space:]]/ { for (i = 0; i < blanks; i++) print ""; blanks = 0; started = 1; print; next }
    started { blanks++ }
' >"$notes_file"
[ -s "$notes_file" ] || restore_and_die "could not extract release notes for $version"

# The feed the players actually read, generated from the changelog just
# promoted so the two can never disagree. It is UPLOADED, never committed.
step "Generating the release feed"
lua5.1 tools/changelog_to_releases.lua >"$feed_file" ||
    restore_and_die "could not generate releases.json from CHANGELOG.md"
# The newest entry is what every client compares against its own version. If it
# is not the version being cut, clients are offered a release that the uploaded
# package is not.
feed_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$feed_file" | head -1)
[ "$feed_version" = "$version" ] ||
    restore_and_die "the feed leads with $feed_version, not $version"

step "Building the package"
muddle || restore_and_die "muddle build failed"
# Muddler names the output after the mfile "package" value, so this check also
# catches an mfile whose package name drifted away from the asset the server
# expects to find on the release.
[ -s build/WillowdaleMudletMapper.mpackage ] ||
    restore_and_die "muddle produced no build/WillowdaleMudletMapper.mpackage"

step "Committing"
git add mfile CHANGELOG.md
git commit -m "Released version $version

Bumped mfile to $version and promoted the changelog's Unreleased section.
The package and the update feed are published as release assets, not
committed."

step "Tagging $tag"
git tag -a "$tag" -m "Willowdale Mudlet Mapper $version"

# The push is NOT the deploy - publishing the release below is. Main goes up
# first so the tag it carries exists before the release references it.
step "Pushing to origin"
git push origin main
git push origin "$tag"

# THE DEPLOY. Both assets go up in one call, and their basenames are what the
# server's release handler looks for: WillowdaleMudletMapper.mpackage and
# releases.json. A release published with only one of them deploys a package no
# feed announces, or a feed pointing at a package that never arrived.
step "Publishing the GitHub release (this deploys to the game server)"
release_url=$(gh release create "$tag" \
    build/WillowdaleMudletMapper.mpackage "$feed_file" \
    --title "$tag" --notes-file "$notes_file")
printf '    %s\n' "$release_url"

printf '\nReleased Willowdale Mudlet Mapper %s\n' "$version"
printf '  tag:     %s\n' "$tag"
printf '  release: %s\n' "$release_url"
printf '  feed:    https://updates.willowdalemud.com/static/resources/mapper/releases.json\n'
printf '\nThe game server deploys from the published release above; give its webhook\n'
printf 'a moment, then confirm the feed leads with %s before announcing it.\n' "$version"
