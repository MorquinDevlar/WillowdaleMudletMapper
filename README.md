# GoMud Mapper

A custom GMCP mapper for GoMud, providing automatic room mapping and navigation features for the Mudlet client.

## Features

- Automatic room mapping using GMCP data
- Coordinate-based room positioning with exitsv2 support
- Speedwalking and pathfinding
- Map feature tracking
- Crowdmap support (future implementation)

## Installation

1. Download the latest GoMudMapper.mpackage from the releases
2. Open Mudlet and connect to GoMud
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

## Credits

Originally forked from the IRE Mudlet Mapper project and adapted specifically for GoMud.