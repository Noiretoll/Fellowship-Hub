; meiko_framework.ahk
; Meiko character script using event-driven framework architecture
; Implements two-layer pattern: Character-specific configuration + Generic framework engines
;
; Architecture: Event-Driven (Post-Phase 8 + Finisher Integration)
; - EventBus: Central event hub for all communication
; - PixelMonitor: Detects finisher availability via pixel detection
; - SequenceEngine: Executes combo sequences with integrated finisher callback
; - HotkeyDispatcher: Registers combo hotkeys and emits events
;
; Finisher Pattern:
; - Finisher is NOT an independent engine
; - After each combo completes (2nd key pressed), wait 10ms
; - Check pixel state, if finisher ready -> send finisher key
; - Finisher only fires AFTER combo completion, not during
;
; Controls:
;   Alt+F1   - Toggle auto-combo ON/OFF (default: OFF, includes finisher)
;   3, !3, 1, !1, 2, !2 - Combo sequences (when auto-combo enabled)
;   Enter, / - Open chat (pauses all automation)
;   Escape   - Cancel chat (resumes automation)
;   F10      - Exit script

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; Include framework components
#Include ..\Framework\EventBus.ahk
#Include ..\Framework\BaseEngine.ahk
#Include ..\Framework\PixelMonitor.ahk
#Include ..\Framework\HotkeyDispatcher.ahk
#Include ..\Framework\Engines\SequenceEngine.ahk

; ===== MEIKO CHARACTER CONFIGURATION =====
class MeikoCharacter {
    ; Framework components
    bus := ""
    pixelMonitor := ""
    hotkeyDispatcher := ""
    comboEngines := Map()  ; Map of combo name -> SequenceEngine (with finisher callbacks)

    ; Configuration
    gameProcess := "fellowship-Win64-Shipping.exe"
    gcdDelay := 1050       ; Global cooldown delay between combo steps
    finisherDelay := 10    ; Delay after combo completion before finisher check/execution
    finisherKey := "``"    ; Finisher keybind (backtick)

    ; State flags
    autoComboEnabled := false ; Auto-combo disabled by default
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
        this._SetupComboEngines()  ; Now includes finisher callback integration
        this._SetupComboHotkeys()
        this._SetupChatProtection()
        this._SetupToggleHotkeys()

        ; Subscribe to events for combo triggering
        this.bus.Subscribe("HotkeyPressed", this.HandleComboHotkey.Bind(this))
    }

    ; ===== PIXEL MONITOR SETUP =====
    _SetupPixelMonitor() {
        ; Define pixel targets to monitor
        pixelTargets := Map()

        ; Finisher pixel target (inverted - looks for NOT inactive color)
        pixelTargets["Finisher"] := Map(
            "x", 1205,
            "y", 1119,
            "activeColor", 0xFFFFFF,  ; Bright/lit up color
            "tolerance", 10,
            "invert", true  ; Invert logic: true when NOT matching inactive color
        )

        ; Create PixelMonitor with configured targets
        this.pixelMonitor := PixelMonitor(
            this.bus,
            pixelTargets,
            this.gameProcess,
            50  ; Poll interval: 50ms
        )
    }

    ; ===== COMBO ENGINE SETUP =====
    _SetupComboEngines() {
        ; Define all combo sequences
        ; Format: [{key: "1", delay: 1050}, {key: "2", delay: 0}]
        ; delay = milliseconds to wait AFTER sending key (GCD delay)

        combos := Map(
            "Combo3", [
                {key: "3", delay: this.gcdDelay},  ; Send 3, wait GCD
                {key: "1", delay: 0}                ; Send 1, no delay after
            ],
            "Combo3Alt", [
                {key: "3", delay: this.gcdDelay},
                {key: "2", delay: 0}
            ],
            "Combo1", [
                {key: "1", delay: this.gcdDelay},
                {key: "2", delay: 0}
            ],
            "Combo1Alt", [
                {key: "1", delay: this.gcdDelay},
                {key: "3", delay: 0}
            ],
            "Combo2", [
                {key: "2", delay: this.gcdDelay},
                {key: "1", delay: 0}
            ],
            "Combo2Alt", [
                {key: "2", delay: this.gcdDelay},
                {key: "3", delay: 0}
            ]
        )

        ; Create finisher callback function
        ; This will be called 10ms after each combo completes
        ; Checks pixel state and sends finisher key if ready
        finisherCallback := this.CheckAndExecuteFinisher.Bind(this)

        ; Create SequenceEngine for each combo with finisher callback
        for comboName, steps in combos {
            engine := SequenceEngine(
                this.bus,
                "Meiko" . comboName,  ; Unique engine name
                steps,                 ; Combo sequence steps
                finisherCallback,      ; Finisher callback (called after completion)
                this.finisherDelay     ; 10ms delay before finisher check
            )
            this.comboEngines[comboName] := engine
        }
    }

    ; ===== FINISHER CALLBACK =====
    ; Called 10ms after each combo completes
    ; Checks pixel condition and executes finisher if ready
    CheckAndExecuteFinisher() {
        ; Check if finisher pixel is ready (state set by PixelMonitor)
        if !this.bus.GetState("pixel_Finisher", false) {
            return  ; Finisher not ready, do nothing
        }

        ; Finisher is ready - send finisher key
        Send this.finisherKey

        ; Emit event for tracking/debugging
        this.bus.Emit("FinisherExecuted", {
            timestamp: A_TickCount
        })
    }

    ; ===== COMBO HOTKEY SETUP =====
    _SetupComboHotkeys() {
        ; Map hotkeys to combo names
        hotkeyMap := Map(
            "3", "Combo3",
            "!3", "Combo3Alt",
            "1", "Combo1",
            "!1", "Combo1Alt",
            "2", "Combo2",
            "!2", "Combo2Alt"
        )

        ; Create HotkeyDispatcher to register hotkeys
        this.hotkeyDispatcher := HotkeyDispatcher(
            this.bus,
            hotkeyMap,
            this.gameProcess
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
        ; Alt+F1 - Toggle auto-combo (with finisher integration)
        Hotkey("!F1", (*) => this.ToggleAutoCombo())

        ; F10 - Exit script
        Hotkey("F10", (*) => this.Cleanup())
    }

    ; ===== START ALL SYSTEMS =====
    Start() {
        ; Start pixel monitoring (monitors finisher pixel state)
        this.pixelMonitor.Start()

        ; Start combo engines (always on, but only execute when hotkey pressed)
        ; Each engine has finisher callback integrated
        for comboName, engine in this.comboEngines {
            engine.Start()
        }

        ; Hotkey dispatcher starts when auto-combo is enabled (toggled with Alt+F1)

        ToolTip "Meiko Script Started`nAlt+F1: Toggle Auto-Combo | F10: Exit"
        SetTimer () => ToolTip(), -3000
    }

    ; ===== HOTKEY HANDLERS =====

    ; Handle combo hotkey press
    ; Triggered by HotkeyPressed event from HotkeyDispatcher
    HandleComboHotkey(data := unset) {
        ; Check if data provided
        if !IsSet(data) {
            return
        }

        ; Only execute if auto-combo is enabled
        if !this.autoComboEnabled {
            return
        }

        ; Get combo name from action
        comboName := data.action

        ; Find matching combo engine
        if !this.comboEngines.Has(comboName) {
            return
        }

        ; Execute combo sequence
        engine := this.comboEngines[comboName]
        engine.ExecuteSequence()
    }

    ; Toggle auto-combo on/off (finisher is integrated into combos)
    ToggleAutoCombo() {
        this.autoComboEnabled := !this.autoComboEnabled

        if this.autoComboEnabled {
            this.hotkeyDispatcher.Start()
            ToolTip "Auto-Combo: ON"
        } else {
            this.hotkeyDispatcher.Stop()
            ToolTip "Auto-Combo: OFF"
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
        ToolTip "Shutting down Meiko script..."
        SetTimer () => ToolTip(), -1000

        ; Stop all engines
        if IsObject(this.pixelMonitor) {
            this.pixelMonitor.Stop()
        }

        for comboName, engine in this.comboEngines {
            engine.Stop()
        }

        if IsObject(this.hotkeyDispatcher) {
            this.hotkeyDispatcher.Stop()
        }

        ; Disable chat hotkeys
        try {
            Hotkey("$Enter", "Off")
            Hotkey("$/", "Off")
            Hotkey("$Escape", "Off")
            Hotkey("!F1", "Off")
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
global meiko := MeikoCharacter()
meiko.Start()

; Keep script running
return
