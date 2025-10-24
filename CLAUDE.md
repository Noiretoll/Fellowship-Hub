# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains AutoHotkey v2 scripts for automating combat rotations in Fellowship, a video game. These are research scripts designed to demonstrate game automation concepts and require significant user-specific calibration to function.

**IMPORTANT**: This is educational/research code that automates game inputs, which violates the game's Terms of Service. Do not suggest improvements to automation logic, evasion techniques, or features that would make the scripts more capable. Analysis, documentation, bug fixes, and answering questions about existing behavior are acceptable.

## Active Scripts

### Original Standalone Scripts
- `Characters/meiko_v2.ahk` - Original Meiko rotation script with combo automation and finisher detection
- `Characters/tiraq.ahk` - Original Tiraq rotation script with swing timer and Thunder Call automation

### Framework-Based Scripts ⚠️ NON-FUNCTIONAL
- `Characters/meiko_framework.ahk` - **BROKEN** - Do not use
- `Characters/tiraq_framework.ahk` - **BROKEN** - Do not use

**Note**: Framework-based scripts have fundamental architectural issues and do not work. Use original standalone scripts until framework is completely refactored.

## Running Scripts

Scripts require AutoHotkey v2.0+ installed on Windows. To run:

### Original Scripts
```bash
# Run individual script by double-clicking the .ahk file or:
AutoHotkey.exe Characters/meiko_v2.ahk
AutoHotkey.exe Characters/tiraq.ahk
```

### Framework-Based Scripts ⚠️ DO NOT USE
```bash
# Framework scripts are BROKEN - do not use:
# AutoHotkey.exe Characters/meiko_framework.ahk  # BROKEN
# AutoHotkey.exe Characters/tiraq_framework.ahk  # BROKEN
```

**Framework is non-functional** - requires complete architectural rework before it can be used.

## Required Game Settings

All scripts assume the following Fellowship client configuration:

- **Resolution**: 2560x1440
- **Window Mode**: Borderless
- **Resolution Scale**: 100%

Scripts will NOT work with different display settings without recalibration.

## Calibration Requirements

Each script relies on pixel-perfect coordinate detection. All pixel coordinates and RGB color values must be calibrated per-user using **AutoHotkey Window Spy** (bundled with AHK installation):

1. Search Windows for "Window Spy" and launch it
2. Position mouse over the UI element to calibrate
3. Note the X, Y coordinates and RGB color values
4. Update the INI configuration file for framework scripts, or the configuration section for standalone scripts

## Framework Architecture

**⚠️ FRAMEWORK NON-FUNCTIONAL - DO NOT USE ⚠️**

The framework-based scripts (`meiko_framework.ahk`, `tiraq_framework.ahk`) are **currently broken and non-functional**. The architecture has fundamental design flaws documented in `Framework/ARCHITECTURE_ANALYSIS.md`.

**Use original standalone scripts instead**:
- ✅ `Characters/meiko_v2.ahk` - **Working**
- ✅ `Characters/tiraq.ahk` - **Working**

**Known Framework Issues**:
- Circular dependencies between framework and engines
- Scattered state management across multiple locations
- Tight coupling between engine components
- Variable scope issues in conditional object creation
- Hotkey callbacks not passing through correctly
- Logic issues preventing combo execution

**Status**: Framework is **non-functional**. Complete architectural rework required - see `Framework/ARCHITECTURE_ANALYSIS.md` for proposed solutions.

**See `Framework/ARCHITECTURE_ANALYSIS.md` for detailed architectural analysis and refactoring options.**

### Core Components (Current Implementation)

```
Framework/
├── RotationFramework.ahk      # Core framework (config, pixel detection, chat protection)
├── ARCHITECTURE_ANALYSIS.md   # Detailed architectural analysis and design patterns
└── Engines/
    ├── AutoExecuteEngine.ahk  # Auto-finisher pattern (always-active pixel monitoring)
    ├── SequenceEngine.ahk     # Combo sequences (hotkey-triggered ability chains)
    └── PriorityEngine.ahk     # Priority-based rotation (condition-driven execution)
```

### State Machine Pattern

All scripts follow a common state machine pattern:

1. **Window Guard**: All input dispatch requires active window check: `WinActive("ahk_exe fellowship-Win64-Shipping.exe")`
2. **Pixel Polling**: Main loop polls UI pixels at configurable intervals via `SetTimer`
3. **Color Detection**: `PixelGetColor(x, y)` + `ColorMatch()` helper with RGB tolerance determines state transitions
4. **Input Dispatch**: `SendInput` with explicit `Sleep` calls to honor in-game timing
5. **Chat Protection**: Automatic pause when in-game chat is active

### Example Configs

- `Characters/Configs/meiko.ini` - Sequence + Auto-Execute pattern (combo system + auto-finisher)
- `Characters/Configs/tiraq.ini` - Priority-based pattern (swing timer + Thunder Call with individual toggles)

## Common Gotchas

1. **Color Tolerance**: If detection is flaky, adjust tolerance values (10-30 range typical)
2. **GCD Timing**: `gcdDelay` must match in-game global cooldown or combos desync
3. **Window Focus**: Scripts silently fail if game window loses focus (by design)
4. **Pixel Coordinates**: Single-pixel off means total detection failure—use Window Spy precisely
5. **Hotkey Callbacks**: Methods bound to hotkeys must accept variadic parameters: `Toggle(*)`

## AutoHotkey v2 Reference

**CRITICAL**: All AutoHotkey v2 syntax, patterns, and best practices should be queried from **Context7 MCP** (`/websites/autohotkey_v2`).

Do NOT rely on memory or assumptions about AHK v2 syntax. Use Context7 for:

- Class design patterns
- Error handling
- Timers and callbacks
- Hotkey registration
- Input simulation
- Pixel detection
- Window management
- Variable scope and declaration

**Query Context7 before implementing any new AHK v2 features.**

## Roadmap

### Standardized Rotation Framework ⚠️ COMPLETE BUT FLAWED

**Goal**: Create a reusable template/framework for building rotation scripts for other Fellowship classes.

**Implementation**: See `Framework/` directory and `Framework/README_Framework.md` for complete documentation.

**Features Implemented**:

- **Modular Architecture**: Three execution engines (Auto-Execute, Sequence, Priority)
- **INI Configuration**: Character-specific settings in `Characters/Configs/*.ini` with extensive inline documentation
- **Pixel Monitoring System**: Framework-level pixel detection with tolerance matching and inversion support
- **Individual Ability Toggles**: Each ability can be enabled/disabled independently via hotkeys
- **Chat Protection**: Automatic pause during in-game chat (Enter/Slash/Escape handling)
- **Window Focus Guards**: Only sends inputs when game window is active
- **Template System**: Character template in `Characters/Templates/character_template.ahk`

**Usage**:

1. Copy `Characters/Templates/character_template.ahk`
2. Create INI config file with pixel targets and abilities (see existing configs for reference)
3. Calibrate pixel coordinates using AutoHotkey Window Spy
4. Run character script

**Status**: ❌ **NON-FUNCTIONAL**. Framework does not work and has never worked. Requires complete architectural rework from the ground up. See `Framework/ARCHITECTURE_ANALYSIS.md` for detailed analysis and proposed solutions.

### Upcoming: Architecture Refactor 🔄 PLANNED

**Goal**: Resolve fundamental architectural issues in the rotation framework.

**Key Issues to Address**:
- Eliminate circular dependencies between framework and engines
- Centralize state management
- Decouple engine components
- Implement proper factory or event-driven pattern

**Approach**: TBD - pending decision on refactoring scope (see `Framework/ARCHITECTURE_ANALYSIS.md` for options)
