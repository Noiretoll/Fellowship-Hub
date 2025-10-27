# Fellowship Rotation Scripts
These scripts automate game inputs and violate Fellowship's Terms of Service. For educational/research purposes only. Use at your own risk.

## Overview

AutoHotkey v2 scripts for Fellowship.

## Quick Start

1. Install [AutoHotkey v2.0+](https://www.autohotkey.com/)
2. Configure game to 2560x1440 borderless windowed mode at 100% resolution scale
3. Choose a character script from `Characters/` folder
4. Calibrate pixel coordinates for your system
5. Run the script

## Requirements

- AutoHotkey 2.0+
- Windows OS
- Fellowship game client
- Specific display settings (2560x1440, borderless, 100% scale)
- Manual pixel calibration per system

**Note**: Scripts require pixel-perfect calibration using AutoHotkey Window Spy and will NOT work without proper configuration.

## Available Scripts

### Meiko (meiko_framework.ahk)
- Event-driven framework architecture
- Combo automation with ability sequences
- Automatic finisher detection (post-combo callback pattern)
- Chat input protection
- **Controls:**
  - **Alt+F1** - Toggle auto-combo on/off
  - **3, !3, 1, !1, 2, !2** - Combo sequences (when enabled)
  - **Enter** / **/** - Opens chat (pauses automation)
  - **Escape** - Cancel chat
  - **F10** - Exit script

### Tiraq (tiraq.ahk)
- Swing timer automation
- Thunder Call cooldown tracking
- **Controls:**
  - **F1** - Toggle automation on/off
  - **F10** - Exit script

## Display Settings

**Resolution:** 2560x1440
**Window Mode:** Borderless
**Resolution Scale:** 100%
