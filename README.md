# Fellowship Rotation Scripts

**⚠️ DISCLAIMER**: These scripts automate game inputs and violate Fellowship's Terms of Service. For educational/research purposes only. Use at your own risk.

## Overview

AutoHotkey v2 scripts for automating combat rotations in Fellowship. Scripts use pixel detection to monitor game UI and send keyboard inputs based on detected states.

**⚠️ Use standalone scripts only**:
- **Standalone** (working): `meiko_v2.ahk`, `tiraq.ahk` - Fully functional
- **Framework-based** (broken): Do NOT use - non-functional, requires complete rework

## Quick Start

1. Install [AutoHotkey v2.0+](https://www.autohotkey.com/)
2. Configure game to 2560x1440 borderless windowed mode at 100% resolution scale
3. Choose a character script from `Characters/` folder
4. Calibrate pixel coordinates for your system
5. Run the script

**For detailed setup and configuration**, see:
- `CLAUDE.md` - Technical architecture and development guide
- ⚠️ `Framework/` - Non-functional, requires architectural rework

## Requirements

- AutoHotkey 2.0+
- Windows OS
- Fellowship game client
- Specific display settings (2560x1440, borderless, 100% scale)
- Manual pixel calibration per system

**Note**: Scripts require pixel-perfect calibration using AutoHotkey Window Spy and will NOT work without proper configuration.

## Available Scripts

### Meiko
- Combo automation with ability sequences
- Automatic finisher detection
- Chat input protection

### Tiraq
- Swing timer automation
- Thunder Call cooldown tracking

## Basic Controls

Most scripts use:
- **F1** - Toggle automation on/off
- **F10** - Exit script
- **Enter** - Opens chat (pauses automation)
- **Escape** - Cancel chat

<<<<<<< HEAD
See individual script files or documentation for specific controls.
=======
**Meiko v2 Chat Protection:**
- **Enter** or **/** - Toggle chat mode (automatic, transparent passthrough)

## Configurations

Note: AutoHotKey 2.0+ required

### Display Settings

**Resolution:** 2560x1440
**Window:** Borderless
**Resolution Scale:** 100
>>>>>>> ade39209d68d7c805a9534164dd605e5fa9221fa
