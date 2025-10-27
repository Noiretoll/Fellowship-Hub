; HotkeyDispatcher.ahk
; Support system for hotkey registration and event emission
; Phase 8 of Event-Driven Architecture Rework
;
; Purpose: Generic hotkey registration engine that emits events when hotkeys are pressed
; Events Emitted:
;   - "HotkeyPressed" {key, action, timestamp} - When registered hotkey is pressed
;
; Protection:
;   - Respects "chatActive" state (doesn't emit events when chat is active)
;   - Respects "windowActive" state (doesn't emit events when window is inactive)

#Requires AutoHotkey v2.0
#Include BaseEngine.ahk

class HotkeyDispatcher extends BaseEngine {
    ; Properties
    hotkeyMap := Map()           ; Map<hotkeyStr, action> - hotkeys to register
    registeredHotkeys := []      ; Array of {hotkey, callback} for cleanup
    gameProcess := ""            ; Process name to check window state

    ; Constructor
    ; Parameters:
    ;   bus - EventBus instance
    ;   hotkeyMap - Map of hotkey strings to action identifiers
    ;   gameProcess - Game process name for window checking (e.g., "fellowship-Win64-Shipping.exe")
    ;
    ; Example hotkeyMap:
    ;   Map("F1", "ToggleCombo", "F2", "SequenceKey1", "!F1", "ToggleFinisher")
    __New(bus, hotkeyMap, gameProcess) {
        super.__New(bus, "HotkeyDispatcher")

        ; Validate parameters
        if !IsObject(hotkeyMap) {
            throw ValueError("hotkeyMap must be a Map object", -1)
        }
        if gameProcess = "" {
            throw ValueError("gameProcess cannot be empty", -1)
        }

        ; Store configuration
        this.hotkeyMap := hotkeyMap
        this.gameProcess := gameProcess
        this.registeredHotkeys := []
    }

    ; Start hotkey registration
    Start() {
        super.Start()

        ; Register all hotkeys from map
        for hotkeyStr, action in this.hotkeyMap {
            this._RegisterHotkey(hotkeyStr, action)
        }
    }

    ; Stop hotkey registration
    Stop() {
        super.Stop()

        ; Unregister all hotkeys
        for entry in this.registeredHotkeys {
            try {
                ; Turn off hotkey
                Hotkey(entry.hotkey, "Off")
            } catch Error as e {
                ; Ignore errors during cleanup
            }
        }

        ; Clear registered hotkeys array
        this.registeredHotkeys := []
    }

    ; Register a single hotkey
    ; Parameters:
    ;   hotkeyStr - Hotkey string (e.g., "F1", "!F2", "^+A")
    ;   action - Action identifier to include in event
    _RegisterHotkey(hotkeyStr, action) {
        ; Create callback - use simple fat arrow that calls handler with hotkey string
        ; Handler will look up action from hotkeyMap
        callback := (*) => this._HandleHotkey(hotkeyStr)

        try {
            ; Register hotkey with AHK
            Hotkey(hotkeyStr, callback)

            ; Track for cleanup
            this.registeredHotkeys.Push({
                hotkey: hotkeyStr,
                callback: callback
            })
        } catch Error as e {
            ; Log error but continue (some hotkeys may conflict)
            this.EmitEvent("HotkeyRegistrationFailed", {
                hotkey: hotkeyStr,
                action: action,
                error: e.Message
            })
        }
    }

    ; Handle hotkey press
    ; Parameters:
    ;   hotkeyStr - The hotkey string that was pressed
    _HandleHotkey(hotkeyStr) {
        ; Look up action from map
        if !this.hotkeyMap.Has(hotkeyStr) {
            return
        }
        action := this.hotkeyMap[hotkeyStr]

        ; Check if chat is active (don't emit if in chat)
        if this.GetState("chatActive", false) {
            return
        }

        ; Check if window is active (don't emit if window inactive)
        if !this._IsWindowActive() {
            return
        }

        ; Emit hotkey pressed event
        this.EmitEvent("HotkeyPressed", {
            key: hotkeyStr,
            action: action,
            timestamp: A_TickCount
        })
    }

    ; Check if game window is active
    ; Returns: true if window is active, false otherwise
    _IsWindowActive() {
        return WinActive("ahk_exe " . this.gameProcess)
    }

    ; Destructor - ensure all hotkeys are unregistered
    __Delete() {
        ; Unregister all hotkeys
        for entry in this.registeredHotkeys {
            try {
                Hotkey(entry.hotkey, "Off")
            } catch Error as e {
                ; Ignore errors during cleanup
            }
        }

        ; Clear array
        this.registeredHotkeys := []

        super.__Delete()
    }
}
