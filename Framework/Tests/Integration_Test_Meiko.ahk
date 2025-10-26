; Integration_Test_Meiko.ahk
; Integration tests for Meiko character script using event-driven framework
;
; Purpose: Validate framework components, event flows, and character script integration
; DO NOT EXECUTE: Manual test file for user validation
;
; Test Coverage:
;   1. Component initialization (EventBus, PixelMonitor, Engines)
;   2. Pixel target configuration validation
;   3. AutoExecuteEngine finisher configuration
;   4. SequenceEngine combo configuration (all 6 combos)
;   5. HotkeyDispatcher hotkey mapping
;   6. Event flow: HotkeyPressed → HandleComboHotkey → ExecuteSequence
;   7. Toggle functionality (finisher, auto-combo, chat)
;   8. State management (chatActive, windowActive, pixel states)
;   9. Cleanup and resource management

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Include framework components
#Include ..\EventBus.ahk
#Include ..\BaseEngine.ahk
#Include ..\PixelMonitor.ahk
#Include ..\HotkeyDispatcher.ahk
#Include ..\Engines\AutoExecuteEngine.ahk
#Include ..\Engines\SequenceEngine.ahk

; ===== TEST STATE =====
testsPassed := 0
testsFailed := 0
testLog := []

; ===== GUI SETUP =====
testGui := Gui("+AlwaysOnTop", "Meiko Integration Tests")
testGui.SetFont("s10", "Consolas")
outputBox := testGui.Add("Edit", "r35 w900 ReadOnly -Wrap HScroll VScroll")
testGui.Show()

; ===== LOGGING FUNCTIONS =====
LogTest(message) {
    global testLog, outputBox
    timestamp := FormatTime(A_Now, "HH:mm:ss")
    testLog.Push(timestamp . " | " . message)
    outputBox.Value := ""
    for line in testLog {
        outputBox.Value .= line . "`n"
    }
    ; Scroll to bottom
    SendMessage(0x115, 7, 0, outputBox)
}

PassTest(testName) {
    global testsPassed
    testsPassed++
    LogTest("✓ PASS: " . testName)
}

FailTest(testName, reason) {
    global testsFailed
    testsFailed++
    LogTest("✗ FAIL: " . testName . " - " . reason)
}

; ===== TEST SUITE =====
RunAllTests() {
    LogTest("=== MEIKO INTEGRATION TEST SUITE ===")
    LogTest("")

    ; Test 1: EventBus Initialization
    try {
        LogTest("Test 1: EventBus initialization...")
        bus := EventBus()

        if !IsObject(bus) {
            FailTest("EventBus initialization", "Bus is not an object")
        } else if !bus.HasOwnProp("state") {
            FailTest("EventBus initialization", "Bus missing state property")
        } else {
            PassTest("EventBus initialization")
        }
    } catch Error as e {
        FailTest("EventBus initialization", e.Message)
    }

    ; Test 2: PixelMonitor Configuration
    try {
        LogTest("Test 2: PixelMonitor configuration...")
        bus := EventBus()

        ; Define pixel targets (same as Meiko script)
        pixelTargets := Map()
        pixelTargets["Finisher"] := Map(
            "x", 1205,
            "y", 1119,
            "activeColor", 0xFFFFFF,
            "tolerance", 10,
            "invert", true
        )

        monitor := PixelMonitor(bus, pixelTargets, "fellowship-Win64-Shipping.exe", 50)

        if !IsObject(monitor) {
            FailTest("PixelMonitor configuration", "Monitor not created")
        } else if monitor.pixelTargets.Count != 1 {
            FailTest("PixelMonitor configuration", "Expected 1 pixel target, got " . monitor.pixelTargets.Count)
        } else if !monitor.pixelTargets.Has("Finisher") {
            FailTest("PixelMonitor configuration", "Finisher pixel target not found")
        } else {
            PassTest("PixelMonitor configuration")
        }

        monitor.Stop()
    } catch Error as e {
        FailTest("PixelMonitor configuration", e.Message)
    }

    ; Test 3: AutoExecuteEngine Finisher Configuration
    try {
        LogTest("Test 3: AutoExecuteEngine finisher configuration...")
        bus := EventBus()

        finisherEngine := AutoExecuteEngine(
            bus,
            "MeikoFinisher",
            "Finisher",
            "``",
            50,
            100
        )

        if !IsObject(finisherEngine) {
            FailTest("AutoExecuteEngine finisher config", "Engine not created")
        } else if finisherEngine.name != "MeikoFinisher" {
            FailTest("AutoExecuteEngine finisher config", "Expected name 'MeikoFinisher', got '" . finisherEngine.name . "'")
        } else if finisherEngine.pixelTarget != "Finisher" {
            FailTest("AutoExecuteEngine finisher config", "Expected pixelTarget 'Finisher', got '" . finisherEngine.pixelTarget . "'")
        } else if finisherEngine.action != "``" {
            FailTest("AutoExecuteEngine finisher config", "Expected action '``', got '" . finisherEngine.action . "'")
        } else {
            PassTest("AutoExecuteEngine finisher config")
        }

        finisherEngine.Stop()
    } catch Error as e {
        FailTest("AutoExecuteEngine finisher config", e.Message)
    }

    ; Test 4: SequenceEngine Combo Configuration
    try {
        LogTest("Test 4: SequenceEngine combo configuration (all 6 combos)...")
        bus := EventBus()

        ; Define all 6 combos
        combos := Map(
            "Combo3", [
                {key: "3", delay: 1050},
                {key: "1", delay: 0}
            ],
            "Combo3Alt", [
                {key: "3", delay: 1050},
                {key: "2", delay: 0}
            ],
            "Combo1", [
                {key: "1", delay: 1050},
                {key: "2", delay: 0}
            ],
            "Combo1Alt", [
                {key: "1", delay: 1050},
                {key: "3", delay: 0}
            ],
            "Combo2", [
                {key: "2", delay: 1050},
                {key: "1", delay: 0}
            ],
            "Combo2Alt", [
                {key: "2", delay: 1050},
                {key: "3", delay: 0}
            ]
        )

        comboEngines := Map()
        allPassed := true
        failReason := ""

        for comboName, steps in combos {
            engine := SequenceEngine(bus, "Meiko" . comboName, steps)

            if !IsObject(engine) {
                allPassed := false
                failReason := "Failed to create " . comboName . " engine"
                break
            }

            if engine.steps.Length != 2 {
                allPassed := false
                failReason := comboName . " has " . engine.steps.Length . " steps, expected 2"
                break
            }

            comboEngines[comboName] := engine
        }

        if !allPassed {
            FailTest("SequenceEngine combo config", failReason)
        } else if comboEngines.Count != 6 {
            FailTest("SequenceEngine combo config", "Expected 6 combos, got " . comboEngines.Count)
        } else {
            PassTest("SequenceEngine combo config")
        }

        ; Cleanup
        for comboName, engine in comboEngines {
            engine.Stop()
        }
    } catch Error as e {
        FailTest("SequenceEngine combo config", e.Message)
    }

    ; Test 5: HotkeyDispatcher Hotkey Mapping
    try {
        LogTest("Test 5: HotkeyDispatcher hotkey mapping...")
        bus := EventBus()

        hotkeyMap := Map(
            "3", "Combo3",
            "!3", "Combo3Alt",
            "1", "Combo1",
            "!1", "Combo1Alt",
            "2", "Combo2",
            "!2", "Combo2Alt"
        )

        dispatcher := HotkeyDispatcher(bus, hotkeyMap, "fellowship-Win64-Shipping.exe")

        if !IsObject(dispatcher) {
            FailTest("HotkeyDispatcher hotkey mapping", "Dispatcher not created")
        } else if dispatcher.hotkeyMap.Count != 6 {
            FailTest("HotkeyDispatcher hotkey mapping", "Expected 6 hotkeys, got " . dispatcher.hotkeyMap.Count)
        } else {
            PassTest("HotkeyDispatcher hotkey mapping")
        }

        dispatcher.Stop()
    } catch Error as e {
        FailTest("HotkeyDispatcher hotkey mapping", e.Message)
    }

    ; Test 6: Event Flow - HotkeyPressed → HandleComboHotkey
    try {
        LogTest("Test 6: Event flow - HotkeyPressed to combo execution...")
        bus := EventBus()

        ; Track events
        hotkeyEventReceived := false
        sequenceEventReceived := false

        ; Subscribe to events with regular functions (fat arrows don't capture outer scope)
        hotkeyHandler(data := unset) {
            hotkeyEventReceived := true
        }
        bus.Subscribe("HotkeyPressed", hotkeyHandler)

        sequenceHandler(data := unset) {
            sequenceEventReceived := true
        }
        bus.Subscribe("SequenceStarted", sequenceHandler)

        ; Create combo engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps)
        engine.Start()

        ; Emit HotkeyPressed event
        bus.Emit("HotkeyPressed", {key: "1", action: "Combo1", timestamp: A_TickCount})

        ; Wait for event processing
        Sleep 50

        ; Manually trigger sequence (simulating HandleComboHotkey)
        engine.ExecuteSequence()

        ; Wait for sequence to start
        Sleep 50

        if !hotkeyEventReceived {
            FailTest("Event flow", "HotkeyPressed event not received")
        } else if !sequenceEventReceived {
            FailTest("Event flow", "SequenceStarted event not received")
        } else {
            PassTest("Event flow")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Event flow", e.Message)
    }

    ; Test 7: State Management - chatActive
    try {
        LogTest("Test 7: State management - chatActive...")
        bus := EventBus()

        ; Set chatActive state
        bus.SetState("chatActive", true)

        if bus.GetState("chatActive", false) != true {
            FailTest("State management - chatActive", "State not set correctly")
        } else {
            ; Change to false
            bus.SetState("chatActive", false)

            if bus.GetState("chatActive", true) != false {
                FailTest("State management - chatActive", "State not updated correctly")
            } else {
                PassTest("State management - chatActive")
            }
        }
    } catch Error as e {
        FailTest("State management - chatActive", e.Message)
    }

    ; Test 8: State Management - windowActive
    try {
        LogTest("Test 8: State management - windowActive...")
        bus := EventBus()

        ; Set windowActive state
        bus.SetState("windowActive", true)

        if bus.GetState("windowActive", false) != true {
            FailTest("State management - windowActive", "State not set correctly")
        } else {
            PassTest("State management - windowActive")
        }
    } catch Error as e {
        FailTest("State management - windowActive", e.Message)
    }

    ; Test 9: State Management - pixel states
    try {
        LogTest("Test 9: State management - pixel states...")
        bus := EventBus()

        ; Set pixel state
        bus.SetState("pixel_Finisher", true)

        if bus.GetState("pixel_Finisher", false) != true {
            FailTest("State management - pixel states", "State not set correctly")
        } else {
            bus.SetState("pixel_Finisher", false)

            if bus.GetState("pixel_Finisher", true) != false {
                FailTest("State management - pixel states", "State not updated correctly")
            } else {
                PassTest("State management - pixel states")
            }
        }
    } catch Error as e {
        FailTest("State management - pixel states", e.Message)
    }

    ; Test 10: AutoExecuteEngine respects chatActive state
    try {
        LogTest("Test 10: AutoExecuteEngine respects chatActive state...")
        bus := EventBus()

        ; Set chatActive state
        bus.SetState("chatActive", true)
        bus.SetState("windowActive", true)
        bus.SetState("pixel_Finisher", true)

        ; Create engine
        engine := AutoExecuteEngine(bus, "TestFinisher", "Finisher", "``", 50, 100)
        engine.Start()

        ; Track execution
        executionCount := 0
        executionHandler(data := unset) {
            executionCount++
        }
        bus.Subscribe("ActionExecuted", executionHandler)

        ; Trigger monitor loop manually
        engine.MonitorLoop()

        ; Wait for potential execution
        Sleep 50

        if executionCount > 0 {
            FailTest("AutoExecuteEngine chatActive protection", "Engine executed while chat active")
        } else {
            PassTest("AutoExecuteEngine chatActive protection")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("AutoExecuteEngine chatActive protection", e.Message)
    }

    ; Test 11: SequenceEngine respects chatActive state
    try {
        LogTest("Test 11: SequenceEngine respects chatActive state...")
        bus := EventBus()

        ; Set chatActive state
        bus.SetState("chatActive", true)
        bus.SetState("windowActive", true)

        ; Create engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps)
        engine.Start()

        ; Track sequence start
        sequenceStarted := false
        sequenceStartHandler(data := unset) {
            sequenceStarted := true
        }
        bus.Subscribe("SequenceStarted", sequenceStartHandler)

        ; Try to execute sequence
        engine.ExecuteSequence()

        ; Wait for potential start
        Sleep 50

        if sequenceStarted {
            FailTest("SequenceEngine chatActive protection", "Sequence started while chat active")
        } else {
            PassTest("SequenceEngine chatActive protection")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("SequenceEngine chatActive protection", e.Message)
    }

    ; Test 12: Multiple Start/Stop Cycles
    try {
        LogTest("Test 12: Multiple Start/Stop cycles...")
        bus := EventBus()

        engine := AutoExecuteEngine(bus, "CycleTest", "TestPixel", "1", 50, 100)

        ; Cycle 1
        engine.Start()
        engine.Stop()

        ; Cycle 2
        engine.Start()
        engine.Stop()

        ; Cycle 3
        engine.Start()
        engine.Stop()

        PassTest("Multiple Start/Stop cycles")
    } catch Error as e {
        FailTest("Multiple Start/Stop cycles", e.Message)
    }

    ; Test 13: Engine Cleanup
    try {
        LogTest("Test 13: Engine cleanup (timer removal)...")
        bus := EventBus()

        engine := AutoExecuteEngine(bus, "CleanupTest", "TestPixel", "1", 50, 100)
        engine.Start()

        ; Verify timer property exists
        if !engine.HasProp("timer") {
            FailTest("Engine cleanup", "Timer property not created on Start")
        } else {
            engine.Stop()

            ; Verify timer property removed
            if engine.HasProp("timer") {
                FailTest("Engine cleanup", "Timer property not removed on Stop")
            } else {
                PassTest("Engine cleanup")
            }
        }
    } catch Error as e {
        FailTest("Engine cleanup", e.Message)
    }

    ; Test 14: EventBus Subscription/Unsubscription
    try {
        LogTest("Test 14: EventBus subscription/unsubscription...")
        bus := EventBus()

        eventCount := 0
        handler(data := unset) {
            eventCount++
        }

        ; Subscribe
        bus.Subscribe("TestEvent", handler)

        ; Emit event
        bus.Emit("TestEvent")

        if eventCount != 1 {
            FailTest("EventBus subscription", "Event not received, count: " . eventCount)
        } else {
            ; Unsubscribe
            bus.Unsubscribe("TestEvent", handler)

            ; Emit again
            bus.Emit("TestEvent")

            if eventCount != 1 {
                FailTest("EventBus unsubscription", "Event still received after unsubscribe, count: " . eventCount)
            } else {
                PassTest("EventBus subscription/unsubscription")
            }
        }
    } catch Error as e {
        FailTest("EventBus subscription/unsubscription", e.Message)
    }

    ; Test 15: SequenceEngine Immediate Restart Pattern
    try {
        LogTest("Test 15: SequenceEngine immediate restart pattern...")
        bus := EventBus()

        steps := [{key: "1", delay: 100}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "RestartTest", steps)
        engine.Start()

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Track interruption
        interruptCount := 0
        interruptHandler(data := unset) {
            interruptCount++
        }
        bus.Subscribe("SequenceInterrupted", interruptHandler)

        ; Start first sequence
        engine.ExecuteSequence()

        ; Wait a bit
        Sleep 20

        ; Start second sequence (should interrupt first)
        engine.ExecuteSequence()

        ; Wait for completion
        Sleep 150

        if interruptCount != 1 {
            FailTest("SequenceEngine immediate restart", "Expected 1 interruption, got " . interruptCount)
        } else {
            PassTest("SequenceEngine immediate restart")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("SequenceEngine immediate restart", e.Message)
    }

    ; ===== SUMMARY =====
    LogTest("")
    LogTest("=== TEST SUMMARY ===")
    LogTest("Total Tests: " . (testsPassed + testsFailed))
    LogTest("Passed: " . testsPassed)
    LogTest("Failed: " . testsFailed)

    if testsFailed = 0 {
        LogTest("")
        LogTest("✓ ALL TESTS PASSED!")
        LogTest("Meiko framework integration is ready for manual testing in-game.")
    } else {
        LogTest("")
        LogTest("✗ SOME TESTS FAILED")
        LogTest("Review failures above and fix issues before proceeding.")
    }

    LogTest("")
    LogTest("Press F10 to exit test suite.")
}

; ===== RUN TESTS =====
SetTimer () => RunAllTests(), -500

; ===== EXIT HOTKEY =====
F10:: {
    ExitApp
}

; Keep script running
return
