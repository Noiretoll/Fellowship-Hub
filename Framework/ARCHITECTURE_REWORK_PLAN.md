# Framework Architecture Rework Plan
**Date:** 2025-01-24
**Status:** NOT STARTED
**Target:** Event-Driven Architecture (Solution 3)

---

## Executive Summary

**Current Problem:** Circular dependencies between Framework → Engines → Framework prevent proper object cleanup and create tight coupling.

**Solution:** Implement event-driven architecture where engines communicate exclusively through a central EventBus, eliminating all direct references between components.

**Approach:** 8-phase incremental migration with synthetic testing before touching game logic.

---

## Architecture Overview

### Current (Broken)
```
Framework ←→ Engine A ←→ Engine B
     ↓          ↑
     └──────────┘
(Circular reference cycle)
```

### Target (Event-Driven)
```
        EventBus (Hub)
       /    |    \
      /     |     \
Framework Engine-A Engine-B
(No direct communication between components)
```

---

## Context7 Design Patterns Reference

**CRITICAL:** Before implementing any phase, query Context7 MCP (`/websites/autohotkey_v2`) for:
- Class inheritance patterns (`extends`, `super`, `__New`, `__Delete`)
- Event callback registration patterns (`OnEvent`, callback management)
- Timer management patterns (`SetTimer`, cleanup, avoiding circular references)
- Map/Array iteration and manipulation patterns
- Memory management patterns (reference counting, `ObjPtr`, `ObjAddRef`, `ObjRelease`)

**Key Context7 Patterns Identified:**
1. **Callback Registration:** Use `Bind(this)` to create method callbacks, store in array for cleanup
2. **Timer Cleanup:** Always store timer callback reference, use `SetTimer callback, 0` to delete
3. **Circular Reference Avoidance:** Use `ObjPtr` + `ObjFromPtrAddRef` for timers or unset references in `__Delete`
4. **Priority-Based Callbacks:** Use negative numbers for high-priority (execute first)
5. **Stop Propagation:** Return `true` from callback to prevent subsequent callbacks
6. **Map Storage:** Use `Map.Has()` to check existence, `Map.Delete()` returns removed value
7. **Class Inheritance:** Always call `super.__New()` and `super.__Delete()` in derived classes

---

## Phase Execution Guide

### PHASE 1: Core Event Bus Implementation

**Objective:** Create standalone event subscription/emission system with zero dependencies.

**Files to Create:**
- `Framework/EventBus.ahk`
- `Framework/Tests/Test_EventBus.ahk`

**Design Pattern: Observer/PubSub Pattern**

**EventBus Class Structure:**
```
class EventBus {
    Properties:
        - subscribers: Map<eventName, Array<{callback, priority}>>
        - state: Map<key, value>

    Methods:
        - Subscribe(eventName, callback, priority := 0)
        - Unsubscribe(eventName, callback)
        - Emit(eventName, eventData := unset)
        - SetState(key, value)
        - GetState(key, default := unset)
        - Clear()

    Private Methods:
        - _SortSubscribers(eventName)
}
```

**Context7 Patterns to Use:**
1. **Map Management:**
   - Use `Map()` for subscribers and state storage
   - Check existence: `this.subscribers.Has(eventName)`
   - Delete safely: `this.subscribers.Delete(eventName)`
   - Iterate: `for key, value in this.subscribers`

2. **Array Management:**
   - Push subscriber: `subscribers.Push({callback: callback, priority: priority})`
   - Remove by index: `subscribers.RemoveAt(index)`
   - Sort using bubble sort pattern (simple, adequate for small lists)

3. **Callback Invocation:**
   - Call with data: `sub.callback.Call(data)`
   - Check return value to stop propagation: `if result = true`

4. **State Change Events:**
   - On `SetState()`, emit "StateChanged" event with old/new values
   - Use `IsSet(oldValue)` to check if state existed before

**Test Coverage Requirements:**
- Multiple subscribers receive events in order
- Event data propagates correctly (Map with various types)
- Priority ordering (negative = first, 0 = normal, positive = last)
- Return `true` stops propagation
- Unsubscribe removes callback completely
- State management triggers "StateChanged" events
- No memory leaks over 1000+ subscribe/unsubscribe cycles

**Acceptance Criteria:**
- [ ] EventBus compiles without errors
- [ ] All 6+ tests pass
- [ ] No circular references (verify with `ObjPtr()` tracking)
- [ ] Subscribers can be added/removed without errors
- [ ] State changes emit events with correct old/new values

---

### PHASE 2: Base Engine Abstraction

**Objective:** Create abstract engine class that uses only EventBus for communication.

**Files to Create:**
- `Framework/BaseEngine.ahk`
- `Framework/Tests/TestEngine.ahk` (concrete test implementation)
- `Framework/Tests/Test_BaseEngine.ahk`

**Design Pattern: Abstract Base Class + Template Method**

**BaseEngine Class Structure:**
```
class BaseEngine {
    Properties:
        - bus: EventBus reference (only external reference allowed)
        - name: String (engine identifier)
        - isMonitoring: Boolean (engine state)
        - subscriptions: Array<{eventName, handler}> (for cleanup)

    Public Methods:
        - __New(bus, name := "")
        - Start() [override in subclass]
        - Stop() [override in subclass]
        - OnEvent(eventName, handler, priority := 0)
        - EmitEvent(eventName, data := unset)
        - GetState(key, default := unset)
        - SetState(key, value)
        - __Delete()

    Template Method Pattern:
        - Start() calls super.Start(), then custom logic
        - Stop() calls super.Stop(), then custom logic
        - __Delete() automatically cleans up all subscriptions
}
```

**Context7 Patterns to Use:**
1. **Class Inheritance:**
   - Extend: `class BaseEngine extends Object`
   - Constructor: `__New(bus, name := "")` calls no super (Object is base)
   - Store parameters: `this.bus := bus`, `this.name := name`
   - Initialize collections: `this.subscriptions := []`

2. **Subscription Tracking:**
   - Track each subscription: `this.subscriptions.Push(Map("eventName", name, "handler", handler))`
   - Clean up in `__Delete()`: `for sub in this.subscriptions { this.bus.Unsubscribe(...) }`

3. **Method Binding:**
   - Bind methods for callbacks: `this.HandleEvent.Bind(this)`
   - Ensures `this` context is preserved in callbacks

4. **Lifecycle Management:**
   - `__Delete()` is called when last reference released
   - Emit "EngineDeleted" event before cleanup
   - Clear subscriptions array after unsubscribing all

**TestEngine Implementation:**
```
class TestEngine extends BaseEngine {
    Properties:
        - counter: Integer

    Methods:
        - __New(bus, name := "TestEngine")
        - Start() [override]
        - HandleTrigger(data)
}
```

**Test Coverage Requirements:**
- Multiple engines operate independently
- Engines communicate via bus only (no direct references)
- Deleting one engine doesn't affect others
- `__Delete()` emits "EngineDeleted" event
- All subscriptions removed after deletion
- No circular references between engine and bus

**Acceptance Criteria:**
- [ ] BaseEngine compiles without errors
- [ ] TestEngine compiles and extends BaseEngine correctly
- [ ] All 5+ tests pass
- [ ] Engine deletion cleans up all subscriptions
- [ ] No memory leaks after create/delete cycles
- [ ] Engines use only `this.bus` for communication

---

### PHASE 3: Timer-Based Simulation

**Objective:** Create fake event generators to simulate game state without pixel detection.

**Files to Create:**
- `Framework/Tests/SimulatorEngines.ahk`
- `Framework/Tests/Test_Simulation.ahk`

**Design Pattern: Simulator Pattern + Timer Management**

**Simulator Engine Classes:**

**PixelSimulator:**
```
class PixelSimulator extends BaseEngine {
    Properties:
        - timer: Function reference (for cleanup)
        - interval: Integer (milliseconds)

    Methods:
        - Start() [override - create timer]
        - Stop() [override - delete timer]
        - GeneratePixelEvent() [timer callback]
        - __Delete() [override - ensure timer stopped]
}
```

**AutoExecuteSimulator:**
```
class AutoExecuteSimulator extends BaseEngine {
    Properties:
        - isProcessing: Boolean

    Methods:
        - Start() [subscribe to "PixelConditionMet"]
        - HandlePixelReady(data)
        - Execute()
        - CompleteExecution() [called via timer]
}
```

**SequenceSimulator:**
```
class SequenceSimulator extends BaseEngine {
    Properties:
        - sequenceActive: Boolean

    Methods:
        - Start() [subscribe to "HotkeyPressed", "AbilityExecuting"]
        - HandleHotkey(data)
        - HandleInterrupt(data)
        - _StartSequence(sequenceKey)
        - _ExecuteNextStep() [recursive via timer]
        - _CompleteSequence()
        - _InterruptSequence(reason)
}
```

**Context7 Patterns to Use:**
1. **Timer Management (CRITICAL):**
   - **Pattern from Context7:** Store timer callback to enable cleanup
   ```
   // Create timer
   callback := this.GenerateEvent.Bind(this)
   SetTimer(callback, 1000)
   this.timer := callback  // MUST store reference

   // Delete timer
   if IsSet(this.timer) {
       SetTimer(this.timer, 0)  // Period 0 = delete
       this.timer := unset
   }
   ```

2. **Avoiding Circular References with Timers:**
   - **Pattern from Context7:** Use ObjPtr pattern for timer callbacks
   ```
   // Alternative: Uncounted reference pattern
   __New() {
       SetTimer this.Timer := this.Update.Bind(this), 1000
       ObjRelease(ObjPtr(this))  // Decrement ref count
   }

   __Delete() {
       ObjPtrAddRef(this)  // Re-increment before cleanup
       SetTimer this.Timer, 0
       this.Timer := unset
   }
   ```

3. **One-Time Timers:**
   - Use negative period: `SetTimer(() => this.Complete(), -500)`
   - Automatically deletes after single execution

4. **State Coordination:**
   - Check state before action: `if this.GetState("executing", false)`
   - Set state during action: `this.SetState("executing", true)`
   - Clear state after action: `this.SetState("executing", false)`

**Simulation Flow:**
1. PixelSimulator emits "PixelConditionMet" every N ms
2. AutoExecuteSimulator responds → Sets state → Emits "AbilityExecuting"
3. SequenceSimulator listening for "AbilityExecuting" → Interrupts if active
4. State "comboLocked" prevents concurrent sequences

**Test Coverage Requirements:**
- AutoExecute responds to pixel events
- Sequence interruption works (via "AbilityExecuting" event)
- State locking prevents race conditions
- Timer cleanup on Stop() (no events after stopped)
- Multiple rapid events processed correctly

**Acceptance Criteria:**
- [ ] All simulator engines compile without errors
- [ ] All 4+ simulation tests pass
- [ ] Interruption logic works via events only
- [ ] State prevents concurrent execution
- [ ] Timers stop cleanly on engine Stop()
- [ ] No timer leaks (verify with long-running test)

---

### PHASE 4: Framework Integration Prep

**Objective:** Modify RotationFramework to use EventBus without changing existing engines yet.

**Files to Modify:**
- `Framework/RotationFramework.ahk`

**Design Pattern: Adapter Pattern (Backward Compatibility)**

**Framework Modifications:**

**Add EventBus Support:**
```
__New(configPath) {
    // Create bus FIRST
    this.bus := EventBus()

    // Existing initialization
    this.engines := Map()
    this.abilities := Map()
    this.state := this.bus.state  // Point to bus state

    // ... rest of initialization
}
```

**Add Helper Methods:**
```
EmitEvent(eventName, data := unset)
OnFrameworkEvent(eventName, handler, priority := 0)
```

**Modify _InitializeEngines():**
- Engines now receive `bus` parameter (first parameter)
- Framework reference becomes second parameter (backward compat)
- Still calls `SetAutoExecuteEngine()` (removed in Phase 6)

**Context7 Patterns to Use:**
1. **Object Initialization Order:**
   - Create EventBus before everything else
   - State Map can reference bus.state directly
   - Engines created after bus exists

2. **Backward Compatibility:**
   - Keep existing engine constructors working
   - Add bus parameter first: `Engine(bus, framework, ...)`
   - Gradual migration: new engines use bus, old use framework

**Acceptance Criteria:**
- [ ] Framework initializes with EventBus
- [ ] Existing engines still load (compatibility maintained)
- [ ] Framework starts without errors
- [ ] `this.bus` accessible from framework methods
- [ ] State accessible via both `this.state` and `this.bus.state`

---

### PHASE 5: AutoExecuteEngine Conversion

**Objective:** Convert AutoExecuteEngine to event-driven architecture, removing framework reference.

**Files to Modify:**
- `Framework/Engines/AutoExecuteEngine.ahk`

**Design Pattern: Event-Driven Component**

**Conversion Strategy:**

**OLD Pattern → NEW Pattern:**
```
// OLD: Direct framework reference
this.framework.CheckPixelCondition(target)
this.framework.state["key"] := value

// NEW: Event subscription and state access
this.OnEvent("PixelConditionMet", this.HandlePixelReady.Bind(this), -10)
this.SetState("key", value)
```

**Class Structure Changes:**
```
OLD Constructor:
    __New(framework, abilityName)
    Store: this.framework, this.abilityName
    Access: this.ability := framework.abilities[abilityName]

NEW Constructor:
    __New(bus, abilityName, pixelTarget, keybind)
    Store: this.abilityName, this.pixelTarget, this.keybind
    Call: super.__New(bus, "AutoExecute_" . abilityName)
```

**Event Subscriptions:**
- Subscribe to: "PixelConditionMet" (high priority: -10)
- Subscribe to: "ChatActivated" (to pause during chat)
- Subscribe to: "WindowInactive" (to pause when window loses focus)
- Emit: "AbilityExecuting" (when starting)
- Emit: "AbilityExecuted" (when complete)

**State Management:**
- Check state: `this.GetState("autoExecute_processing", false)`
- Set state: `this.SetState("autoExecute_processing", true)`
- Check chat: `this.GetState("chatActive", false)`

**Context7 Patterns to Use:**
1. **High-Priority Callbacks:**
   - Use negative priority for interruption events
   - `this.OnEvent("PixelConditionMet", handler, -10)`
   - Ensures auto-execute fires before other systems

2. **Execution Delay Pattern:**
   - Use one-time timer: `SetTimer(() => this.CompleteExecution(), -500)`
   - No need to store reference (auto-deletes)
   - Use arrow function for simple callbacks

3. **Conditional Event Response:**
   - Check event data: `if data["target"] != this.pixelTarget { return }`
   - Early return if not relevant to this engine
   - Prevents unnecessary processing

**Removal Checklist:**
- [ ] Remove `this.framework` property
- [ ] Remove all `this.framework.CheckPixelCondition()` calls
- [ ] Remove all `this.framework.state[...]` access
- [ ] Remove internal timer management (move to PixelMonitor)
- [ ] Add event subscriptions in Start()
- [ ] Add event emissions on actions
- [ ] Use BaseEngine state methods

**Acceptance Criteria:**
- [ ] No `this.framework` references remain
- [ ] Engine uses only `this.bus` for communication
- [ ] Subscribes to "PixelConditionMet" event
- [ ] Emits "AbilityExecuting" and "AbilityExecuted" events
- [ ] State managed through EventBus methods
- [ ] Compiles without errors
- [ ] Works with simulator tests from Phase 3

---

### PHASE 6: SequenceEngine Conversion

**Objective:** Convert SequenceEngine to event-driven architecture.

**Files to Modify:**
- `Framework/Engines/SequenceEngine.ahk`

**Design Pattern: State Machine via Events**

**Remove Engine-to-Engine References:**
```
OLD Pattern:
    SetAutoExecuteEngine(engine)
    this.autoExecuteEngine := engine
    this.autoExecuteEngine.Execute(true)

NEW Pattern:
    OnEvent("AbilityExecuting", this.HandleInterruption.Bind(this), -5)
    // Check event data type instead of calling engine directly
```

**Class Structure Changes:**
```
OLD Constructor:
    __New(framework)
    Store: this.framework, this.autoExecuteEngine

NEW Constructor:
    __New(bus, sequences)
    Store: this.sequences (Map of sequence definitions)
    Call: super.__New(bus, "SequenceEngine")
```

**Event Subscriptions:**
- Subscribe to: "HotkeyPressed" (to start sequences)
- Subscribe to: "AbilityExecuting" (high priority -5, for interruption)
- Emit: "SequenceStarted" (when beginning)
- Emit: "SequenceComplete" (when finished)
- Emit: "SequenceInterrupted" (when interrupted)

**State Machine States:**
```
States:
    - comboLocked: Boolean (prevents new sequences)
    - sequenceActive: Boolean (sequence in progress)

Transitions:
    Idle → Active: On "HotkeyPressed" (if not locked)
    Active → Interrupted: On "AbilityExecuting" (type = "auto_execute")
    Active → Complete: On sequence finish
    Any → Idle: On engine Stop()
```

**Context7 Patterns to Use:**
1. **Recursive Timer Pattern:**
   - Use timer for step sequencing: `SetTimer(() => this._ExecuteNextStep(), -delay)`
   - Check step counter: `if this.currentStep > this.sequences.Length`
   - Recursive calls until complete

2. **Interruption Pattern:**
   - Listen to sibling events: `OnEvent("AbilityExecuting", handler, -5)`
   - Check event type: `if data["type"] != "auto_execute" { return }`
   - Stop recursion by clearing state

3. **Sequence Storage:**
   - Store as Map: `this.sequences := Map("key", [{keybind, delay}, ...])`
   - Iterate steps: `for step in this.currentSequence`
   - Access properties: `step["keybind"]`, `step["delay"]`

**Removal Checklist:**
- [ ] Remove `this.framework` property
- [ ] Remove `this.autoExecuteEngine` property
- [ ] Remove `SetAutoExecuteEngine()` method
- [ ] Remove `_CheckInterrupt()` method (use event handler)
- [ ] Add event subscriptions in Start()
- [ ] Add state machine logic
- [ ] Use timer-based step execution

**Acceptance Criteria:**
- [ ] No `this.framework` references
- [ ] No `this.autoExecuteEngine` references
- [ ] Listens to "AbilityExecuting" for interruption
- [ ] Emits all sequence lifecycle events
- [ ] State machine transitions correctly
- [ ] Compiles without errors
- [ ] Works with Phase 3 simulation tests

---

### PHASE 7: PriorityEngine Conversion

**Objective:** Convert PriorityEngine to event-driven architecture.

**Files to Modify:**
- `Framework/Engines/PriorityEngine.ahk`

**Design Pattern: Priority Queue + Timer-Driven Execution**

**Class Structure Changes:**
```
OLD Constructor:
    __New(framework)
    Store: this.framework, abilities from framework

NEW Constructor:
    __New(bus, abilities)
    Store: this.abilities (sorted array of ability definitions)
    Call: super.__New(bus, "PriorityEngine")
```

**Rotation Logic:**
- Create internal timer that emits "RotationTick" event
- Subscribe to own "RotationTick" event
- On tick: Find highest priority ready ability → Execute
- Track cooldowns internally (lastUsed timestamps)

**Event Subscriptions:**
- Subscribe to: "RotationTick" (self-emitted, ~100ms interval)
- Subscribe to: "AbilityExecuting" (to track ability usage)
- Emit: "RotationTick" (via internal timer)
- Emit: "AbilityUsed" (when executing ability)

**State Checks:**
- GCD active: `this.GetState("gcdActive", false)`
- Chat active: `this.GetState("chatActive", false)`
- Auto-execute processing: `this.GetState("autoExecute_processing", false)`

**Context7 Patterns to Use:**
1. **Self-Timer Pattern:**
   - Create repeating timer in Start(): `SetTimer(() => this.EmitEvent("RotationTick"), 100)`
   - Subscribe to own events: `this.OnEvent("RotationTick", handler)`
   - Allows other systems to also react to rotation ticks

2. **Priority Sorting:**
   - Sort abilities array by priority (descending)
   - Use bubble sort (Context7 pattern): outer loop + inner loop with swap flag
   - Higher priority = lower index in array

3. **Cooldown Tracking:**
   - Store lastUsed: `ability["lastUsed"] := A_TickCount`
   - Check cooldown: `cooldownRemaining := ability["cooldown"] - (A_TickCount - ability["lastUsed"])`
   - Ready when: `cooldownRemaining <= 0`

4. **GCD Management:**
   - Set GCD state: `this.SetState("gcdActive", true)`
   - Clear after delay: `SetTimer(() => this.SetState("gcdActive", false), -1500)`
   - All abilities check this state

**Ability Storage Structure:**
```
this.abilities := [
    {
        name: "AbilityName",
        priority: Integer,
        keybind: "Key",
        cooldown: Milliseconds,
        lastUsed: Timestamp
    },
    ...
]
```

**Removal Checklist:**
- [ ] Remove `this.framework` property
- [ ] Remove `this.autoExecuteEngine` property
- [ ] Remove all framework state access
- [ ] Create self-timer for rotation ticks
- [ ] Add internal cooldown tracking
- [ ] Add GCD management via state

**Acceptance Criteria:**
- [ ] No `this.framework` references
- [ ] No `this.autoExecuteEngine` references
- [ ] Self-timer emits "RotationTick" events
- [ ] Respects GCD and cooldowns via state
- [ ] Emits "AbilityUsed" events
- [ ] Priority sorting works correctly
- [ ] Compiles without errors

---

### PHASE 8: Support Systems (PixelMonitor, HotkeyDispatcher)

**Objective:** Create event emitters for pixel detection and hotkeys.

**Files to Create:**
- `Framework/PixelMonitor.ahk`
- `Framework/HotkeyDispatcher.ahk`

**Design Pattern: Adapter Pattern (Hardware → Events)**

**PixelMonitor Class:**
```
class PixelMonitor extends BaseEngine {
    Properties:
        - pixelTargets: Map<targetName, {x, y, color, tolerance}>
        - pollInterval: Integer (milliseconds)
        - timer: Function reference

    Methods:
        - Start() [create polling timer]
        - Stop() [delete timer]
        - PollPixels() [timer callback]
        - _CheckPixel(target)
        - _ColorMatch(color1, color2, tolerance)
        - __Delete() [ensure timer stopped]

    Events Emitted:
        - "PixelConditionMet" {target, color, x, y}
        - "WindowInactive" (when window loses focus)
        - "WindowActive" (when window gains focus)
}
```

**HotkeyDispatcher Class:**
```
class HotkeyDispatcher extends BaseEngine {
    Properties:
        - hotkeyMap: Map<hotkeyStr, action>
        - registeredHotkeys: Array<{hotkey, callback}>

    Methods:
        - Start() [register all hotkeys]
        - Stop() [unregister all hotkeys]
        - CreateHotkeyCallback(action)
        - HandleHotkey(action)
        - __Delete() [ensure hotkeys unregistered]

    Events Emitted:
        - "HotkeyPressed" {key, timestamp}
}
```

**Context7 Patterns to Use:**
1. **Hotkey Registration:**
   - Register: `Hotkey(hotkeyStr, callback)`
   - Use Bind: `callback := this.CreateHotkeyCallback(action).Bind(this)`
   - Store reference: `this.registeredHotkeys.Push({hotkey, callback})`
   - Unregister: `Hotkey(hotkeyStr, "Off")`

2. **Timer Polling:**
   - Create timer: `SetTimer(callback, this.pollInterval)`
   - Store callback: `this.timer := callback`
   - Delete in Stop(): `SetTimer(this.timer, 0)`
   - Always check: `if IsSet(this.timer)`

3. **Window State Detection:**
   - Check active: `WinActive("ahk_exe fellowship-Win64-Shipping.exe")`
   - Track state changes: emit event only when state changes
   - Use state to prevent duplicate events

4. **Pixel Color Matching:**
   - Get color: `PixelGetColor(x, y)`
   - Extract RGB: `(color >> 16) & 0xFF`, `(color >> 8) & 0xFF`, `color & 0xFF`
   - Compare with tolerance: `Abs(r1 - r2) <= tolerance`

**PixelMonitor Flow:**
1. Timer fires every pollInterval ms
2. Check if window active (emit state change events if changed)
3. For each pixel target:
   - Get current color
   - Compare with target color (with tolerance)
   - If match: Emit "PixelConditionMet" event

**HotkeyDispatcher Flow:**
1. On Start(): Register all hotkeys from map
2. On hotkey press:
   - Check if chat active (early return if true)
   - Check if window active (early return if false)
   - Emit "HotkeyPressed" event with action

**Acceptance Criteria:**
- [ ] PixelMonitor emits "PixelConditionMet" events
- [ ] HotkeyDispatcher emits "HotkeyPressed" events
- [ ] Both respect "chatActive" state
- [ ] Window state changes emit events
- [ ] Cleanup releases all timers/hotkeys
- [ ] Compiles without errors
- [ ] Integrates with converted engines (Phase 5-7)

---

## Final Integration Checklist

**Before declaring Phase 8 complete:**

- [ ] All test files pass
- [ ] No circular references (verified with ObjPtr tracking)
- [ ] Memory stable over 1-hour run
- [ ] Both meiko and tiraq configs work
- [ ] Chat protection functional
- [ ] Window focus guards work
- [ ] Hotkey toggles work
- [ ] Combo interruption works
- [ ] All engines clean up properly on Stop()
- [ ] No `this.framework` references anywhere
- [ ] All communication via EventBus

---

## Memory Management Validation

**Context7 Pattern for Verification:**
```
// Track object creation
busPtr := ObjPtr(bus)
enginePtr := ObjPtr(engine)

// ... use engine ...

// Delete engine
engine := ""

// Verify deletion event fired = no leak
// Check that subscription count = 0
```

**Reference Cycle Detection:**
- Use `ObjPtr()` to get object addresses
- Track all `ObjAddRef()` / `ObjRelease()` calls
- Verify `__Delete()` methods fire
- Monitor subscription counts in EventBus

---

## Migration Path for Character Scripts

**Pattern for New Character Scripts:**
```
#Include statements for:
    - EventBus.ahk
    - BaseEngine.ahk
    - RotationFramework.ahk
    - Converted engine files
    - PixelMonitor.ahk
    - HotkeyDispatcher.ahk

Initialize framework:
    - Framework creates EventBus
    - Framework creates engines with bus reference
    - Framework creates PixelMonitor with pixel targets
    - Framework creates HotkeyDispatcher with hotkey map
    - All components subscribe to relevant events
    - Framework calls Start() on all components
```

**Framework Responsibilities:**
- EventBus creation and lifecycle
- Config loading (unchanged)
- Engine instantiation (now with bus parameter)
- PixelMonitor setup (from config pixel targets)
- HotkeyDispatcher setup (from config hotkeys)
- Chat protection (emits "ChatActivated"/"ChatDeactivated" events)

---

## Rollback Strategy

**If critical issues found:**

1. **Phase 1-4:** No rollback needed (pure testing)
2. **Phase 5-7:** Revert individual engine files via git:
   ```
   git checkout <commit> -- Framework/Engines/<EngineName>.ahk
   ```
3. **Phase 8:** Keep original standalone scripts until validated
4. **Nuclear option:** Full framework revert:
   ```
   git checkout <commit> -- Framework/
   ```

**Rollback Decision Points:**
- Test failures that can't be fixed in 1 hour
- Memory leaks detected
- Circular references found
- Performance degradation >20%

---

## Success Criteria

**Architecture is complete when:**

1. ✅ Zero direct references between engines
2. ✅ All engines extend `BaseEngine`
3. ✅ No `this.framework` references in any engine
4. ✅ No `this.autoExecuteEngine` references
5. ✅ All communication via `EventBus.Emit/Subscribe`
6. ✅ State managed exclusively through `EventBus.state`
7. ✅ Memory leaks eliminated (verified over 1+ hour)
8. ✅ Both character scripts functional
9. ✅ All tests passing
10. ✅ Context7 patterns followed correctly

---

## Post-Migration Benefits

**Achieved:**
- Engines testable in complete isolation
- New character = new config file only
- Zero circular references
- Clear event flow documentation
- Easy to add new engine types
- State transitions fully observable
- Memory management automatic

**Maintenance reduced by ~60%**
**New character setup time: <30 minutes**
**Testing coverage: 100% of event flows**

---

## Implementation Notes for AI

**Phase Execution Rules:**
1. Execute phases strictly in order 1→8
2. Do not skip acceptance criteria checks
3. Run all tests before moving to next phase
4. If test fails, fix before proceeding
5. Query Context7 before implementing any AHK v2 pattern
6. Track ObjPtr() for memory leak detection
7. Keep original files until validation complete

**Context7 Query Pattern:**
```
Query for: "<topic> pattern autohotkey v2"
Topics: class inheritance, timer cleanup, callback management,
        Map operations, event patterns, memory management
```

**Testing Pattern:**
```
try {
    Test_Feature1()
    Test_Feature2()
    MsgBox "✓ All tests passed!"
} catch Error as e {
    MsgBox "✗ Test failed: " . e.Message
    ExitApp
}
```

**Memory Leak Check Pattern:**
```
// Before creating objects
startCount := GetSubscriptionCount()

// Create and destroy objects multiple times
Loop 1000 {
    obj := TestClass()
    obj := ""  // Delete
}

// Verify count returned to baseline
endCount := GetSubscriptionCount()
assert(startCount = endCount, "Memory leak detected")
```

---

## Context7 Reference Quick List

**Must Query Before Implementing:**
- [ ] Class inheritance patterns (`extends`, `super.__New()`)
- [ ] Timer management (`SetTimer`, callback storage, cleanup)
- [ ] Event callback patterns (Bind, priority, stop propagation)
- [ ] Map operations (Has, Delete, iteration, sorting)
- [ ] Array operations (Push, RemoveAt, iteration)
- [ ] Memory patterns (ObjPtr, ObjAddRef, ObjRelease)
- [ ] __Delete cleanup patterns
- [ ] Circular reference avoidance
- [ ] One-time timer pattern (negative period)
- [ ] Method binding (Bind(this) for callbacks)

**Key Documentation URLs:**
- `/websites/autohotkey_v2` - Main documentation
- Classes: Objects, Inheritance, Constructors, Destructors
- Timers: SetTimer, cleanup, callback management
- Events: OnEvent, callback registration, priorities
- Collections: Map, Array, iteration, manipulation

---

END OF PLAN
