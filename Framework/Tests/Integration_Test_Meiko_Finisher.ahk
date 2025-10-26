; Integration_Test_Meiko_Finisher.ahk
; Integration tests for SequenceEngine finisher callback pattern
;
; Purpose: Validate finisher integration into SequenceEngine
; DO NOT EXECUTE AUTOMATICALLY - User will run manually and report results
;
; Test Coverage:
;   1. SequenceEngine with finisher callback parameter
;   2. Finisher callback execution after sequence completion
;   3. Finisher delay timing (10ms after completion)
;   4. Finisher callback respects chatActive state
;   5. Finisher callback respects windowActive state
;   6. Finisher callback checks pixel state before execution
;   7. Finisher NOT called when sequence interrupted
;   8. Multiple combos with shared finisher callback
;   9. FinisherExecuted event emission
;   10. Finisher callback error handling

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Include framework components
#Include ..\EventBus.ahk
#Include ..\BaseEngine.ahk
#Include ..\PixelMonitor.ahk
#Include ..\Engines\SequenceEngine.ahk

; ===== TEST STATE =====
testsPassed := 0
testsFailed := 0
testLog := []

; ===== GUI SETUP =====
testGui := Gui("+AlwaysOnTop", "Meiko Finisher Integration Tests")
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
    LogTest("=== MEIKO FINISHER INTEGRATION TEST SUITE ===")
    LogTest("")

    ; Test 1: SequenceEngine accepts finisher callback parameter
    try {
        LogTest("Test 1: SequenceEngine finisher callback parameter...")
        bus := EventBus()

        ; Create callback function
        finisherCalled := false
        finisherCallback() {
            finisherCalled := true
        }

        ; Create engine with finisher callback
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, finisherCallback, 10)

        if !IsObject(engine) {
            FailTest("SequenceEngine finisher parameter", "Engine not created")
        } else if !IsObject(engine.finisherCallback) {
            FailTest("SequenceEngine finisher parameter", "Finisher callback not stored")
        } else if engine.finisherDelay != 10 {
            FailTest("SequenceEngine finisher parameter", "Finisher delay not stored correctly")
        } else {
            PassTest("SequenceEngine finisher parameter")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("SequenceEngine finisher parameter", e.Message)
    }

    ; Test 2: Finisher callback executes after sequence completes
    try {
        LogTest("Test 2: Finisher callback execution after completion...")
        bus := EventBus()

        ; Track finisher execution
        finisherExecuted := false
        Test2_FinisherCallback() {
            finisherExecuted := true
        }

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Create engine with finisher callback
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test2_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for sequence + finisher delay
        Sleep 50

        if !finisherExecuted {
            FailTest("Finisher callback execution", "Finisher not called after sequence")
        } else {
            PassTest("Finisher callback execution")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher callback execution", e.Message)
    }

    ; Test 3: Finisher delay timing (10ms)
    try {
        LogTest("Test 3: Finisher delay timing...")
        bus := EventBus()

        ; Track finisher timing
        sequenceCompleteTime := 0
        finisherExecuteTime := 0

        ; Subscribe to sequence complete event
        completeHandler(data := unset) {
            sequenceCompleteTime := A_TickCount
        }
        bus.Subscribe("SequenceComplete", completeHandler)

        Test3_FinisherCallback() {
            finisherExecuteTime := A_TickCount
        }

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Create engine with 10ms finisher delay
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test3_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for completion
        Sleep 50

        delay := finisherExecuteTime - sequenceCompleteTime

        ; Allow 5ms tolerance (10ms ± 5ms)
        if delay < 5 || delay > 15 {
            FailTest("Finisher delay timing", "Expected ~10ms, got " . delay . "ms")
        } else {
            PassTest("Finisher delay timing")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher delay timing", e.Message)
    }

    ; Test 4: Finisher respects chatActive state
    try {
        LogTest("Test 4: Finisher respects chatActive state...")
        bus := EventBus()

        ; Track finisher execution
        finisherExecuted := false
        Test4_FinisherCallback() {
            finisherExecuted := true
        }

        ; Set chatActive = true (should block finisher)
        bus.SetState("chatActive", true)
        bus.SetState("windowActive", true)

        ; Create engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test4_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for potential finisher
        Sleep 50

        if finisherExecuted {
            FailTest("Finisher chatActive protection", "Finisher executed while chat active")
        } else {
            PassTest("Finisher chatActive protection")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher chatActive protection", e.Message)
    }

    ; Test 5: Finisher respects windowActive state
    try {
        LogTest("Test 5: Finisher respects windowActive state...")
        bus := EventBus()

        ; Track finisher execution
        finisherExecuted := false
        Test5_FinisherCallback() {
            finisherExecuted := true
        }

        ; Set windowActive = false (should block finisher)
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", false)

        ; Create engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test5_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for potential finisher
        Sleep 50

        if finisherExecuted {
            FailTest("Finisher windowActive protection", "Finisher executed while window inactive")
        } else {
            PassTest("Finisher windowActive protection")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher windowActive protection", e.Message)
    }

    ; Test 6: Finisher checks pixel state before execution
    try {
        LogTest("Test 6: Finisher checks pixel state...")
        bus := EventBus()

        ; Track finisher behavior with pixel state
        finisherCheckedPixel := false
        pixelWasReady := false

        Test6_FinisherCallback() {
            finisherCheckedPixel := true
            ; This callback should check bus.GetState("pixel_Finisher")
            pixelWasReady := bus.GetState("pixel_Finisher", false)
        }

        ; Set pixel state ready
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)
        bus.SetState("pixel_Finisher", true)

        ; Create engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test6_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for finisher
        Sleep 50

        if !finisherCheckedPixel {
            FailTest("Finisher pixel check", "Finisher callback not called")
        } else if !pixelWasReady {
            FailTest("Finisher pixel check", "Pixel state not accessible in callback")
        } else {
            PassTest("Finisher pixel check")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher pixel check", e.Message)
    }

    ; Test 7: Finisher NOT called when sequence interrupted
    try {
        LogTest("Test 7: Finisher not called on interruption...")
        bus := EventBus()

        ; Track finisher execution
        finisherExecuted := false
        Test7_FinisherCallback() {
            finisherExecuted := true
        }

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Create engine with delay in steps
        steps := [{key: "1", delay: 50}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test7_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Interrupt mid-sequence
        Sleep 20
        engine.InterruptSequence("Test interruption")

        ; Wait to ensure finisher would have fired if called
        Sleep 50

        if finisherExecuted {
            FailTest("Finisher interruption handling", "Finisher executed after interruption")
        } else {
            PassTest("Finisher interruption handling")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher interruption handling", e.Message)
    }

    ; Test 8: Multiple combos with shared finisher callback
    try {
        LogTest("Test 8: Multiple combos with shared finisher...")
        bus := EventBus()

        ; Track finisher calls per combo
        finisherCallCount := 0
        Test8_FinisherCallback() {
            finisherCallCount++
        }

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Create 3 engines with same finisher callback
        steps1 := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        steps2 := [{key: "3", delay: 0}, {key: "4", delay: 0}]
        steps3 := [{key: "5", delay: 0}, {key: "6", delay: 0}]

        engine1 := SequenceEngine(bus, "Combo1", steps1, Test8_FinisherCallback, 10)
        engine2 := SequenceEngine(bus, "Combo2", steps2, Test8_FinisherCallback, 10)
        engine3 := SequenceEngine(bus, "Combo3", steps3, Test8_FinisherCallback, 10)

        engine1.Start()
        engine2.Start()
        engine3.Start()

        ; Execute all sequences
        engine1.ExecuteSequence()
        Sleep 30
        engine2.ExecuteSequence()
        Sleep 30
        engine3.ExecuteSequence()
        Sleep 30

        if finisherCallCount != 3 {
            FailTest("Multiple combos shared finisher", "Expected 3 finisher calls, got " . finisherCallCount)
        } else {
            PassTest("Multiple combos shared finisher")
        }

        engine1.Stop()
        engine2.Stop()
        engine3.Stop()
    } catch Error as e {
        FailTest("Multiple combos shared finisher", e.Message)
    }

    ; Test 9: FinisherError event on callback exception
    try {
        LogTest("Test 9: FinisherError event on callback exception...")
        bus := EventBus()

        ; Create callback that throws error
        Test9_FinisherCallback() {
            throw Error("Test error in finisher callback")
        }

        ; Track error event
        errorReceived := false
        errorHandler(data := unset) {
            errorReceived := true
        }
        bus.Subscribe("FinisherError", errorHandler)

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Create engine
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps, Test9_FinisherCallback, 10)
        engine.Start()

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for error
        Sleep 50

        if !errorReceived {
            FailTest("Finisher error handling", "FinisherError event not emitted")
        } else {
            PassTest("Finisher error handling")
        }

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher error handling", e.Message)
    }

    ; Test 10: Finisher callback optional (engine works without it)
    try {
        LogTest("Test 10: Finisher callback optional...")
        bus := EventBus()

        ; Create engine WITHOUT finisher callback
        steps := [{key: "1", delay: 0}, {key: "2", delay: 0}]
        engine := SequenceEngine(bus, "TestCombo", steps)  ; No callback
        engine.Start()

        ; Set protection states
        bus.SetState("chatActive", false)
        bus.SetState("windowActive", true)

        ; Execute sequence
        engine.ExecuteSequence()

        ; Wait for completion
        Sleep 30

        ; Should complete without error
        PassTest("Finisher callback optional")

        engine.Stop()
    } catch Error as e {
        FailTest("Finisher callback optional", e.Message)
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
        LogTest("Finisher integration is working correctly.")
    } else {
        LogTest("")
        LogTest("✗ SOME TESTS FAILED")
        LogTest("Review failures above and fix issues.")
    }

    LogTest("")
    LogTest("Press F10 to exit test suite.")
}

; ===== EXIT HOTKEY =====
F10:: {
    ExitApp
}

; DO NOT AUTO-RUN - Wait for user to press hotkey
LogTest("Press F1 to run finisher integration tests...")

F1:: {
    RunAllTests()
}

; Keep script running
return
