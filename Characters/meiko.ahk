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

; Shield orb coordinates
; shieldOrbX := 1225
; shieldOrbY := 912

; Shield orb was present on last check
; shieldOrbPresent := false

isMonitoring := false

; Toggle monitoring with F1
F1:: {
    global isMonitoring, shieldOrbPresent
    isMonitoring := !isMonitoring
    if (isMonitoring) {
        ToolTip "Meiko Monitoring ON - Press F1 to stop"
        shieldOrbPresent := false  ; Reset shield state
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
    ; global shieldOrbX, shieldOrbY, shieldOrbPresent
    global isMonitoring, gameProcess

    if (!isMonitoring)
        return

    ; Only execute if game is active window
    if (!WinActive("ahk_exe " . gameProcess))
        return

    ; ===== SHIELD ORB MONITORING ===== (DISABLED)
    ; shieldColor := PixelGetColor(shieldOrbX, shieldOrbY)
    ; orbCurrentlyPresent := IsGoldenColor(shieldColor)
    ;
    ; ; Detect when orb disappears (was present, now gone)
    ; if (shieldOrbPresent && !orbCurrentlyPresent) {
    ;     Sleep 50
    ;     Send "x"
    ;     Sleep 100  ; Brief pause to let shield refresh
    ;
    ;     ; Verify orb is back
    ;     shieldColor := PixelGetColor(shieldOrbX, shieldOrbY)
    ;     shieldOrbPresent := IsGoldenColor(shieldColor)
    ; } else {
    ;     ; Update current state
    ;     shieldOrbPresent := orbCurrentlyPresent
    ; }

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

; Helper function to detect golden/yellow shield orb colors
; Covers range: C98947, D69447, E59B46, F7A52F and similar golden-orange tones
IsGoldenColor(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF

    ; Convert to HSV for better color range detection
    maxVal := Max(r, g, b)
    minVal := Min(r, g, b)
    delta := maxVal - minVal

    ; Value (brightness) check: these colors are fairly bright
    v := maxVal / 255.0
    if (v < 0.48 || v > 1.0)  ; Too dark or invalid
        return false

    ; Saturation check: these colors have moderate-high saturation
    s := (maxVal = 0) ? 0 : delta / maxVal
    if (s < 0.40 || s > 0.85)  ; Too gray or oversaturated
        return false

    ; Hue check: orange-yellow range
    if (delta = 0)
        return false

    if (maxVal = r)
        h := 60 * Mod((g - b) / delta, 6)
    else if (maxVal = g)
        h := 60 * ((b - r) / delta + 2)
    else
        h := 60 * ((r - g) / delta + 4)

    if (h < 0)
        h += 360

    ; Golden-orange hue range: approximately 25-40 degrees
    return (h >= 25 && h <= 40)
}

; Exit script with F10
F10:: {
    ExitApp
}
