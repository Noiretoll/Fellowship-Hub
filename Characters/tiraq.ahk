#Requires AutoHotkey v2.0
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; Configure these coordinates by using Window Spy
barX := 1422  ; X coordinate of the bar center
barY := 680  ; Y coordinate to check (middle of bar area)

; Colors to detect
activeColor := 0x9E2627    ; Red bar when active/bright
inactiveColor := 0x4B1A15  ; Red bar when inactive/dark
colorTolerance := 25       ; Adjust if needed

isMonitoring := false
barWasInactive := true

; Toggle monitoring with F1
F1:: {
    global isMonitoring, barWasInactive
    isMonitoring := !isMonitoring
    if (isMonitoring) {
        ToolTip "Monitoring ON - Press F1 to stop"
        barWasInactive := true
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 50
    } else {
        ToolTip "Monitoring OFF"
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 0
    }
}

; Main monitoring loop
MonitorLoop() {
    global barX, barY, activeColor, inactiveColor, colorTolerance
    global isMonitoring, barWasInactive

    if (!isMonitoring)
        return

    ; Check current bar color
    currentColor := PixelGetColor(barX, barY)

    ; Check if bar just became active (transition from inactive to active)
    if (barWasInactive && ColorMatch(currentColor, activeColor, colorTolerance)) {
        ; Bar just became active - wait then press 1
        barWasInactive := false
        Sleep 200
        Send "1"

        ; Cooldown to prevent multiple triggers
        Sleep 1500
    }

    ; Check if bar is inactive
    if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
        barWasInactive := true
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

