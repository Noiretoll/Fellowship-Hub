# Fellowship Notes

Everything here is dependant on your UI setup. These will NOT be usable without modification. Review the configuration instructions in the file. Use AutoHotKey Window Spy to identify the required UI configurations information (download AHK 2.0+, search your PC for "Window Spy")
For research purposes only. Although AHK is rarely punished for uses like this, do not use in-game. It's against TOS, very likely detectable, and we don't know the devs tolerance for it.

## Features

### Meiko v2 Script
- **Combo Automation**: Predefined ability sequences triggered by hotkeys (1, 2, 3, Alt+combos)
- **Finisher Detection**: Automatically fires finisher when icon lights up (off-GCD)
- **Chat Input Protection**: NEW - Automatically pauses script when typing in-game chat
  - Press Enter or "/" to open chat → Script pauses all inputs
  - Type safely without key spam
  - Press Enter to send or Escape to cancel → Script resumes
  - Tooltip feedback shows chat mode status
  - Works seamlessly mid-combo (pauses and resumes)

### Tiraq Script
- **Swing Timer Automation**: Detects swing bar and sends Heavy Strike in timing window
- **Thunder Call on Cooldown**: Auto-casts Thunder Call when available during combat

## Controls

**All Scripts:**
- **F1** - Toggle monitoring on/off
- **F10** - Exit script

**Meiko v2 Chat Protection:**
- **Enter** or **/** - Toggle chat mode (automatic, transparent passthrough)

## Configurations

Note: AutoHotKey 2.0+ required

### Display Settings

**Resolution:** 2560x1440
**Window:** Borderless
**Resolution Scale:** 100
