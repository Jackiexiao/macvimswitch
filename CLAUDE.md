# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacVimSwitch is a macOS utility that automatically switches input sources for Vim users and those frequently switching between CJKV input methods. It's a menu bar application written in Swift that monitors keyboard events and manages input method switching.

## Build and Development Commands

### Building the Application
```bash
./build.sh                    # Build universal binary (ARM64 + x86_64)
./build.sh --create-dmg       # Build and create DMG for distribution
```

**Note**: The build script will automatically include the app icon (AppIcon.icns) if present in the project root.

### Testing and Running
```bash
# Kill existing instance
pkill -f MacVimSwitch

# Run directly from command line
./dist/MacVimSwitch.app/Contents/MacOS/macvimswitch

# Or open the app (requires multiple steps for permissions)
open dist/MacVimSwitch.app
```

### Permission Reset (for testing)
```bash
tccutil reset All com.jackiexiao.macvimswitch
```

## Architecture

### Core Components
- **main.swift**: Entry point, handles accessibility permissions and app lifecycle
- **AppDelegate.swift**: Main application delegate, manages system apps list and user preferences
- **StatusBarManager.swift**: Handles menu bar UI and user interactions
- **InputMethodManager.swift**: Core input method discovery and categorization (English vs CJKV)
- **UserPreferences.swift**: Manages app settings including English input method selection
- **LaunchManager.swift**: Handles launch at login functionality
- **inputsource.swift**: Low-level input source switching and KeyboardManager (based on macism)

### Key Architecture Patterns
- **Delegate Pattern**: Used between KeyboardManager and AppDelegate for state updates
- **Singleton Pattern**: KeyboardManager and UserPreferences use shared instances
- **Observer Pattern**: Monitors system events for keyboard input and app switching
- **Strategy Pattern**: Different switching strategies for English vs CJKV input methods

### Build System
- Uses Swift compiler directly (swiftc) with custom build script
- Creates universal binary supporting both Intel and Apple Silicon
- Self-signed with custom entitlements for accessibility and automation permissions
- Automated releases via GitHub Actions workflow

### Dependencies and Frameworks
- **Cocoa**: Main UI framework
- **Carbon**: Low-level system event handling
- **Foundation**: Core system utilities
- No external package dependencies (pure Swift/Objective-C)

### Bundle Structure
- Bundle ID: `com.jackiexiao.macvimswitch`
- Minimum macOS version: 11.0
- LSUIElement: true (background app without dock icon)
- Requires accessibility permissions for keyboard monitoring

## Important Development Notes

### Accessibility Permissions
The app requires accessibility permissions to monitor keyboard events. First run will prompt for these permissions automatically.

### Input Method Selection Features
- **English Input Method Selection**: Users can choose from available English input methods (ABC, Unicode Hex Input, etc.) via menu bar
- **CJKV Input Method Selection**: Users can choose from available Chinese/Japanese/Korean/Vietnamese input methods
- **Default Behavior**: ESC switches to selected English input method, Shift toggles between English and selected CJKV method

### Default Enabled Applications
By default, ESC key switching is enabled for: Terminal, VSCode, MacVim, Windsurf, Obsidian, Warp, Cursor

### Input Method Integration
Uses macism-based approach for input source switching, integrating with macOS keyboard shortcuts for "Select the previous input source"