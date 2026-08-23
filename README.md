# Willowdale Mudlet Mapper

A custom GMCP mapper for WillowdaleMUD, providing automatic room mapping and navigation features for the Mudlet client.

## Features

- Automatic room mapping using GMCP data
- Coordinate-based room positioning with exitsv2 support
- Speedwalking and pathfinding
- Map feature tracking
- Crowdmap support (future implementation)

## Installation

1. Download the latest WillowdaleMudletMapper.mpackage from the releases
2. Open Mudlet and connect to WillowdalemMUD
3. Install the package via Package Manager

## Usage

Common commands:
- `goto <room ID>` - Navigate to a specific room
- `goto <area name>` - Navigate to an area
- `mconfig` - View mapper settings
- `mm` - Toggle mapping mode

## Development

This project uses Muddler for building. To build:
```bash
muddler
```

### Local CI profiles

Muddler's local CI helper reinstalls the package on every build, and each
uninstall would normally restore Mudlet's `generic_mapper` package - a download
that then races the reinstall. The uninstall handler skips that restore when it
sees the helper's own `Muddler` global, so a profile running local CI needs no
setup. A profile that rebuilds some other way can opt out explicitly by setting
the global `_willowdale_mapper_devmode` to `true` before the uninstall, for
instance from the helper's `preremove` hook.

A real uninstall in a profile with neither still restores `generic_mapper` as
before.

## Credits

Originally forked from the IRE Mudlet Mapper project and adapted specifically for WillowdaleMUD.
