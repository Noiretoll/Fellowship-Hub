;MEIKO FINISHER SCRIPT
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; Target game process
gameProcess := "fellowship-Win64-Shipping.exe"

; Finisher icon coordinates
finisherX := 1205
finisherY := 1119

; Colors
inactiveColor := 0x505050  ; Gray when finisher not available
colorTolerance := 10
isMonitoring := false
comboActive := false
comboCancelRequested := false
comboLocked := false
isFinisherProcessing := false
finisherPending := false
activeComboHotkey := ""
segmentGap := 50  ; extra buffer between combo segments (ms)

; ===== COMBO CONFIGURATION =====
gcdDelay := 1000  ; Global cooldown in milliseconds between abilities

; comboTable maps each hotkey to the keys it should fire.
; format example: Map(
;"Key you press", ["Combo Builder 1 hotbar key", "Combo Builder 2 hotbar key"]
;)
; - Use the AHK key notation ("1", "!1" for Alt+1, "^1" for Shift+1 etc.).
; - A pair ["1", "2"] runs a single two-button combo.
; - Wrap multiple pairs to chain combos back-to-back (see hotkey "3").
; Adjust the entries below to match your in-game keybinds.
comboTable := Map(
    "3", [["3", "1"], ["3", "2"]],
    "!3", ["3", "2"],
    "1", ["1", "2"],
    "!1", ["1", "3"],
    "2", ["2", "1"],
    "!2", ["2", "3"]
)

for hotkeyName, keys in comboTable {
    Hotkey("$" . hotkeyName, RunCombo.Bind(keys))
}

; Toggle monitoring with F1
F1:: {
    global isMonitoring
    isMonitoring := !isMonitoring
    if (isMonitoring) {
        ToolTip "Meiko Monitoring ON - Press F1 to stop"
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 50
    } else {
        ToolTip "Meiko Monitoring OFF"
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 0
    }
}

; ===== COMBO EXECUTION =====
RunCombo(keySequence, thisHotkey := "") {
    global gcdDelay, segmentGap, isFinisherProcessing
    global comboLocked, comboActive, comboCancelRequested, activeComboHotkey

    if !(keySequence is Array)
        return

    ; Ignore hotkey spam while a combo is already running
    if (comboLocked)
        return

    comboLocked := true
    comboActive := true
    comboCancelRequested := false
    activeComboHotkey := NormalizeHotkey(thisHotkey != "" ? thisHotkey : A_ThisHotkey)

    segments := []
    if (keySequence.Length > 0 && keySequence[1] is Array) {
        segments := keySequence
    } else {
        segments := [keySequence]
    }

    try {
        for index, segment in segments {
            if !(segment is Array)
                continue

            TryExecuteFinisher(true)

            canceled := ExecuteComboSegment(segment)
            if (canceled)
                break

            TryExecuteFinisher(true)

            if (index < segments.Length) {
                if (WaitForComboCooldown(gcdDelay, true)) {
                    break
                }

                TryExecuteFinisher(true)

                if (segmentGap > 0 && WaitForComboCooldown(segmentGap, true)) {
                    break
                }

                TryExecuteFinisher(true)
            }
        }
    } finally {
        FinishCombo()
    }
}

SendComboStep(key) {
    global comboCancelRequested

    if (comboCancelRequested)
        return true

    SendInput(key)
    Sleep 30  ; brief pause to let key register

    return comboCancelRequested
}

WaitForComboCooldown(duration, allowFinisher := false) {
    global comboCancelRequested

    step := 25
    endTime := A_TickCount + duration

    while (true) {
        if (comboCancelRequested)
            return true

        if (allowFinisher)
            TryExecuteFinisher(true)

        remaining := endTime - A_TickCount
        if (remaining <= 0)
            break

        sleepChunk := (remaining < step) ? remaining : step
        Sleep sleepChunk
    }

    return comboCancelRequested
}

ExecuteComboSegment(keys) {
    global comboCancelRequested, gcdDelay

    for index, key in keys {
        if (SendComboStep(key)) {
            return true
        }

        if (index < keys.Length) {
            if (WaitForComboCooldown(gcdDelay, true)) {
                return true
            }
        }
    }

    return comboCancelRequested
}

FinishCombo() {
    global comboCancelRequested, comboActive, comboLocked, finisherPending, activeComboHotkey
    comboActive := false
    comboCancelRequested := false
    comboLocked := false
    activeComboHotkey := ""
    if (finisherPending)
        TryExecuteFinisher()
}

TryExecuteFinisher(force := false) {
    global finisherX, finisherY, inactiveColor, colorTolerance
    global comboLocked, isFinisherProcessing, finisherPending
    global comboCancelRequested, comboActive, activeComboHotkey

    if (isFinisherProcessing)
        return false

    if (!force && comboLocked) {
        finisherPending := true
        return false
    }

    currentColor := PixelGetColor(finisherX, finisherY)
    if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
        if (!force)
            finisherPending := false
        return false
    }

    finisherPending := false
    isFinisherProcessing := true

    needToUnlock := false
    if (!comboLocked) {
        comboLocked := true
        needToUnlock := true
    }

    Sleep 50  ; Safety delay
    Send "``"
    Sleep 100  ; Let game register

    if (comboActive && activeComboHotkey != "3")
        comboCancelRequested := true

    currentColor := PixelGetColor(finisherX, finisherY)
    if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
        Sleep 200
    }

    Sleep 200

    if (needToUnlock)
        comboLocked := false

    isFinisherProcessing := false
    return true
}

NormalizeHotkey(hotkey) {
    if (!hotkey)
        return ""

    hotkey := Trim(hotkey)
    while (SubStr(hotkey, 1, 1) = "$") {
        hotkey := SubStr(hotkey, 2)
    }
    return hotkey
}

; Main monitoring loop
MonitorLoop() {
    global finisherX, finisherY, inactiveColor, colorTolerance
    global isMonitoring, gameProcess

    if (!isMonitoring)
        return

    ; Only execute if game is active window
    if (!WinActive("ahk_exe " . gameProcess))
        return
    ; ===== FINISHER MONITORING =====
    ; Check current finisher icon color
    currentColor := PixelGetColor(finisherX, finisherY)
    isInactive := ColorMatch(currentColor, inactiveColor, colorTolerance)

    ; If finisher is available (not gray), execute press sequence
    if (!isInactive)
        TryExecuteFinisher()
}

; Helper function to match colors with tolerance
ColorMatch(color1, color2, tolerance) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF

    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF

    return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
}

; Exit script with F10
F10:: {
    ExitApp
}
