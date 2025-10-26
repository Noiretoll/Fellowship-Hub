# Meiko Framework Script - Testing Guide

**Date:** 2025-10-25
**Status:** Post-Phase 8 Integration Testing
**Script:** `Characters/meiko_framework.ahk`

---

## Overview

This guide provides instructions for testing the new Meiko framework script built using the event-driven architecture (Phases 1-8 complete). The script implements the two-layer pattern:

- **Layer 1 (Framework):** Generic, reusable engines (EventBus, PixelMonitor, SequenceEngine, HotkeyDispatcher)
- **Layer 2 (Character):** Meiko-specific configuration (pixel coords, combo sequences, finisher callback, hotkey mappings)

---

## Testing Phases

### Phase 1: Unit Tests (Integration_Test_Meiko.ahk)

Run automated integration tests to validate framework components and event flows **before** launching the game.

**Location:** `Framework/Tests/Integration_Test_Meiko.ahk`

**How to Run:**

1. Double-click `Integration_Test_Meiko.ahk` **OR** run via command line:
   ```bash
   "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "D:\Games\Fellowship\Fellowship-Hub\Framework\Tests\Integration_Test_Meiko.ahk"
   ```

2. Test GUI window will open with real-time test output

3. Tests run automatically after 500ms delay

4. Press **F10** to exit when tests complete

**Expected Results:**

All 15 tests should **PASS**:

1. ✓ EventBus initialization
2. ✓ PixelMonitor configuration
3. ✓ SequenceEngine combo configuration (all 6 combos with finisher callbacks)
4. ✓ HotkeyDispatcher hotkey mapping
5. ✓ Event flow - HotkeyPressed to combo execution
6. ✓ State management - chatActive
7. ✓ State management - windowActive
8. ✓ State management - pixel states
9. ✓ SequenceEngine respects chatActive state
10. ✓ Multiple Start/Stop cycles
11. ✓ Engine cleanup (timer removal)
12. ✓ EventBus subscription/unsubscription
13. ✓ SequenceEngine immediate restart pattern
14. ✓ Finisher callback integration (10ms delay after combo)
15. ✓ Finisher pixel state checking

**If Any Tests Fail:**

- Review error messages in test output
- Check file paths in `#Include` statements
- Verify all Phase 1-8 framework files exist
- Do NOT proceed to Phase 2 until all tests pass

---

### Phase 2: Manual Script Testing (No Game Required)

Test script startup, toggle functionality, and cleanup **without** the game running.

**Location:** `Characters/meiko_framework.ahk`

**How to Run:**

1. Double-click `meiko_framework.ahk` **OR** run via command line:
   ```bash
   "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "D:\Games\Fellowship\Fellowship-Hub\Characters\meiko_framework.ahk"
   ```

2. Script starts automatically with tooltip: "Meiko Script Started..."

**Tests to Perform:**

#### Test 2.1: Script Startup
- **Expected:** Tooltip appears: "Meiko Script Started | Alt+F1: Toggle Auto-Combo | F10: Exit"
- **Expected:** No error messages or crashes
- **Result:** ☐ PASS / ☐ FAIL

#### Test 2.2: Toggle Auto-Combo (Alt+F1)
- **Action:** Press **Alt+F1**
- **Expected:** Tooltip shows "Auto-Combo: ON" (default is OFF)
- **Action:** Press **Alt+F1** again
- **Expected:** Tooltip shows "Auto-Combo: OFF"
- **Result:** ☐ PASS / ☐ FAIL

#### Test 2.3: Chat Mode (Enter Key)
- **Action:** Press **Enter**
- **Expected:** Tooltip shows "Chat Mode: ON"
- **Expected:** Enter key still registers (passthrough)
- **Action:** Press **Enter** again
- **Expected:** Tooltip shows "Chat Mode: OFF"
- **Result:** ☐ PASS / ☐ FAIL

#### Test 2.4: Chat Mode (Slash Key)
- **Action:** Press **/**
- **Expected:** Tooltip shows "Chat Mode: ON"
- **Expected:** Slash key still registers (passthrough)
- **Result:** ☐ PASS / ☐ FAIL

#### Test 2.5: Chat Cancel (Escape)
- **Action:** Press **Enter** to activate chat
- **Action:** Press **Escape**
- **Expected:** Tooltip shows "Chat Cancelled"
- **Expected:** Chat mode deactivated
- **Result:** ☐ PASS / ☐ FAIL

#### Test 2.6: Clean Exit (F10)
- **Action:** Press **F10**
- **Expected:** Tooltip shows "Shutting down Meiko script..."
- **Expected:** Script exits cleanly after 1 second
- **Expected:** No AHK processes remain (check Task Manager)
- **Result:** ☐ PASS / ☐ FAIL

**If Any Tests Fail:**

- Check AHK v2 installation (must be v2.0+)
- Review script error messages (right-click AHK tray icon → "View Errors")
- Verify hotkey conflicts with other running scripts
- Do NOT proceed to Phase 3 until all manual tests pass (6 tests)

---

### Phase 3: In-Game Integration Testing

Test actual gameplay integration with Fellowship client.

**Prerequisites:**

- ✅ Phase 1 tests passed (all 15 tests)
- ✅ Phase 2 tests passed (all 6 manual tests)
- ✅ Fellowship client installed
- ✅ Meiko character logged in
- ✅ Game settings configured:
  - Resolution: 2560x1440
  - Window Mode: Borderless
  - Resolution Scale: 100%

**How to Run:**

1. Launch Fellowship and log in with Meiko character
2. Run `Characters/meiko_framework.ahk`
3. Ensure game window is active

**Tests to Perform:**

#### Test 3.1: Finisher Integration (Post-Combo Callback)
- **Setup:** Enable auto-combo with **Alt+F1**
- **Action:** Execute combo sequence (e.g., press **3**)
- **Expected:** Combo executes (3 → 1), waits 10ms after completion
- **Expected:** If finisher is ready (bright icon), finisher key (backtick) fires automatically
- **Expected:** Finisher only fires AFTER combo completes, not during
- **Note:** Finisher pixel at (1205, 1119) must match your display
- **Result:** ☐ PASS / ☐ FAIL / ☐ NEEDS CALIBRATION

**If Finisher Doesn't Trigger:**

Pixel coordinates need calibration:

1. Press **F10** to exit script
2. Open **AutoHotkey Window Spy** (search Windows Start menu)
3. Position mouse over finisher icon when it's **inactive** (dark/grayed out)
4. Note the **X, Y coordinates** and **Color** value
5. Edit `Characters/meiko_framework.ahk` line 77-81:
   ```ahk
   pixelTargets["Finisher"] := Map(
       "x", 1205,              ; ← Update X coordinate
       "y", 1119,              ; ← Update Y coordinate
       "activeColor", 0xFFFFFF, ; ← Leave as is (inverted check)
       "tolerance", 10,         ; ← Increase if flaky (10-30 range)
       "invert", true           ; ← Leave as is
   )
   ```
6. Restart script and re-test

#### Test 3.2: Auto-Combo Execution
- **Setup:** Press **Alt+F1** to enable auto-combo
- **Expected:** Tooltip shows "Auto-Combo: ON"
- **Action:** Press **3** (Combo3 sequence)
- **Expected:** Script sends "3", waits 1050ms (GCD), sends "1"
- **Expected:** Combo executes in-game
- **Result:** ☐ PASS / ☐ FAIL

#### Test 3.3: All Combo Sequences
Test each combo hotkey:

| Hotkey | Sequence | Result |
|--------|----------|--------|
| **3**  | 3 → 1    | ☐ PASS / ☐ FAIL |
| **Alt+3** | 3 → 2 | ☐ PASS / ☐ FAIL |
| **1**  | 1 → 2    | ☐ PASS / ☐ FAIL |
| **Alt+1** | 1 → 3 | ☐ PASS / ☐ FAIL |
| **2**  | 2 → 1    | ☐ PASS / ☐ FAIL |
| **Alt+2** | 2 → 3 | ☐ PASS / ☐ FAIL |

**If Combos Desync:**

GCD delay needs adjustment:

1. Edit `Characters/meiko_framework.ahk` line 51:
   ```ahk
   gcdDelay := 1050  ; ← Adjust this value
   ```
2. Too fast = increase value (e.g., 1100)
3. Too slow = decrease value (e.g., 1000)
4. Restart script and re-test

#### Test 3.4: Chat Protection
- **Setup:** Auto-combo enabled, in combat
- **Action:** Press **Enter** to open chat
- **Expected:** Tooltip shows "Chat Mode: ON"
- **Action:** Press combo hotkey (e.g., **3**)
- **Expected:** Combo does NOT execute (chat mode blocks input)
- **Action:** Press **Enter** to close chat
- **Expected:** Combo hotkeys work again
- **Result:** ☐ PASS / ☐ FAIL

#### Test 3.5: Window Focus Protection
- **Setup:** Auto-finisher enabled, finisher ready
- **Action:** Alt+Tab to different window
- **Expected:** Finisher does NOT fire (window inactive blocks input)
- **Action:** Alt+Tab back to game
- **Expected:** Finisher fires immediately (window active again)
- **Result:** ☐ PASS / ☐ FAIL

#### Test 3.6: Finisher Post-Combo Behavior
- **Setup:** Auto-combo ON
- **Action:** Execute multiple combos in sequence
- **Action:** Build finisher meter during combat
- **Expected:** Finisher fires 10ms AFTER each combo completes (not during)
- **Expected:** Finisher does NOT interrupt combo execution
- **Note:** Finisher is integrated as post-completion callback (by design)
- **Result:** ☐ PASS / ☐ FAIL

#### Test 3.7: Immediate Combo Restart
- **Setup:** Auto-combo ON
- **Action:** Start combo **3** (3 → 1)
- **Action:** During GCD delay, press **1** (different combo)
- **Expected:** First combo interrupts, second combo starts immediately
- **Expected:** No lockout or "combo busy" behavior
- **Note:** This is intentional - user can restart combos anytime
- **Result:** ☐ PASS / ☐ FAIL

#### Test 3.8: Long-Term Stability (1 Hour)
- **Setup:** Auto-combo ON
- **Action:** Play normally for 1 hour
- **Monitor:** AHK memory usage (Task Manager)
- **Monitor:** Script responsiveness
- **Expected:** No memory leaks (usage stays constant)
- **Expected:** No lag or input delays
- **Expected:** No crashes or freezes
- **Result:** ☐ PASS / ☐ FAIL

---

## Troubleshooting

### Issue: Script Won't Start

**Symptoms:**
- Double-clicking does nothing
- Error message on startup

**Solutions:**
1. Verify AutoHotkey v2.0+ installed (not v1.1)
2. Check file paths in `#Include` statements (lines 23-28)
3. Ensure all framework files exist:
   - `Framework/EventBus.ahk`
   - `Framework/BaseEngine.ahk`
   - `Framework/PixelMonitor.ahk`
   - `Framework/HotkeyDispatcher.ahk`
   - `Framework/Engines/SequenceEngine.ahk`
4. Right-click AHK tray icon → "View Errors" for details

---

### Issue: Finisher Not Firing

**Symptoms:**
- Finisher icon lights up, but script doesn't send backtick
- Finisher fires at wrong times

**Solutions:**
1. **Calibrate pixel coordinates:**
   - Use Window Spy to get exact X, Y coordinates
   - Update line 77-78 in `meiko_framework.ahk`
2. **Adjust tolerance:**
   - Increase `"tolerance", 10` to `20` or `30` (line 80)
   - Higher tolerance = less precise, more forgiving
3. **Check invert setting:**
   - Line 81: `"invert", true` means "fire when NOT dark"
   - Should be `true` for finisher detection
4. **Verify auto-combo enabled:**
   - Press Alt+F1 to ensure auto-combo is ON
   - Finisher only fires after combos complete
   - Tooltip should confirm state

---

### Issue: Combos Desync

**Symptoms:**
- Combo steps execute too fast (overlap abilities)
- Combo steps execute too slow (miss GCD window)

**Solutions:**
1. **Adjust GCD delay:**
   - Line 51: `gcdDelay := 1050`
   - Increase if too fast: `1100` or `1150`
   - Decrease if too slow: `1000` or `950`
2. **Check game latency:**
   - High ping may require longer delays
   - Test in solo content first to isolate issue
3. **Verify window mode:**
   - Borderless window mode recommended
   - Fullscreen may cause input delays

---

### Issue: Hotkeys Don't Work

**Symptoms:**
- Pressing combo keys (3, 1, 2) does nothing
- Toggle keys (F1, Alt+F1) don't respond

**Solutions:**
1. **Check auto-combo state:**
   - Combo hotkeys only work when auto-combo is ON
   - Press **Alt+F1** to enable
   - Tooltip should say "Auto-Combo: ON"
2. **Verify window focus:**
   - Game window must be active
   - Alt+Tab to game if needed
3. **Check chat mode:**
   - Press **Escape** to cancel chat if stuck
   - Tooltip should not say "Chat Mode: ON"
4. **Hotkey conflicts:**
   - Close other AHK scripts
   - Check for game macro conflicts

---

### Issue: Chat Protection Not Working

**Symptoms:**
- Combos execute while typing in chat
- Enter/Escape keys don't toggle chat mode

**Solutions:**
1. **Verify passthrough hotkeys:**
   - Lines 192-206 register `$Enter`, `$/`, `$Escape`
   - `$` prefix creates non-blocking hotkeys
2. **Check state management:**
   - Line 282: `bus.SetState("chatActive", true)`
   - Engines check this state before execution
3. **Test without game:**
   - Run script outside game
   - Press Enter, watch for "Chat Mode: ON" tooltip
   - If tooltip doesn't appear, hotkey registration failed

---

### Issue: Memory Leaks / Performance Degradation

**Symptoms:**
- AHK memory usage grows over time
- Script becomes slow or unresponsive
- Game FPS drops

**Solutions:**
1. **Check Task Manager:**
   - Monitor "AutoHotkey64.exe" memory
   - Should stay < 50 MB
   - If growing, there's a timer leak
2. **Restart script periodically:**
   - Press **F10** to exit cleanly
   - Restart script every few hours
3. **Report issue:**
   - Note memory usage pattern
   - Check for events that trigger growth
   - Review Phase 8 timer cleanup patterns

---

## Success Criteria

Script is **READY FOR PRODUCTION** when:

- ✅ All Phase 1 integration tests pass (15/15)
- ✅ All Phase 2 manual tests pass (6/6)
- ✅ All Phase 3 in-game tests pass (8/8)
- ✅ Finisher fires after combos reliably (Test 3.1)
- ✅ All combos execute correctly (Test 3.3)
- ✅ Chat protection works (Test 3.4)
- ✅ Window focus protection works (Test 3.5)
- ✅ Finisher post-combo behavior correct (Test 3.6)
- ✅ No memory leaks over 1 hour (Test 3.8)

---

## Next Steps After Testing

### If All Tests Pass:

1. **Archive old script:**
   - Rename `Characters/meiko_v2.ahk` to `Characters/meiko_v2_OLD.ahk`
   - Keep as backup/reference

2. **Update documentation:**
   - Mark `Characters/meiko_framework.ahk` as production script in `CLAUDE.md`
   - Update architecture plan with final status

3. **Create Tiraq framework script:**
   - Follow same two-layer pattern
   - Use PriorityEngine instead of SequenceEngine
   - Reference Meiko implementation as template

### If Tests Fail:

1. **Document failures:**
   - Note which tests failed
   - Capture error messages
   - Record steps to reproduce

2. **Review architecture plan:**
   - Check Phase 1-8 lessons learned
   - Verify Context7 patterns followed
   - Review `unset` usage (common crash source)

3. **Debug systematically:**
   - Use `.claude/agents/debugger.md` procedures
   - Add `[DEBUGGER:location:line]` prefixes
   - Create isolated test files for suspect behavior

4. **Do NOT use in production:**
   - Stick with `meiko_v2.ahk` until framework is stable
   - Framework is research/experimental until validated

---

## File Locations Reference

```
Fellowship-Hub/
├── Characters/
│   ├── meiko_framework.ahk         ← Event-driven script (production)
│   ├── meiko_v2.ahk                ← Standalone script (backup)
│   └── tiraq.ahk                   ← Standalone Tiraq script (backup)
│
├── Framework/
│   ├── EventBus.ahk                ← Central event hub
│   ├── BaseEngine.ahk              ← Abstract engine class
│   ├── PixelMonitor.ahk            ← Pixel detection system
│   ├── HotkeyDispatcher.ahk        ← Hotkey registration system
│   ├── Engines/
│   │   ├── SequenceEngine.ahk      ← Combo sequences with finisher callbacks
│   │   └── PriorityEngine.ahk      ← Priority rotation (future use - Tiraq)
│   └── Tests/
│       ├── Integration_Test_Meiko.ahk           ← 15 integration tests
│       ├── Integration_Test_Meiko_Finisher.ahk  ← 10 finisher tests
│       └── MEIKO_TESTING_GUIDE.md               ← This file
│
├── CLAUDE.md                        ← Project documentation
└── SYSTEM_DESIGN.md                 ← Architecture documentation
```

---

## Support

For issues, questions, or bug reports:

1. Review this testing guide thoroughly
2. Check `SYSTEM_DESIGN.md` for architecture details
3. Review integration test files for component behavior
4. Create isolated test files to reproduce issues
5. Document findings for future debugging

---

**END OF TESTING GUIDE**
