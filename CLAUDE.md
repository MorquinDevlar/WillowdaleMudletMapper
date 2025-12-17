# MudletMapper Development Notes

## Important References

### Mudlet Mapper API Documentation
- **URL**: https://wiki.mudlet.org/w/Manual:Mapper_Functions
- **Purpose**: Complete reference for all Mudlet mapper functions
- **Note**: Always check this page when working with mapper functionality to ensure correct usage of:
  - Room manipulation functions (addRoom, setRoomCoordinates, etc.)
  - Exit handling (setExit, setDoor, getRoomExits, etc.)
  - Area management (setRoomArea, getRoomArea, etc.)
  - Pathfinding (getPath, speedwalk functions)
  - Special exits and room properties
  - Environment and terrain functions

## Project Structure

The mapper script is organized into several key modules:
- Core functionality in `/src/scripts/core/`
- Navigation features in `/src/scripts/navigation/`
- Mapping features in `/src/scripts/mapping/`
- Game-specific code in `/src/scripts/game_specific/`

## Recent Changes

### Simplified Option System
- Options are now defined in a simple table structure in `option_definitions.lua`
- Easy to add new options without complex function calls
- Supports all existing features (validation, onChange handlers, game-specific options)

### GMCP Structure Support
- Handles hierarchical GMCP room data (Info.Basic, Info.Exits, etc.)
- Automatic door creation and state tracking
- Coordinate system conversion for Y-axis inversion

### Package Installation Handler
- Automatically reloads mapper settings when package is reinstalled
- Listens to `sysInstallPackage` event

### Commit message best practices
- Always write in the past tense
- Always compare to the previous commit or branch
- Never write up fixes for things that you broke yourself inside the same commit
- If possible, add these sections to the commit message: Added, Fixed, Changed, Removed
