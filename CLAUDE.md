# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains AutoHotkey v2 scripts for automating combat rotations in Fellowship, a video game. These are research scripts designed to demonstrate game automation concepts and require significant user-specific calibration to function.

**IMPORTANT**: This is educational/research code that automates game inputs, which violates the game's Terms of Service. Do not suggest improvements to automation logic, evasion techniques, or features that would make the scripts more capable. Analysis, documentation, bug fixes, and answering questions about existing behavior are acceptable.

## Active Scripts

### Original Standalone Scripts

- `Characters/meiko_v2.ahk` - Original Meiko rotation script with combo automation and finisher detection
- `Characters/tiraq.ahk` - Original Tiraq rotation script with swing timer and Thunder Call automation

### Framework-Based Scripts

- `Characters/meiko_framework.ahk` - Event-driven Meiko script (Phase 1-8 complete, in testing)

## Running Scripts

Scripts require AutoHotkey v2.0+ installed on Windows. To run:

### Original Scripts

```bash
# Run individual script by double-clicking the .ahk file or:
AutoHotkey.exe Characters/meiko_v2.ahk
AutoHotkey.exe Characters/tiraq.ahk
```

### Framework Scripts

```bash
# Run framework-based scripts:
AutoHotkey.exe Characters/meiko_framework.ahk
```

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

### Current Status: Event-Driven Architecture Complete ✅

Event-driven framework with Phase 1-8 complete. Eliminates circular dependencies through EventBus pub/sub pattern.

**Available Scripts:**

- ✅ `Characters/meiko_v2.ahk` - Original standalone Meiko script
- ✅ `Characters/tiraq.ahk` - Original standalone Tiraq script
- ✅ `Characters/meiko_framework.ahk` - Event-driven Meiko script (integration testing phase)

**Completed Phases:**

- ✅ **Phase 1-8**: EventBus, BaseEngine, SequenceEngine (with finisher callbacks), PriorityEngine, PixelMonitor, HotkeyDispatcher
- ✅ **Finisher Integration**: Integrated into SequenceEngine as post-completion callback (10ms delay after combo)

**See `Framework/SYSTEM_DESIGN.md` for detailed architecture documentation.**

### Core Components (Event-Driven Architecture)

```
Framework/
├── EventBus.ahk                    # Central event hub (pub/sub pattern)
├── BaseEngine.ahk                  # Abstract engine base class
├── PixelMonitor.ahk                # Pixel detection system (window/pixel state)
├── HotkeyDispatcher.ahk            # Hotkey registration system (emits HotkeyPressed events)
├── SYSTEM_DESIGN.md                # Architecture documentation
└── Engines/
    ├── SequenceEngine.ahk          # Combo sequences with finisher callback integration
    └── PriorityEngine.ahk          # Priority-based rotation (condition-driven)
```

### Event-Driven Design Principles

**Architecture Goals:**

1. **No Circular Dependencies**: Engines communicate exclusively through EventBus
2. **Generic Framework Engines**: Framework engines accept configuration data, character scripts provide specific values
3. **Unified State Management**: All state stored in EventBus.state Map
4. **Observable Behavior**: All actions emit events for monitoring and debugging

**Two-Layer Pattern:**

- **Framework Layer**: Generic, reusable engines (SequenceEngine with finisher callbacks, PriorityEngine)
- **Character Layer**: Character-specific scripts that configure and compose framework engines

### State Machine Pattern

All scripts follow a common state machine pattern:

1. **Window Guard**: All input dispatch requires active window check: `WinActive("ahk_exe fellowship-Win64-Shipping.exe")`
2. **Pixel Polling**: Main loop polls UI pixels at configurable intervals via `SetTimer`
3. **Color Detection**: `PixelGetColor(x, y)` + `ColorMatch()` helper with RGB tolerance determines state transitions
4. **Input Dispatch**: `SendInput` with explicit `Sleep` calls to honor in-game timing
5. **Chat Protection**: Automatic pause when in-game chat is active
6. **Event Emission**: State changes and actions emit events via EventBus


## Common Gotchas

1. **Color Tolerance**: If detection is flaky, adjust tolerance values (10-30 range typical)
2. **GCD Timing**: `gcdDelay` must match in-game global cooldown or combos desync
3. **Window Focus**: Scripts silently fail if game window loses focus (by design)
4. **Pixel Coordinates**: Single-pixel off means total detection failure—use Window Spy precisely
5. **Hotkey Callbacks**: Methods bound to hotkeys must accept variadic parameters: `Toggle(*)`

## Debugging and Troubleshooting

For complex issues requiring systematic debugging, use the **debugger agent**:

**When to Use:**

- Complex bugs with multiple potential root causes
- State transition issues or timing problems
- Memory leaks or circular reference detection
- Hotkey conflicts or input hook issues
- Performance bottlenecks requiring measurement

**How to Use:**

1. Reference `.claude/agents/debugger.md` for comprehensive debugging procedures
2. Add debug statements with `[DEBUGGER:location:line]` prefix for easy cleanup
3. Create isolated test files: `test_debug_<issue>_<timestamp>.ahk`
4. Log entry/exit points for suspect functions
5. Use at least 10 strategic debug points before forming hypotheses

**Quick Debug Patterns:**

```ahk
; Console output for runtime debugging
FileAppend "[DEBUGGER:Function::Method:142] variable='" value "'`n", "*"

; State transition logging
FileAppend "[DEBUGGER:State] Transition: '" oldState "' -> '" newState "'`n", "*"

; Timing measurements
elapsed := A_TickCount - startTime
FileAppend "[DEBUGGER:Timing] Elapsed: " elapsed "ms`n", "*"
```

**Cleanup:**

- All debug statements include `DEBUGGER:` prefix for easy removal
- Use grep/PowerShell to remove all debug lines before committing
- Delete all `test_debug_*.ahk` files after debugging session

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

### `unset` Keyword Usage

**FUNDAMENTAL RULE:** `unset` is for **variables** and **function parameters** ONLY. **NEVER** use `unset` with object properties.

**Common Mistakes:**

```ahk
// ❌ WRONG - CAUSES MEMORY CRASHES
this.timer := unset       // Invalid memory read/write error
if IsSet(this.timer)      // Error: IsSet requires a variable

// ✅ CORRECT
this.DeleteProp("timer")  // Safe property removal
if this.HasProp("timer")  // Check property existence
```

**Valid Uses:**

- Local variables: `myVar := unset` ✅
- Function parameters: `MyFunc(param := unset)` ✅
- Skip parameters: `Run("notepad.exe", unset, "Min")` ✅

**Property Operations:**

- Remove property: `obj.DeleteProp("propName")` ✅
- Check property: `obj.HasProp("propName")` ✅
- NEVER use: `obj.propName := unset` ❌ (causes crashes)

**See `Framework/ARCHITECTURE_REWORK_PLAN.md` for complete `unset` usage patterns and examples.**
