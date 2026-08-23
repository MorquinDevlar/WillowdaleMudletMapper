---
description: Cut a release by running tools/release.sh - the only supported way to release.
argument-hint: "[X.Y.Z]"
allowed-tools: Bash(tools/release.sh:*), Bash(git status:*), Bash(git log:*), Read, AskUserQuestion
---

Cut a release. This command is a thin wrapper around `tools/release.sh` and
does nothing the script does not do.

Requested version: $ARGUMENTS

## The script owns the release

`tools/release.sh X.Y.Z` bumps `mfile`, promotes `## Unreleased` in
`CHANGELOG.md`, generates the update feed, builds the package, commits, tags,
pushes, and publishes the GitHub release with both assets. Publishing that
release IS the deploy: the game server subscribes to this repo's release
events and installs the assets, so every player is offered the update.

Therefore:

- NEVER bump `mfile`, edit `releases/releases.json`, promote the changelog,
  build, tag, push, or create a release by hand. Run the script.
- NEVER work around a check the script refuses on. A refusal - dirty tree, not
  on main, behind origin, empty `## Unreleased`, existing tag - means the
  release is not ready. Fix the cause, or report it and stop.
- The script restores `mfile` and `CHANGELOG.md` itself if it fails after the
  bump. Do not try to clean up after it.

## Steps

1. If `$ARGUMENTS` names a version, use it. Otherwise read the current version
   from `mfile`, show the `## Unreleased` entries from `CHANGELOG.md` so the
   choice is informed, and use AskUserQuestion to pick patch (X.Y.Z+1), minor
   (X.Y+1.0), or major (X+1.0.0). Say in the question that this deploys to the
   game server.
2. Run exactly:

   ```bash
   tools/release.sh X.Y.Z
   ```

3. Relay the release URL it prints, and its closing note: give the server's
   webhook a moment, then confirm the feed leads with the new version before
   announcing it. If it fails, report the failure and what it refused on.

Uncommitted work is not part of a release - the script requires a clean tree.
Use `/commit` first.
