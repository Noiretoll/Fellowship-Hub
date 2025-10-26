; PixelMonitor.ahk
; Support system for pixel condition detection and window state monitoring
; Phase 8 of Event-Driven Architecture Rework
;
; Purpose: Generic pixel polling engine that emits events when pixel conditions are met
; Events Emitted:
;   - "PixelConditionMet" {target, color, x, y} - When pixel matches target color
;   - "WindowActive" - When game window gains focus
;   - "WindowInactive" - When game window loses focus
;
; State Management:
;   - Sets state["pixel_<targetName>"] = true/false for each monitored pixel
;   - Sets state["windowActive"] = true/false for window focus state

#Requires AutoHotkey v2.0
#Include BaseEngine.ahk

class PixelMonitor extends BaseEngine {
    ; Properties
    pixelTargets := Map()       ; Map<targetName, {x, y, activeColor, tolerance, invert?}>
    pollInterval := 50          ; Milliseconds between pixel polls
    gameProcess := ""           ; Process name to monitor (e.g., "fellowship-Win64-Shipping.exe")
    timer := unset              ; Timer callback reference (for cleanup)
    windowWasActive := false    ; Track window state changes

    ; Constructor
    ; Parameters:
    ;   bus - EventBus instance
    ;   pixelTargets - Map of pixel targets to monitor
    ;   gameProcess - Game process name (e.g., "fellowship-Win64-Shipping.exe")
    ;   pollInterval - Polling interval in milliseconds (default: 50)
    __New(bus, pixelTargets, gameProcess, pollInterval := 50) {
        super.__New(bus, "PixelMonitor")

        ; Validate parameters
        if !IsObject(pixelTargets) {
            throw ValueError("pixelTargets must be a Map object", -1)
        }
        if gameProcess = "" {
            throw ValueError("gameProcess cannot be empty", -1)
        }

        ; Store configuration
        this.pixelTargets := pixelTargets
        this.gameProcess := gameProcess
        this.pollInterval := pollInterval
        this.windowWasActive := false
    }

    ; Start pixel monitoring
    Start() {
        super.Start()

        ; Initialize all pixel states to false
        for targetName, target in this.pixelTargets {
            this.SetState("pixel_" . targetName, false)
        }

        ; Initialize window state
        this.windowWasActive := this._IsWindowActive()
        this.SetState("windowActive", this.windowWasActive)

        ; Create and start polling timer
        this.timer := this.PollPixels.Bind(this)
        SetTimer(this.timer, this.pollInterval)
    }

    ; Stop pixel monitoring
    Stop() {
        super.Stop()

        ; Stop and cleanup timer
        if this.HasProp("timer") {
            SetTimer(this.timer, 0)
            this.DeleteProp("timer")
        }

        ; Clear all pixel states
        for targetName, target in this.pixelTargets {
            this.SetState("pixel_" . targetName, false)
        }
    }

    ; Timer callback - polls all pixel targets and window state
    PollPixels() {
        ; Check window state first
        this._CheckWindowState()

        ; Skip pixel polling if window is inactive
        if !this.GetState("windowActive", false) {
            return
        }

        ; Poll each pixel target
        for targetName, target in this.pixelTargets {
            this._CheckPixel(targetName, target)
        }
    }

    ; Check and update window active state
    _CheckWindowState() {
        isActive := this._IsWindowActive()

        ; Emit events only on state change
        if isActive != this.windowWasActive {
            this.windowWasActive := isActive
            this.SetState("windowActive", isActive)

            if isActive {
                this.EmitEvent("WindowActive")
            } else {
                this.EmitEvent("WindowInactive")
            }
        }
    }

    ; Check if game window is active
    ; Returns: true if window is active, false otherwise
    _IsWindowActive() {
        return WinActive("ahk_exe " . this.gameProcess)
    }

    ; Check a single pixel target and emit event if condition met
    ; Parameters:
    ;   targetName - Name of the pixel target
    ;   target - Map with {x, y, activeColor, tolerance, invert?}
    _CheckPixel(targetName, target) {
        ; Get current pixel color
        currentColor := PixelGetColor(target["x"], target["y"])

        ; Check if color matches (with tolerance)
        isMatch := this._ColorMatch(
            currentColor,
            target["activeColor"],
            target["tolerance"]
        )

        ; Apply invert if specified
        if target.Has("invert") && target["invert"] {
            isMatch := !isMatch
        }

        ; Update state
        stateKey := "pixel_" . targetName
        previousState := this.GetState(stateKey, false)

        if isMatch != previousState {
            this.SetState(stateKey, isMatch)

            ; Emit event when pixel condition is met (transition to true)
            if isMatch {
                this.EmitEvent("PixelConditionMet", {
                    target: targetName,
                    color: currentColor,
                    x: target["x"],
                    y: target["y"]
                })
            }
        }
    }

    ; Compare two colors with RGB tolerance
    ; Parameters:
    ;   color1 - First color (0xRRGGBB)
    ;   color2 - Second color (0xRRGGBB)
    ;   tolerance - Maximum allowed difference per channel (0-255)
    ; Returns: true if colors match within tolerance
    _ColorMatch(color1, color2, tolerance) {
        ; Extract RGB components
        r1 := (color1 >> 16) & 0xFF
        g1 := (color1 >> 8) & 0xFF
        b1 := color1 & 0xFF

        r2 := (color2 >> 16) & 0xFF
        g2 := (color2 >> 8) & 0xFF
        b2 := color2 & 0xFF

        ; Check if all channels are within tolerance
        return (Abs(r1 - r2) <= tolerance)
            && (Abs(g1 - g2) <= tolerance)
            && (Abs(b1 - b2) <= tolerance)
    }

    ; Destructor - ensure timer is stopped
    __Delete() {
        if this.HasProp("timer") {
            SetTimer(this.timer, 0)
            this.DeleteProp("timer")
        }

        super.__Delete()
    }
}
