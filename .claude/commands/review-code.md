---
description: Perform a comprehensive code review of current changes.
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(grep:*), Bash(rg:*), Bash(git merge-base:*), Bash(git show:*), Read, Glob, Grep
---

IMPORTANT: Use ultrathink when doing the review.

## Usage

```
/review-code                    # Review all changes in current branch vs base branch
/review-code HEAD               # Review the latest commit only
/review-code abc123             # Review specific commit by hash
/review-code HEAD~3             # Review the commit 3 commits ago
/review-code HEAD~3..HEAD       # Review last 3 commits
/review-code --full-context     # Review changes with analysis of surrounding code
/review-code --entire-codebase  # Full codebase review (not just changes)
```

## Review Process

I'll analyze your code changes focusing on these critical areas:

### 1. Lua/Mudlet Pattern Adherence
- **String literals**: Use double quotes for strings, escape internal quotes properly
- **Naming conventions**:
  - Global namespace: `mapper.*` for all mapper functions and variables
  - Local variables: camelCase or snake_case consistently
  - Functions: `mapper.functionName` for public, local for internal helpers
  - Constants: UPPER_SNAKE_CASE for true constants
- **Nil checking**: Always check for nil before accessing GMCP data or room properties
- **Event handlers**: Must be registered in `event_handlers.lua` using `registerNamedEventHandler`
- **GMCP data access**: Handle missing/malformed GMCP gracefully
- **Table initialization**: Initialize tables with `{}` before use

### 2. Code Location and Organization
- **Core** (`src/scripts/core/`): Settings, initialization, event handlers, utility functions
- **Navigation** (`src/scripts/navigation/`): Room events, speedwalking, pathfinding, door handling
- **Mapping** (`src/scripts/mapping/`): Room creation, GMCP room processing, area management
- **Game Specific** (`src/scripts/game_specific/`): Willowdale-specific handlers and logic
- **Updates** (`src/scripts/updates/`): Auto-update system, version checking, downloads
- **Aliases** (`src/aliases/`): User command shortcuts (mgo, mconfig, etc.)
- **Triggers** (`src/triggers/`): Pattern-based triggers for game output
- **scripts.json files**: Must correctly reference all Lua files in the folder

### 3. Event-Driven Architecture
- All map updates should be triggered by GMCP events, not polling
- Event handlers defined in `event_handlers.lua` using `registerNamedEventHandler`
- Key GMCP events: `gmcp.Room.Info`, `gmcp.Room.Info.Exits`, `gmcp.Room.Wrongdir`
- System events: `sysLoadEvent`, `sysExitEvent`, `sysDownloadDone`, `sysDownloadError`
- Custom events: `mapper logged in`, `mapper areas changed`, `mapper updated map`

### 4. Code Redundancy and Reuse
- Search for existing functionality in utility modules
- Check `core/` files before creating new helpers
- Flag duplicate code, dead code, and unused variables
- Suggest specific existing functions that could be extended

### 5. Mudlet Mapper API Usage
- **Room functions**: `addRoom()`, `setRoomCoordinates()`, `setRoomName()`, `setRoomArea()`
- **Exit functions**: `setExit()`, `getRoomExits()`, `setExitStub()`, `connectExitStub()`
- **Door functions**: `setDoor()`, `getDoors()`, `openDoor()`, `closeDoor()`
- **Pathfinding**: `getPath()`, `speedWalkPath`, `speedWalkDir`, custom speedwalk system
- **View functions**: `centerview()`, `highlightRoom()`, `unHighlightRoom()`
- **Area functions**: `addAreaName()`, `setAreaName()`, `getRoomArea()`
- **Room data**: `setRoomUserData()`, `getRoomUserData()`, `clearRoomUserData()`
- Reference: https://wiki.mudlet.org/w/Manual:Mapper_Functions

### 6. Data Persistence
- Settings saved via `mapper.settings` proxy table with auto-persistence
- Room data stored in Mudlet's map database via `setRoomUserData()`
- Download files stored in `getMudletHomeDir()/map downloads/`
- Handle missing files gracefully on first load

### 7. Code Efficiency and Clarity
- Avoid global variable pollution - use the `mapper` namespace
- Prefer local variables for performance in loops
- Question unnecessary abstractions
- Prefer simple, self-documenting solutions
- Avoid numbered steps in comments like "STEP 1:"

### 8. Comment Quality
- Keep comments simple and direct
- Comments should explain WHY, not WHAT
- Remove redundant comments that just restate code
- Flag TODO/FIXME comments that should be addressed

## Execution Steps

1. First, I'll determine what to review:
   - If no argument provided: Detect actual branch commits by finding the merge base with main
   - Use `git merge-base main HEAD` to find where branch diverged
   - Review ONLY commits unique to current branch (not shared with main)
   - If commit specified: Review that specific commit or range
2. Verify JSON structure:
   - Check all `scripts.json`, `triggers.json`, `aliases.json`, `keys.json` files
   - Ensure they correctly reference all Lua files
   - Validate JSON syntax
3. Analyze existing codebase patterns for consistency
4. Review the changes against Mudlet/Lua patterns
5. Search for existing code that could be reused
6. Check for common Lua issues (nil access, global leaks)
7. Provide a comprehensive report with:
   - Quick summary of changes
   - Critical issues that must be fixed
   - Redundancy report with reusable code suggestions
   - Efficiency improvements
   - Actionable comment review

### Branch Detection Logic
When reviewing without arguments, I will:
1. Find the merge base: `git merge-base main HEAD`
2. List branch-only commits: `git log --oneline <merge-base>..HEAD`
3. Review diff of branch changes: `git diff <merge-base>..HEAD`
4. This ensures I ONLY review changes introduced by your branch, not changes from main
5. The diff is still against current main, so it validates your changes work with latest code

## Architecture-Specific Checks

### Mapper Structure
- **Core**: Initialization, settings, event registration, echo/output functions
- **Navigation**: Speedwalking, door handling, room centering, path highlights
- **Mapping**: Room creation from GMCP, exit linking, coordinate calculation
- **Updates**: Version checking, package downloads, crowdmap system

### GMCP Data Flow
1. **GMCP Data Arrival** → Event triggered (e.g., `gmcp.Room.Info`)
2. **Event Handler** → Calls mapper function (e.g., `mapper.room_events()`)
3. **Room Processing** → Creates/updates room in map database
4. **Map Update** → Mudlet renders changes in mapper window

### Key GMCP Structures
- `gmcp.Room.Info` - Room vnum, name, area, coordinates
- `gmcp.Room.Info.Basic` - Basic room properties
- `gmcp.Room.Info.Exits` - Available exits with door states
- `gmcp.Room.Wrongdir` - Movement failure notification

### Speedwalk System
- `mapper.speedWalk` - Queue of pending movements
- `mapper.speedWalkPath` - Room IDs in path
- `mapper.speedWalkDir` - Directions for each step
- `mapper.speedWalkCounter` - Current position in walk
- Custom door handling during speedwalk

### External Dependencies
- **yajl** - JSON parsing (`yajl.to_value()`, `yajl.to_string()`)
- **lfs** - LuaFileSystem for directory operations
- **rex** - PCRE regex library (if used)

## Critical Review Focus

### Default Behavior (Branch/Commit Review)
When reviewing specific changes, I will:
1. **ONLY flag issues introduced by the changes** - Not pre-existing problems
2. **Check if new code follows existing patterns** - Even if those patterns have issues
3. **Verify issues are actually new** - Compare with base branch before reporting
4. **Focus on the diff** - Only review code that was actually modified
5. **Note when following bad patterns** - "Follows existing pattern (which has issues)"

### Full Context Review (--full-context)
When requested, I will also:
- Analyze surrounding code that interacts with changes
- Identify pre-existing issues that might affect new code
- Suggest broader refactoring opportunities

### Entire Codebase Review (--entire-codebase)
Comprehensive analysis including:
- All existing code quality issues
- Systemic pattern problems
- Technical debt identification
- JSON configuration completeness

## Review Philosophy

**By default, I assume you want a focused PR review** that helps you merge clean changes without being blocked by pre-existing issues. The review will:
- Distinguish between "new problems" and "following existing bad patterns"
- Not penalize you for consistency with existing code
- Focus on regressions and new bugs introduced
- Suggest fixes only for issues your changes created

Example output for pre-existing pattern:
```
Note: The new code follows the existing pattern of not nil-checking GMCP data.
This is a pre-existing issue in the codebase, not introduced by this PR.
```

## Review Verification Standards

### CRITICAL: Preventing False Positives
**NEVER report issues without complete verification. False positives destroy trust.**

### Mandatory Verification Process
Before reporting ANY issue, you MUST:

1. **Verify the Issue Actually Exists**
   - NEVER assume based on patterns that "look wrong"
   - ALWAYS trace the full code path to confirm
   - Check for nil guards, default values, or error handling elsewhere
   - Verify issues are INTRODUCED BY THIS BRANCH, not pre-existing

2. **Test Your Claims**
   - For "nil access": Check if guards exist in the call chain
   - For "missing event handler": Verify it's not registered in event_handlers.lua
   - For "unused variable": Search entire codebase first
   - For "JSON mismatch": Verify the actual file references

3. **Common False Positive Patterns to AVOID**
   - "Nil access risk" - CHECK for guards in calling code first
   - "Missing from scripts.json" - CHECK if file is included via parent folder
   - "Unused function" - CHECK for dynamic calls via string names
   - "Event not handled" - CHECK event_handlers.lua registrations

4. **Evidence Requirements**
   - Show EXACT code proving the issue (not just line numbers)
   - Trace COMPLETE execution path showing how issue occurs
   - Provide COUNTER-EVIDENCE search (did you look for guards?)
   - If guards exist elsewhere, issue is FALSE POSITIVE

5. **Three-Strike Verification**
   Before reporting an issue, ask yourself:
   - Strike 1: Did I verify this is actually broken, not just different?
   - Strike 2: Did I check for defensive code/guards elsewhere?
   - Strike 3: Is this actually NEW in this branch or pre-existing?

   If ANY strike fails, DO NOT REPORT THE ISSUE.

6. **Language for Uncertainty**
   If you cannot fully verify:
   - "Unable to verify if..." (not "There is a problem with...")
   - "Could not find guard for..." (not "Nil access bug in...")
   - "Recommend manual verification of..." (not "Found issue in...")

### Review Trust Guidelines
Users should:
- **Request evidence**: "Show me where that issue exists"
- **Ask for examples**: "Give me 3 specific instances of that problem"
- **Challenge vague claims**: Vague warnings often indicate unverified assumptions
- **Demand specifics**: If a review claims issues without line numbers, ask for them
- **Question theoretical issues**: "Will this actually cause problems in practice?"

Ready to analyze your WillowdaleMudletMapper code changes with verified, evidence-based feedback!
