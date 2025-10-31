# Fellowship Rotation Scripts

**⚠️ DISCLAIMER**: These scripts automate game inputs and violate Fellowship's Terms of Service. For educational/research purposes only. Use at your own risk.

## Overview

AutoHotkey v2 scripts for automating combat rotations in Fellowship. Scripts use pixel detection to monitor game UI and send keyboard inputs based on detected states.

## Quick Start

1. Install [AutoHotkey v2.0+](https://www.autohotkey.com/)
2. Choose a character script from `Characters/` folder
3. Calibrate pixel coordinates for your system
4. Run the script

**For detailed setup and configuration**, see `CLAUDE.md` for technical architecture and development guide.

## Requirements

- AutoHotkey 2.0+
- Windows OS
- Fellowship game client
- Manual pixel calibration per system

**Note**: Scripts require pixel-perfect calibration using AutoHotkey Window Spy and will NOT work without proper configuration.

## Available Scripts

### Meiko (meiko_framework.ahk)

- Event-driven framework architecture
- Combo automation with ability sequences
- Automatic finisher detection (post-combo callback pattern)
- Chat input protection
-

### Tiraq (tiraq.ahk)

- Swing timer automation
- Thunder Call cooldown tracking
- **Controls:**
  - **F1** - Toggle automation on/off
  - **F10** - Exit script
