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
    if (!isInactive) {
        Sleep 50  ; Safety delay

        ; First press
        Send "``"
        Sleep 100  ; Let game register

        ; Check if successful (returned to gray)
        currentColor := PixelGetColor(finisherX, finisherY)
        if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
            ; Success - wait for it to fully reset before monitoring again
            Sleep 200
            return
        }

        ; First press failed, try second press
        Sleep 400  ; Total 500ms from first press
        Send "``"

        ; Wait a bit regardless of outcome to avoid spam
        Sleep 500
    }
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
