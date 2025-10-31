; Meiko_AutoFinisher.ahk
; Meiko auto-finisher script with pixel-driven finisher detection
; Fires finisher immediately when pixel becomes active (no combo logic)
;
; Controls:
;   Alt+F2   - Toggle auto-finisher ON/OFF (default: OFF)
;   Auto pause on in-game chat activation or alt-tab
;   F10      - Exit script

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; ========================================
; CONFIGURATION - CALIBRATE THESE VALUES
; ========================================
; REQUIRED: Borderless full-screen
;
; HOW TO CALIBRATE:
; 1. Search Windows for "Window Spy" and launch it (bundled with AutoHotkey)
; 2. Open Fellowship and hover mouse over finisher UI indicator when INACTIVE (dim/dark)
; 3. Use X, Y coordinates and RGB color from Window Spy to configure below
; 4. Adjust tolerance (10-30) if detection is unreliable

global CFG_FINISHER_KEY := "``"          ; Finisher keybind (backtick)
global CFG_FINISHER_X := 1205            ; X coordinate of finisher pixel
global CFG_FINISHER_Y := 1119            ; Y coordinate of finisher pixel
global CFG_FINISHER_COLOR := 0x303030   ; RGB color when finisher is INACTIVE (dim/dark)
global CFG_FINISHER_TOLERANCE := 10     ; Color match tolerance (10=strict, 30=loose)

; ========================================
; END CONFIGURATION
; ========================================

; Script logic constants (do not modify)
global CFG_FINISHER_INVERT := true  ; Core logic: fires when NOT matching inactive color

; Include framework components
#Include ..\Framework\EventBus.ahk
#Include ..\Framework\BaseEngine.ahk
#Include ..\Framework\PixelMonitor.ahk

; ===== MEIKO AUTO-FINISHER CLASS =====
class MeikoAutoFinisher {
    ; Framework components
    bus := ""
    pixelMonitor := ""

    ; Configuration (loaded from global CFG_* variables at top of script)
    gameProcess := "fellowship-Win64-Shipping.exe"
    finisherKey := CFG_FINISHER_KEY
    finisherPixelX := CFG_FINISHER_X
    finisherPixelY := CFG_FINISHER_Y
    finisherActiveColor := CFG_FINISHER_COLOR
    finisherTolerance := CFG_FINISHER_TOLERANCE
    finisherInvert := CFG_FINISHER_INVERT

    ; State flags
    autoFinisherEnabled := false ; Auto-finisher disabled by default
    chatActive := false

    ; Chat hotkey callbacks (stored for cleanup)
    chatEnterCallback := ""
    chatSlashCallback := ""
    chatEscapeCallback := ""

    ; Constructor - Sets up all framework components
    __New() {
        ; Create EventBus first (central communication hub)
        this.bus := EventBus()

        ; Initialize state
        this.bus.SetState("windowActive", true)
        this.bus.SetState("chatActive", false)

        ; Setup components
        this._SetupPixelMonitor()
        this._SetupChatProtection()
        this._SetupToggleHotkeys()

        ; Subscribe to pixel state changes
        this.bus.Subscribe("PixelStateChanged", this.HandlePixelChange.Bind(this))
    }

    ; ===== PIXEL MONITOR SETUP =====
    _SetupPixelMonitor() {
        ; Define pixel targets to monitor
        pixelTargets := Map()

        ; Finisher pixel target (inverted - looks for NOT inactive color)
        pixelTargets["Finisher"] := Map(
            "x", this.finisherPixelX,
            "y", this.finisherPixelY,
            "activeColor", this.finisherActiveColor,
            "tolerance", this.finisherTolerance,
            "invert", this.finisherInvert
        )

        ; Create PixelMonitor with configured targets
        this.pixelMonitor := PixelMonitor(
            this.bus,
            pixelTargets,
            this.gameProcess,
            50  ; Poll interval: 50ms
        )
    }

    ; ===== CHAT PROTECTION SETUP =====
    _SetupChatProtection() {
        ; Register chat hotkeys with passthrough
        ; These hotkeys set chatActive state and still send the key

        ; Enter key - toggle chat
        this.chatEnterCallback := (*) => this.ToggleChat("Enter")
        Hotkey("$Enter", this.chatEnterCallback)

        ; Slash key - toggle chat
        this.chatSlashCallback := (*) => this.ToggleChat("/")
        Hotkey("$/", this.chatSlashCallback)

        ; Escape key - cancel chat
        this.chatEscapeCallback := (*) => this.CancelChat()
        Hotkey("$Escape", this.chatEscapeCallback)
    }

    ; ===== TOGGLE HOTKEY SETUP =====
    _SetupToggleHotkeys() {
        ; Alt+F2 - Toggle auto-finisher
        Hotkey("!F2", (*) => this.ToggleAutoFinisher())

        ; F10 - Exit script
        Hotkey("F10", (*) => this.Cleanup())
    }

    ; ===== START ALL SYSTEMS =====
    Start() {
        ; Start pixel monitoring (monitors finisher pixel state)
        this.pixelMonitor.Start()

        ToolTip "Meiko Auto-Finisher Started`nAlt+F2: Toggle Auto-Finisher | F10: Exit"
        SetTimer () => ToolTip(), -3000
    }

    ; ===== EVENT HANDLERS =====

    ; Handle pixel state changes
    ; Triggered by PixelStateChanged event from PixelMonitor
    HandlePixelChange(data := unset) {
        ; Validate event data
        if !IsSet(data) || data.name != "Finisher" {
            return
        }

        ; Only fire if auto-finisher is enabled
        if !this.autoFinisherEnabled {
            return
        }

        ; Only fire if pixel became active (not inactive)
        if !data.active {
            return
        }

        ; Check window and chat guards
        if !WinActive("ahk_exe " . this.gameProcess) {
            return
        }

        if this.bus.GetState("chatActive", false) {
            return
        }

        ; Execute finisher immediately
        Send this.finisherKey

        ; Emit event for tracking/debugging
        this.bus.Emit("FinisherExecuted", {
            timestamp: A_TickCount,
            mode: "finisher-only"
        })
    }

    ; ===== TOGGLE HANDLERS =====

    ; Toggle auto-finisher on/off
    ToggleAutoFinisher() {
        this.autoFinisherEnabled := !this.autoFinisherEnabled

        if this.autoFinisherEnabled {
            ToolTip "Auto-Finisher: ON"
        } else {
            ToolTip "Auto-Finisher: OFF"
        }

        SetTimer () => ToolTip(), -2000
    }

    ; Toggle chat mode
    ToggleChat(key) {
        this.chatActive := !this.chatActive
        this.bus.SetState("chatActive", this.chatActive)

        if this.chatActive {
            ToolTip "Chat Mode: ON"
            SetTimer () => ToolTip(), -2000
        } else {
            ToolTip "Chat Mode: OFF"
            SetTimer () => ToolTip(), -2000
        }

        ; Send the key (passthrough)
        Send "{" . key . "}"
    }

    ; Cancel chat mode
    CancelChat() {
        if this.chatActive {
            this.chatActive := false
            this.bus.SetState("chatActive", false)

            ToolTip "Chat Cancelled"
            SetTimer () => ToolTip(), -2000
        }

        ; Send Escape key (passthrough)
        Send "{Escape}"
    }

    ; ===== CLEANUP =====
    Cleanup() {
        ToolTip "Shutting down Meiko Auto-Finisher..."
        SetTimer () => ToolTip(), -1000

        ; Stop pixel monitor
        if IsObject(this.pixelMonitor) {
            this.pixelMonitor.Stop()
        }

        ; Disable chat hotkeys
        try {
            Hotkey("$Enter", "Off")
            Hotkey("$/", "Off")
            Hotkey("$Escape", "Off")
            Hotkey("!F2", "Off")
            Hotkey("F10", "Off")
        } catch {
            ; Ignore errors during cleanup
        }

        ; Clear EventBus
        if IsObject(this.bus) {
            this.bus.Clear()
        }

        ; Exit after short delay
        SetTimer () => ExitApp(), -1000
    }

    ; Destructor
    __Delete() {
        this.Cleanup()
    }
}

; ===== INITIALIZE AND START =====
global meikoFinisher := MeikoAutoFinisher()
meikoFinisher.Start()

; Keep script running
return