---
description: Review the current changes, commit them, then offer to cut a release with tools/release.sh.
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(grep:*), Bash(rg:*), Bash(git merge-base:*), Bash(git show:*), Bash(git add:*), Bash(git commit:*), Bash(git status:*), Bash(luac5.1:*), Bash(muddle:*), Bash(tools/release.sh:*), Read, Edit, AskUserQuestion
---

IMPORTANT: Use ultrathink when doing the review.

This command commits code. It does NOT release. Releasing is `tools/release.sh
X.Y.Z` and nothing else, and this command's only involvement is to offer to run
it once the commit is in.

## What this command must never do

`tools/release.sh` owns all of the following. Doing any of it here produces a
half-made release that the script will then refuse to finish, or - worse - a
version and a feed that disagree with what was actually published.

- NEVER edit the `"version"` field in `mfile`. Only the release script bumps it.
- NEVER create or edit `releases/releases.json`. It is generated from
  `CHANGELOG.md` by `tools/changelog_to_releases.lua`, written to a temp file,
  and uploaded as a release asset. It is gitignored and hand-editing it is
  forbidden.
- NEVER promote `## Unreleased` in `CHANGELOG.md` to a version heading. The
  script does that as part of cutting the release.
- NEVER commit `build/` or `releases/`. Both are gitignored; the package and
  the feed go up as release assets.
- NEVER tag, push a tag, or create a GitHub release by hand.

## Step 1: Review

Read the working tree with `git status` and `git diff`, and compare against the
previous commit. Review the changes for correctness and for anything that
contradicts `CLAUDE.md`. Raise real problems before committing them.

## Step 2: Changelog

`CHANGELOG.md` is the source of truth for release notes, so a change a player
would notice gets its entry in the SAME commit as the change itself. A change
committed without its note is a change no player is ever told about.

1. Decide whether the change is player-visible: commands, settings, behaviour
   they will see, or something that was going wrong for them. Development
   tooling, build changes, and internal refactors are NOT listed - if the
   change is one of those, skip to step 3 and say so.
2. If it is player-visible, add one line per change under the existing
   `## Unreleased` heading with the Edit tool. Do not create a version heading,
   and do not touch any heading below `## Unreleased`.
3. Entries are one line, past tense, player-facing, and start with `Added`,
   `Fixed`, `Changed`, or `Removed`. Describe what the player sees, not how it
   was implemented. Match the voice of the entries already in the file.
4. Stage `CHANGELOG.md` together with the code.

Example:

```markdown
## Unreleased

- Added a `mapper showpath` command that highlights the route to your target
- Fixed the map not following you after a teleport
```

## Step 3: Verify

There is no test suite in this repo, so a parse of every Lua file and the
build are the checks. From the repo root:

```bash
luac5.1 -p src/scripts/*.lua src/scripts/*/*.lua tools/*.lua
muddle
```

Both must succeed before committing. The parse is the only check of Lua
syntax: muddler packages the Lua without parsing it and reports success for a
file with a syntax error. The build proves the muddler `__VERSION__`
substitution still lands. The build cannot validate Qt rendering, live GMCP
framing, or the mapper against a real map - say so if the change needs testing
against the running game. Do not stage anything the build produced.

## Step 4: Commit

NEVER add any information about the commit being written or handled by Claude
Code, and NEVER add a Claude signature or Co-Authored-By trailer.

1. **Title**: Brief, factual description of changes (50-72 characters maximum,
   no adjectives like "better", "improved", etc.)
2. **Body**: Bullet points listing specific changes:
   - Use past tense ("Fixed", "Added", "Removed", not "Fix", "Add", "Remove")
   - Be specific and technical
   - No subjective assessments (avoid "simpler", "better", "faster", "cleaner")
   - No hyperbole
   - Just state what changed, not why it is good
   - Group related changes together in this order: Added, Fixed, Changed, Removed
   - Never write up fixes for things broken earlier in the same commit
3. **Breaking changes**: List any breaking changes separately at the end

Example:

  Modified GMCP module architecture and exit information

  Added:
  - PlayerDespawn cleanup handlers to all combat modules
  - User validation with validateUserForGMCP helper function
  - ExitLockChanged event for exit state notifications
  - Exit details map with type, state, name, hasKey, and hasPicked fields

  Fixed:
  - Memory leaks from uncleaned tracking maps
  - Redundant "exits" wrapper in Room.Info.Exits output

  Changed:
  - Cooldown timer interval from 250ms to 200ms
  - Exit state values to "locked" and "open"

  Removed:
  - Unused imports from gmcp.go and combat modules

  Breaking Changes:
  - Room.Info.Exits now exists as a primary node (previously Room.Info.Exits.exits)

Keep it neutral, factual, and technical.

## Step 5: Offer a release

Pushing main is not deploying; publishing the GitHub release is. So after the
commit lands, ask - do not assume.

1. Read the current version from `mfile` and work out the three candidates:
   patch (bug fixes), minor (new features), major (breaking changes).
2. Use AskUserQuestion to ask whether to cut a release now, offering:
   - **No release** (recommended default): stop here, the commit stands on its own.
   - **Patch X.Y.Z+1**, **Minor X.Y+1.0**, **Major X+1.0.0**: cut that release.
   State plainly in the question that cutting a release deploys to the game
   server: the server subscribes to this repo's release events and installs the
   published assets, so every player is offered the update.
3. If the user declines, report the commit and stop. Do not push.
4. If the user picks a version, run exactly:

   ```bash
   tools/release.sh X.Y.Z
   ```

   Nothing else. The script checks the prerequisites, bumps `mfile`, promotes
   the changelog, generates the feed, builds the package, commits, tags,
   pushes, and publishes the release with both assets. Do not do any of that
   yourself, and do not work around a check the script refuses on - a refusal
   means the release is not ready. If it fails, report the failure; the script
   restores `mfile` and `CHANGELOG.md` itself.
5. When it succeeds, relay the release URL it prints and its closing note: give
   the server's webhook a moment, then confirm the feed leads with the new
   version before announcing it.
