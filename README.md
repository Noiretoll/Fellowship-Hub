# Fellowship Rotation Scripts
These scripts automate game inputs and violate Fellowship's Terms of Service. For educational/research purposes only. Use at your own risk.

## Overview

AutoHotkey v2 scripts for Fellowship.

## Quick Start

1. Install [AutoHotkey v2.0+](https://www.autohotkey.com/)
2. Configure game to 2560x1440 borderless windowed mode at 100% resolution scale
3. Choose a character script from `Characters/` folder
4. Follow instructions at the beginning of the character script
5. Run the script

## Requirements

- AutoHotkey 2.0+
- Windows OS
- Fellowship game client
- Manual pixel calibration per system

**Note**: Scripts require pixel-perfect calibration using AutoHotkey Window Spy and will NOT work without proper configuration.

## Available Scripts

### Meiko

- **Meiko_AutoCombo.ahk** - Auto-combo with hard-coded finisher
- **Meiko_AutoFinisher.ahk** - Pixel-driven finisher only
- Event-driven framework architecture
- Chat input protection

### Rime (rime_framework.ahk)

- Simple key sequences
- No pixel monitoring or finishers

### Tiraq (tiraq.ahk)

- Swing timer automation
- Thunder Call cooldown tracking
- **Controls:**
  - **F1** - Toggle automation on/off
  - **F10** - Exit script
