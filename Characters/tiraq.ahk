; Tiraq autocasts Heavy Strike in the swing timer sweet-spot and Thunder Call on cooldown while in combat.
; Press F1 to toggle on and off, and F10 to exit script. Adjust Lines 35 or 172 to change these keys.

#Requires AutoHotkey v2.0
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; UI CONFIGURATION. CONFIGURE THE FOLLOWING SECTION USING AHK WINDOW SPY (COMES WITH AHK INSTALLATION, SEARCH YOUR COMPUTER FOR IT)
; How-to: Open Window Spy visible, mouseover the UI element and take note of the X and Y coordinates. e.g. 1422,680 (first number x, second number y)

barX := 1422  ; X coor of the swing timer bar center
barY := 680  ; Y coord of the swing timer bar center

thunderX := 1224  ; X coord for thunder hotbar icon (Using a clock as directional reference, pick an area around 11:30 in the icon for your coordinates. It helps with cooldown color matching)
thunderY := 1018   ; Y coord for thunder hotbar icon (Same instructions as above)

activeColor := 0x9E2627    ; Swing timer bar when active/bright red (hold your mouse over the exact x,y coordinate area for your bar and take note of the colors as the bar changes states)
inactiveColor := 0x4B1A15  ; Red bar when inactive/dark (Same instructions as above)
colorTolerance := 25       ; Adjust if needed (20-30)

thunderOffCooldownColor := 0xB6E7ED   ; Color when thunder is ready/off cooldown (Hold your mouse over the exact x,y coordinate area of the icon and take note of the colors as the icon changes states)
thunderOnCooldownColor := 0x334042    ; Color when thunder is on cooldown (Same instructions as above)
thunderColorTolerance := 25            ; Adjust if needed (20-30)

strikeHotKey := "1" ; Change to your keybind for Heavy Strike. KEEP THE QUOTES
thunderHotKey := "2" ; Change to your keybind for Thunder Call. KEEP THE QUOTES

; END UI CONFIGURATION

; ------------DO NOT TOUCH BELOW THIS LINE------------ ;

isMonitoring := false
barWasInactive := true
lastOneSentTime := 0
lastBarActivityTime := 0
thunderCooldownStartTime := 0  ; When cooldown started
thunderIsOnCooldown := false   ; Track if thunder is currently on cooldown
inCombat := false

; Toggle script on and off
F1:: {
    global isMonitoring, barWasInactive, inCombat, lastBarActivityTime
    global thunderCooldownStartTime, thunderIsOnCooldown
    isMonitoring := !isMonitoring
    if (isMonitoring) {
        ToolTip "Monitoring ON - Press F1 to stop"
        barWasInactive := true
        inCombat := false
        lastBarActivityTime := 0
        thunderCooldownStartTime := 0
        thunderIsOnCooldown := false
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 50
    } else {
        ToolTip "Monitoring OFF"
        SetTimer () => ToolTip(), -2000
        SetTimer MonitorLoop, 0
    }
}

MonitorLoop() {
    global barX, barY, activeColor, inactiveColor, colorTolerance
    global thunderX, thunderY, thunderOffCooldownColor, thunderOnCooldownColor, thunderColorTolerance
    global isMonitoring, barWasInactive, lastOneSentTime
    global lastBarActivityTime, thunderCooldownStartTime, thunderIsOnCooldown, inCombat

    if (!isMonitoring)
        return

    ; Check bar color
    currentColor := PixelGetColor(barX, barY)

    ; Track bar activity - if bar is "inactive", we're in combat
    if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
        lastBarActivityTime := A_TickCount
        inCombat := true
    }

    ; Out of combat if bar has been bright red (active) for more than 3 seconds
    if (inCombat && (A_TickCount - lastBarActivityTime) > 3000) {
        inCombat := false
        ; Reset Thunder Call tracking when leaving combat
        thunderIsOnCooldown := false
        thunderCooldownStartTime := 0
    }

    ; SWING TIMER BAR LOGIC
    ; Check if bar just became active (transition from inactive to active)
    if (barWasInactive && ColorMatch(currentColor, activeColor, colorTolerance)) {
        ; Bar just became active - wait then press Heavy Strike
        barWasInactive := false
        Sleep Random(100, 170)
        Send strikeHotKey
        lastOneSentTime := A_TickCount  ; Record Heavy Strike was sent

        ; Cooldown to prevent multiple triggers
        Sleep 1500
    }

    ; Check if bar is inactive
    if (ColorMatch(currentColor, inactiveColor, colorTolerance)) {
        barWasInactive := true
    }

    ; THUNDER CALL LOGIC
    if (inCombat) {
        ; Check thunder area color
        thunderColor := PixelGetColor(thunderX, thunderY)

        ; Check if thunder is currently on cooldown (by color)
        currentlyOnCooldown := ColorMatch(thunderColor, thunderOnCooldownColor, thunderColorTolerance)
        currentlyOffCooldown := ColorMatch(thunderColor, thunderOffCooldownColor, thunderColorTolerance)

        ; Detect cooldown state changes
        if (!thunderIsOnCooldown && currentlyOnCooldown) {
            ; Thunder Call just went on cooldown - start timer
            thunderIsOnCooldown := true
            thunderCooldownStartTime := A_TickCount
        } else if (thunderIsOnCooldown && currentlyOffCooldown) {
            ; Thunder Call came off cooldown
            thunderIsOnCooldown := false
        }

        ; Calculate time since cooldown started
        timeSinceCooldownStart := thunderCooldownStartTime > 0 ? (A_TickCount - thunderCooldownStartTime) : 0

        ; Use Thunder Call if off cooldown AND enough time has passed
        canUsethunder := false

        if (thunderCooldownStartTime == 0) {
            ; Never used before - can use immediately when off cooldown
            canUsethunder := currentlyOffCooldown
        } else if (timeSinceCooldownStart >= 44500) {
            ; 44.5+ seconds have passed since cooldown started
            ; AND we're currently showing off cooldown color
            canUsethunder := currentlyOffCooldown
        }

        if (canUsethunder) {
            ; Check if Heavy Strike hotkey was sent less than 500ms ago
            timeSinceOne := A_TickCount - lastOneSentTime
            if (timeSinceOne < 500) {
                ; Wait for the remaining time to reach 500ms total
                Sleep(500 - timeSinceOne)
            }

            ; Send Thunder Call hotkey
            Send thunderHotKey

            ; Small delay to let the game register it
            Sleep 500

            ; The cooldown detection will pick up the state change automatically
            ; on the next loop iteration
        }
    } else {
        ; Not in combat - reset Thunder Call timer
        thunderIsOnCooldown := false
        thunderCooldownStartTime := 0
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
