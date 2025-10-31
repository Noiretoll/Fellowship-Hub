# Framework System Design

**Version:** 1.1
**Date:** 2025-10-29
**Status:** Production-ready

---

## Overview

### What

Event-driven combat rotation framework for AutoHotkey v2 game automation scripts. Provides reusable engines for building character-specific combat rotations.

### Why

**Problem:** Direct engine-to-engine communication creates circular dependencies, preventing proper cleanup and creating tight coupling.

**Solution:** Event-driven architecture where all communication flows through a central EventBus using pub/sub pattern.

### How

**Two-Layer Architecture:**

1. **Framework Layer** - Generic, reusable engines (`Framework/`)
2. **Character Layer** - Character-specific scripts that compose framework engines (`Characters/`)

**Communication Pattern:**

```
        EventBus (Hub)
       /    |    \
      /     |     \
Framework Engine-A Engine-B
```

No direct communication between components - all interaction via EventBus events.

---

## Core Components

### EventBus

**File:** `Framework/EventBus.ahk`

**Purpose:** Central event hub for pub/sub communication and global state management.

**Key Features:**

- **Event Emission:** `Emit(eventName, data := unset)`
- **Event Subscription:** `Subscribe(eventName, handler, priority := 0)`
- **State Management:** `SetState(key, value)` / `GetState(key, default := unset)`
- **Priority Callbacks:** Negative priorities execute first (e.g., -100 runs before 0)

**State Storage:**

All state stored in `bus.state` Map:

- `windowActive` - Game window focus state
- `chatActive` - Chat mode active/inactive
- `pixel_{name}` - Pixel detection states (set by PixelMonitor)

**Usage Pattern:**

```ahk
; Create bus (character script)
bus := EventBus()

; Set state
bus.SetState("windowActive", true)

; Subscribe to events
bus.Subscribe("HotkeyPressed", this.HandleHotkey.Bind(this))

; Emit events
bus.Emit("SequenceComplete", {comboName: "Combo1"})
```

---

### BaseEngine

**File:** `Framework/BaseEngine.ahk`

**Purpose:** Abstract base class for all framework engines. Provides lifecycle management and event subscription tracking.

**Key Features:**

- **Lifecycle Methods:** `Start()` / `Stop()` for engine activation
- **Subscription Tracking:** Automatically tracks all event subscriptions for cleanup
- **Event Access:** `this.bus` reference for emitting/subscribing to events

**Usage Pattern:**

```ahk
class MyEngine extends BaseEngine {
    __New(bus, name := "MyEngine") {
        super.__New(bus, name)
        ; Initialize engine-specific properties
    }

    Start() {
        ; Subscribe to events (tracked automatically)
        super.Start()
        this.bus.Subscribe("SomeEvent", this.HandleEvent.Bind(this))
    }

    Stop() {
        ; Unsubscribe all tracked events
        super.Stop()
    }
}
```

**CRITICAL - Subscription Cleanup:**

- Always call `Stop()` before deleting engines to break circular references
- `Bind(this)` creates engine → bus → callback → engine circular reference
- Pattern: `engine.Stop()` before `engine := unset`

---

### PixelMonitor

**File:** `Framework/PixelMonitor.ahk`

**Purpose:** Poll pixel conditions and emit state change events. Monitors multiple pixel targets simultaneously.

**Key Features:**

- **Multi-Target Monitoring:** Monitor multiple pixel locations with different conditions
- **Inverted Logic Support:** Match when pixel does NOT match target color
- **State Updates:** Automatically sets `bus.state["pixel_{targetName}"]` for each target
- **Event Emission:** Emits `PixelStateChanged` on state transitions

**Configuration:**

```ahk
pixelTargets := Map()
pixelTargets["Finisher"] := Map(
    "x", 1205,
    "y", 1119,
    "activeColor", 0xFFFFFF,  ; Target color (RGB)
    "tolerance", 10,           ; Color match tolerance
    "invert", true             ; true = match when NOT matching color
)

monitor := PixelMonitor(
    bus,
    pixelTargets,
    "fellowship-Win64-Shipping.exe",  ; Game process name
    50  ; Poll interval (ms)
)
```

**State Keys:**

- `pixel_Finisher` → true/false (set by monitor based on pixel detection)
- Character scripts check: `bus.GetState("pixel_Finisher", false)`

---

### HotkeyDispatcher

**File:** `Framework/HotkeyDispatcher.ahk`

**Purpose:** Register hotkeys and emit `HotkeyPressed` events. Respects window/chat state.

**Key Features:**

- **Bulk Registration:** Register multiple hotkeys from Map
- **Window Guard:** Only fires when game window active
- **Chat Protection:** Respects `chatActive` state (no events during chat)
- **Event Emission:** Emits `HotkeyPressed` with hotkey and action data

**Configuration:**

```ahk
hotkeyMap := Map(
    "3", "Combo3",      ; Key "3" → action "Combo3"
    "!3", "Combo3Alt",  ; Alt+3 → action "Combo3Alt"
    "1", "Combo1"
)

dispatcher := HotkeyDispatcher(
    bus,
    hotkeyMap,
    "fellowship-Win64-Shipping.exe"
)
```

**Event Data:**

```ahk
{
    hotkey: "3",         ; Original hotkey string
    action: "Combo3",    ; Mapped action name
    timestamp: 12345
}
```

---

### DebugMonitor

**File:** `Framework/DebugMonitor.ahk`

**Purpose:** Optional debugging and event logging system for development and troubleshooting.

**Key Features:**

- **Multi-Mode Output:** Tooltip overlay, file logging, or both
- **Event Filtering:** Automatically monitors common framework events
- **Real-Time Display:** Shows last N events in tooltip (configurable)
- **Timestamped Logs:** Creates dated log files in `/Logs` directory
- **Zero Impact:** Completely optional - scripts work without it

**Output Modes:**

- `"tooltip"` - Shows recent events in screen overlay (top-left corner)
- `"file"` - Logs all events to timestamped file (`Logs/debug_YYYYMMDD_HHMMSS.log`)
- `"both"` - Tooltip + file logging

**Monitored Events:**

- `HotkeyPressed` - When registered hotkeys are pressed
- `PixelStateChanged` - When pixel conditions change
- `FinisherExecuted` - When finishers fire
- `SequenceStarted/Complete` - When combos execute
- `WindowActive/Inactive` - When game window focus changes
- `StateChanged` - When important state changes (chat, window, pixels)

**Usage:**

```ahk
; Add to character script __New()
#Include ..\Framework\DebugMonitor.ahk

class MyCharacter {
    debugMonitor := ""

    __New() {
        this.bus := EventBus()

        ; Create debug monitor (optional)
        this.debugMonitor := DebugMonitor(
            this.bus,
            "tooltip",  ; or "file" or "both"
            5           ; Show last 5 events in tooltip
        )

        ; ... rest of setup ...
    }

    Start() {
        ; Start debug monitor
        if IsObject(this.debugMonitor) {
            this.debugMonitor.Start()
        }

        ; ... rest of startup ...
    }
}
```

**Example Tooltip Output:**

```
=== DebugMonitor ===
[14:23:45] Hotkey: Combo3 (key=3)
[14:23:45] Sequence: Started (engine=MeikoCombo3, steps=2)
[14:23:46] Sequence: Complete (engine=MeikoCombo3, steps=2)
[14:23:47] Finisher: Executed (mode=auto-combo)
[14:23:50] State: chatActive (old=false, new=true)
```

**Example Log File:**

```
=== DebugMonitor Log Started ===
Timestamp: 2025-10-29 14:23:40
Script: Meiko_AutoCombo.ahk
=====================================

[14:23:45] Hotkey: Combo3 (key=3)
[14:23:45] Sequence: Started (engine=MeikoCombo3, steps=2)
[14:23:46] Sequence: Complete (engine=MeikoCombo3, steps=2)
[14:23:47] Finisher: Executed (mode=auto-combo)
```

**Recommendation:**

- Use `"tooltip"` during active development for real-time feedback
- Use `"file"` for long-running tests or bug reproduction
- Use `"both"` for comprehensive debugging sessions
- Remove or comment out in production for performance

---

### SequenceEngine

**File:** `Framework/SequenceEngine.ahk`

**Purpose:** Execute multi-step combo sequences with optional post-completion callback.

**Key Features:**

- **Step-by-Step Execution:** Array of steps with delays
- **Finisher Integration:** Post-completion callback pattern (10ms delay)
- **Window/Chat Guards:** Respects `windowActive` and `chatActive` state
- **Event Emission:** Emits `SequenceStarted` / `SequenceComplete`

**Configuration:**

```ahk
; Define combo sequence
steps := [
    {key: "3", delay: 1050},  ; Send "3", wait 1050ms (GCD)
    {key: "1", delay: 0}       ; Send "1", no delay after
]

; Create finisher callback
finisherCallback := this.CheckAndExecuteFinisher.Bind(this)

; Create engine
engine := SequenceEngine(
    bus,
    "Combo3",              ; Engine name
    steps,                 ; Sequence steps
    finisherCallback,      ; Callback (optional)
    10                     ; Callback delay in ms (optional)
)
```

**Execution Pattern:**

1. `ExecuteSequence()` called (by character script)
2. For each step: `Send {key}` → `Sleep {delay}`
3. After last step completes, wait `callbackDelay` ms (default 10ms)
4. Call `finisherCallback()` if provided
5. Emit `SequenceComplete` event

**Finisher Modes:**

Character scripts may implement two independent finisher modes:

1. **Auto-Combo Mode (includes finisher):**

   - Executes combo sequences automatically
   - Fires finisher 200ms after each combo completes
   - Toggle: Alt+F1 (default)

2. **Finisher-Only Mode (no combo):**
   - Does NOT execute combos automatically
   - Fires finisher immediately when pixel becomes active
   - Independent of auto-combo mode
   - Can run simultaneously with manual combo execution
   - Toggle: Separate hotkey (character-specific)

**Implementation Notes:**

- Both modes monitor same finisher pixel (`pixel_Finisher`)
- Finisher-Only mode uses PixelMonitor event: `PixelStateChanged`
- Auto-Combo mode uses SequenceEngine callback after combo completion
- Modes are independent: can enable both, either, or neither

---

## Architecture Patterns

### Two-Layer Pattern

**Layer 1: Framework (Generic Building Blocks)**

- **Location:** `Framework/`
- **Purpose:** Reusable engines for ANY character
- **Contains:** Generic patterns (sequences, pixel monitoring, hotkey dispatch, debugging)
- **NO character assumptions:** No hardcoded delays, keys, positions, or modes

**Layer 2: Character Scripts (Character-Specific Logic)**

- **Location:** `Characters/{charactername}_framework.ahk`
- **Purpose:** Use framework engines to implement character mechanics
- **Contains:** Character-specific config (keys, delays, combos, toggles, modes)
- **Composes engines:** Instantiates and combines framework engines

**Example - Meiko Character Script:**

```ahk
class MeikoCharacter {
    __New() {
        ; Create EventBus
        this.bus := EventBus()

        ; Define character-specific combo
        combo := [
            {key: "3", delay: 1050},  ; Meiko's GCD timing
            {key: "1", delay: 0}
        ]

        ; Create finisher callback (character-specific logic)
        finisherCallback := this.CheckAndExecuteFinisher.Bind(this)

        ; Compose generic SequenceEngine with Meiko config
        this.engine := SequenceEngine(
            this.bus,
            "Combo3",
            combo,
            finisherCallback,
            10  ; Meiko's finisher delay
        )
    }

    ; Character-specific finisher logic
    CheckAndExecuteFinisher() {
        if !this.bus.GetState("pixel_Finisher", false)
            return

        Send this.finisherKey  ; Meiko's finisher key
        this.bus.Emit("FinisherExecuted", {timestamp: A_TickCount})
    }
}
```

**Benefits:**

- ✅ Reusable: Framework works for ANY character
- ✅ Maintainable: Character logic isolated in character scripts
- ✅ Testable: Framework engines tested independently
- ✅ Flexible: Each character can use engines differently

---

### Finisher Integration Pattern (CRITICAL)

**Why Finisher is NOT an Independent Engine:**

In-game mechanic: Finisher becomes available during combo execution but should fire AFTER combo completes (not interrupt mid-combo).

**Pattern 1: Post-Sequence Callback (Auto-Combo Mode)**

Used when finisher should fire after combo completes.

```
Combo Execution Flow:
1. Send Key1 → Wait GCD (1050ms)
2. Send Key2 → Wait 0ms
3. Combo Complete
4. Wait 200ms (finisher delay)
5. Check finisher pixel state
6. If ready → Send finisher key
```

**Implementation:**

```ahk
; Character script defines finisher callback
finisherCallback := this.CheckAndExecuteFinisher.Bind(this)

; SequenceEngine calls callback after completion
engine := SequenceEngine(bus, name, steps, finisherCallback, 200)

; Callback checks pixel state and executes
CheckAndExecuteFinisher() {
    ; Check pixel state (set by PixelMonitor)
    if !this.bus.GetState("pixel_Finisher", false)
        return

    ; Execute finisher
    Send this.finisherKey
    this.bus.Emit("FinisherExecuted", {timestamp: A_TickCount})
}
```

**Pattern 2: Pixel-Driven Finisher (Finisher-Only Mode)**

Used when finisher should fire immediately when pixel becomes active, independent of combos.

```
Finisher-Only Flow:
1. PixelMonitor detects finisher pixel active
2. Emits PixelStateChanged event
3. Character script receives event
4. If finisher-only mode enabled → Send finisher key
```

**Implementation:**

```ahk
; Subscribe to pixel state changes
this.bus.Subscribe("PixelStateChanged", this.HandlePixelChange.Bind(this))

; Handle pixel state changes
HandlePixelChange(data := unset) {
    if !IsSet(data) || data.name != "Finisher"
        return

    ; Only fire if finisher-only mode enabled
    if !this.finisherOnlyEnabled
        return

    ; Only fire if pixel became active (not inactive)
    if !data.active
        return

    ; Execute finisher immediately
    Send this.finisherKey
    this.bus.Emit("FinisherExecuted", {timestamp: A_TickCount, mode: "finisher-only"})
}
```

**Key Points:**

- **Pattern 1** (Post-Sequence): Finisher fires 200ms after combo completion
- **Pattern 2** (Pixel-Driven): Finisher fires immediately when pixel becomes active
- Both patterns use same finisher pixel (`pixel_Finisher`)
- Both patterns can be enabled simultaneously (independent modes)
- Window/chat guards apply to both patterns
- Pixel state: Set by PixelMonitor (`pixel_Finisher`)
- Callback: Character-specific logic, not framework code
- Event emission: `FinisherExecuted` for tracking/debugging

---

### Event Flow Patterns

**Combo Execution Flow (Auto-Combo Mode):**

```
User presses hotkey "3"
  ↓
HotkeyDispatcher detects press
  ↓
Emit: HotkeyPressed {hotkey: "3", action: "Combo3"}
  ↓
Character script receives event
  ↓
Call: engine.ExecuteSequence()
  ↓
Emit: SequenceStarted {name: "Combo3"}
  ↓
Execute steps: Send "3", Sleep 1050ms, Send "1"
  ↓
Emit: SequenceComplete {name: "Combo3"}
  ↓
Wait 200ms
  ↓
Call finisher callback
  ↓
Check pixel state
  ↓
If ready: Send finisher key
  ↓
Emit: FinisherExecuted {mode: "auto-combo"}
```

**Finisher-Only Mode Flow:**

```
PixelMonitor detects finisher pixel active
  ↓
Emit: PixelStateChanged {name: "Finisher", active: true}
  ↓
Character script receives event
  ↓
Check: finisher-only mode enabled?
  ↓
If enabled: Send finisher key immediately
  ↓
Emit: FinisherExecuted {mode: "finisher-only"}
```

**Pixel Monitoring Flow:**

```
PixelMonitor timer fires (every 50ms)
  ↓
Check window active state
  ↓
For each pixel target:
  - Get pixel color at (x, y)
  - Compare to activeColor with tolerance
  - Apply invert logic if enabled
  - Determine new state (true/false)
  ↓
If state changed:
  - SetState("pixel_{targetName}", newState)
  - Emit: PixelStateChanged {target, oldState, newState}
```

---

### State Management Pattern

**All State in EventBus.state Map:**

```ahk
; Set state
bus.SetState("windowActive", true)
bus.SetState("chatActive", false)
bus.SetState("pixel_Finisher", true)

; Get state
windowActive := bus.GetState("windowActive", true)  ; Default: true
finisherReady := bus.GetState("pixel_Finisher", false)  ; Default: false
```

**State Keys Convention:**

- `windowActive` - Game window has focus
- `chatActive` - Chat mode active (prevents automation)
- `pixel_{targetName}` - Pixel detection results

**Protection Guards:**

All input dispatch checks state before sending:

```ahk
; Check window active
if !WinActive("ahk_exe fellowship-Win64-Shipping.exe")
    return

; Check chat active
if this.bus.GetState("chatActive", false)
    return

; Safe to send input
Send "{1}"
```

---

## Character Script Development

### Creating a New Character Script

**Step 1: Create Character Script File**

```ahk
; Characters/newcharacter_framework.ahk
#Requires AutoHotkey v2.0
#Include ..\Framework\EventBus.ahk
#Include ..\Framework\BaseEngine.ahk
#Include ..\Framework\PixelMonitor.ahk
#Include ..\Framework\HotkeyDispatcher.ahk
#Include ..\Framework\Engines\SequenceEngine.ahk
```

**Step 2: Define Character Class**

```ahk
class NewCharacter {
    bus := ""
    pixelMonitor := ""
    hotkeyDispatcher := ""
    comboEngines := Map()

    __New() {
        this.bus := EventBus()
        this._SetupPixelMonitor()
        this._SetupComboEngines()
        this._SetupComboHotkeys()
    }
}
```

**Step 3: Configure Pixel Targets**

```ahk
_SetupPixelMonitor() {
    pixelTargets := Map()
    pixelTargets["Finisher"] := Map(
        "x", 1205,  ; Use Window Spy to find coordinates
        "y", 1119,
        "activeColor", 0xFFFFFF,
        "tolerance", 10,
        "invert", true
    )

    this.pixelMonitor := PixelMonitor(
        this.bus,
        pixelTargets,
        "fellowship-Win64-Shipping.exe",
        50
    )
}
```

**Step 4: Define Combo Sequences**

```ahk
_SetupComboEngines() {
    combos := Map(
        "Combo1", [
            {key: "1", delay: 1050},
            {key: "2", delay: 0}
        ]
    )

    finisherCallback := this.CheckAndExecuteFinisher.Bind(this)

    for comboName, steps in combos {
        engine := SequenceEngine(
            this.bus,
            comboName,
            steps,
            finisherCallback,
            10
        )
        this.comboEngines[comboName] := engine
    }
}
```

**Step 5: Setup Hotkeys**

```ahk
_SetupComboHotkeys() {
    hotkeyMap := Map(
        "1", "Combo1",
        "!1", "Combo1Alt"
    )

    this.hotkeyDispatcher := HotkeyDispatcher(
        this.bus,
        hotkeyMap,
        "fellowship-Win64-Shipping.exe"
    )
}
```

**Step 6: Start Engines**

```ahk
Start() {
    this.pixelMonitor.Start()

    for comboName, engine in this.comboEngines {
        engine.Start()
    }

    this.hotkeyDispatcher.Start()
}
```

---

### Pixel Calibration Guide

**Required Tool:** AutoHotkey Window Spy (bundled with AHK installation)

**Step 1: Launch Window Spy**

```powershell
# Search Windows for "Window Spy" and launch
```

**Step 2: Position Mouse Over Target**

1. Open game at 2560x1440 resolution (borderless, 100% scale)
2. Hover mouse over UI element to calibrate
3. Note X, Y coordinates from Window Spy
4. Note RGB color values (e.g., 0xFFFFFF for white)

**Step 3: Update Configuration**

```ahk
pixelTargets["TargetName"] := Map(
    "x", 1205,            ; From Window Spy
    "y", 1119,            ; From Window Spy
    "activeColor", 0xFFFFFF,  ; RGB from Window Spy
    "tolerance", 10,      ; Adjust if flaky (10-30 range)
    "invert", true        ; true = active when NOT matching
)
```

**Step 4: Test Detection**

Run script and observe tooltip feedback. Adjust tolerance if detection is unreliable.

---

### Testing Workflow

**Phase 1: Integration Tests (Automated)**

Run comprehensive integration tests:

```powershell
AutoHotkey.exe Framework/Tests/Integration_Test_Meiko.ahk
AutoHotkey.exe Framework/Tests/Integration_Test_Meiko_Finisher.ahk
```

**Current Test Coverage:**

- 15 integration tests (Phase 1-2 validation)
- 10 finisher integration tests (finisher callback pattern)
- Total: 25 automated tests

**Phase 2: Manual Tests (Synthetic Testing)**

Create manual test file to verify behavior:

```ahk
; Framework/Tests/Manual_Test_NewCharacter.ahk
#Include ../EventBus.ahk
#Include ../BaseEngine.ahk
#Include ..\Characters\newcharacter_framework.ahk

; Test scenarios
; - Combo execution with hotkeys
; - Finisher integration
; - Chat protection
; - Window focus handling
```

**Phase 3: In-Game Tests**

1. Run character script in-game
2. Test combo execution with Alt+F1 toggle
3. Verify finisher fires after combos when ready
4. Test chat protection (Enter, /, Escape)
5. Verify window focus handling (tab out/in)

**Testing Guide:**

See [Framework/Tests/MEIKO_TESTING_GUIDE.md](Framework/Tests/MEIKO_TESTING_GUIDE.md) for detailed testing procedures.

---

## Common Patterns and Gotchas

### `unset` Keyword Usage

**FUNDAMENTAL RULE:** `unset` is for **variables** and **function parameters** ONLY. **NEVER** use with object properties.

**Valid Uses:**

```ahk
; Local variables
myVar := unset  ; ✅ CORRECT

; Optional function parameters
MyFunc(param1, param2 := unset) {  ; ✅ CORRECT
    if IsSet(param2) {
        ; ...
    }
}

; Skip parameters
Run "notepad.exe", unset, "Min"  ; ✅ CORRECT
```

**Invalid Uses (CAUSES CRASHES):**

```ahk
; Object properties - DO NOT USE
this.timer := unset  ; ❌ WRONG - Memory corruption

; Use DeleteProp() instead
this.DeleteProp("timer")  ; ✅ CORRECT

; Check properties with HasProp()
if IsSet(this.timer) {  ; ❌ WRONG - Error
}
if this.HasProp("timer") {  ; ✅ CORRECT
}
```

**Why This Crashes:**

Object properties are COM-style reference counted. `unset` corrupts the property descriptor table, causing "Critical Error: Invalid memory read/write".

---

### Timer Management

**Pattern for Timer Cleanup:**

```ahk
class MyEngine {
    timer := unset  ; Property declaration

    Start() {
        ; Create timer
        callback := this.Update.Bind(this)
        SetTimer(callback, 1000)
        this.timer := callback  ; Store reference
    }

    Stop() {
        ; Delete timer
        if this.HasProp("timer") {
            SetTimer(this.timer, 0)  ; Period 0 = delete
            this.DeleteProp("timer")  ; Remove property
        }
    }
}
```

**One-Time Timers:**

```ahk
; Negative period = single execution, auto-deletes
SetTimer(() => ToolTip(), -3000)
```

---

### Color Tolerance

If pixel detection is unreliable, adjust tolerance:

```ahk
"tolerance", 10   ; Default - strict matching
"tolerance", 20   ; Moderate - handles slight variations
"tolerance", 30   ; Loose - handles lighting changes
```

**Typical Range:** 10-30

---

### GCD Timing

`gcdDelay` must match in-game global cooldown or combos desync:

```ahk
class MeikoCharacter {
    gcdDelay := 1050  ; Must match game's GCD
}
```

Test in-game and adjust if combos feel delayed or rushed.

---

### Window Focus

Scripts silently fail if game window loses focus (by design). All input dispatch checks:

```ahk
if !WinActive("ahk_exe fellowship-Win64-Shipping.exe")
    return
```

No error messages - script just stops sending input.

---

### Hotkey Callbacks

Methods bound to hotkeys must accept variadic parameters:

```ahk
; Hotkey callback signature
Toggle(*) {  ; Accept variadic params
    ; ...
}

; Register hotkey
Hotkey("F1", this.Toggle.Bind(this))
```

---

## Testing

### Integration Test Suite

**Location:** `Framework/Tests/`

**Test Files:**

1. **Integration_Test_Meiko.ahk** - 15 tests

   - EventBus pub/sub
   - PixelMonitor state detection
   - SequenceEngine combo execution
   - HotkeyDispatcher event emission
   - Chat/window state protection

2. **Integration_Test_Meiko_Finisher.ahk** - 10 tests
   - Finisher callback pattern
   - Post-completion timing (10ms delay)
   - Pixel state checking
   - Event emission
   - Multiple combos with finisher

**Total Coverage:** 25 automated integration tests

---

### Running Tests

**Automated Tests (Phase 1):**

```powershell
# Run integration tests
AutoHotkey.exe Framework/Tests/Integration_Test_Meiko.ahk
AutoHotkey.exe Framework/Tests/Integration_Test_Meiko_Finisher.ahk
```

**Expected Output:**

```
Test 1: EventBus state management - PASS
Test 2: PixelMonitor detection - PASS
...
Test 15: Complete integration - PASS

All tests passed!
```

**Manual Tests (Phase 2):**

See individual test files for manual test procedures.

**In-Game Tests (Phase 3):**

1. Launch game at 2560x1440 (borderless, 100% scale)
2. Run character script
3. Toggle auto-combo with Alt+F1
4. Test combos, finisher, chat protection
5. Verify behavior matches expectations

---

### Test Coverage

**Framework Components:**

- ✅ EventBus (state management, pub/sub, priority callbacks)
- ✅ BaseEngine (lifecycle, subscription tracking)
- ✅ PixelMonitor (multi-target detection, state updates, events)
- ✅ HotkeyDispatcher (registration, window/chat guards, events)
- ✅ SequenceEngine (step execution, finisher callback, protection)

**Character Scripts:**

- ✅ Meiko_AutoCombo (6 combos with hard-coded finisher, chat protection)
- ✅ Meiko_AutoFinisher (pixel-driven finisher only, chat protection)
- ✅ Rime (simple key sequences, no pixel monitoring or finishers)
- ⏸️ Tiraq (standalone script - does NOT use framework)

**Test Types:**

- Unit tests: Individual component behavior
- Integration tests: Component interaction via EventBus
- Manual tests: Synthetic testing without game
- In-game tests: Real-world usage validation

---

## Repository Structure

```
Fellowship-Hub/
├── Characters/
│   ├── Meiko_AutoCombo.ahk         # Meiko auto-combo with hard-coded finisher
│   ├── Meiko_AutoFinisher.ahk      # Meiko pixel-driven finisher only
│   ├── rime_framework.ahk          # Rime simple key sequences
│   └── tiraq.ahk                   # Standalone Tiraq (no framework)
│
├── Framework/
│   ├── EventBus.ahk                # Central event hub
│   ├── BaseEngine.ahk              # Engine base class
│   ├── PixelMonitor.ahk            # Pixel detection
│   ├── HotkeyDispatcher.ahk        # Hotkey registration
│   ├── SequenceEngine.ahk          # Combo sequences + finisher
│   ├── DebugMonitor.ahk            # Optional debugging/logging (optional)
│   ├── Tests/
│   │   ├── Integration_Test_Meiko.ahk           # 15 integration tests
│   │   ├── Integration_Test_Meiko_Finisher.ahk  # 10 finisher tests
│   │   └── MEIKO_TESTING_GUIDE.md               # Testing documentation
│   └── SYSTEM_DESIGN.md            # This document
│
└── CLAUDE.md                        # Project documentation
```

---

## Version History

**1.2** (2025-10-29)

- Added DebugMonitor.ahk - Optional debugging and event logging system
- Fixed critical bug: PixelMonitor event name mismatch (PixelConditionMet → PixelStateChanged)
- Removed unused PriorityEngine.ahk (268 lines of dead code)
- Updated documentation to reflect actual script architecture (added rime_framework.ahk, corrected tiraq.ahk status)

**1.1** (2025-10-29)

- Split meiko_framework.ahk into two focused scripts:
  - Meiko_AutoCombo.ahk: Auto-combo with hard-coded finisher (no pixel detection)
  - Meiko_AutoFinisher.ahk: Pixel-driven finisher only (no combo logic)
- User-friendly configuration sections in both scripts
- Ability keybinds defined once and referenced in combo sequences

**1.0** (2025-10-26)

- Initial system design document
- Event-driven architecture (Phase 1-8 complete)
- Finisher integration pattern documented
- 25 automated integration tests passing
- Production-ready for Meiko character script

---

**END OF SYSTEM DESIGN**
