; Meiko_AutoCombo.ahk
; Meiko auto-combo script with hard-coded finisher integration
; Fires finisher automatically 200ms after each combo completes (no pixel detection)
;
; Controls:
;   Alt+F1   - Toggle auto-combo ON/OFF (default: OFF)
;   F10      - Exit script

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; ========================================
; CONFIGURATION - MATCH YOUR GAME KEYBINDS
; ========================================
; Hotkey syntax: "3" = key 3, "!3" = Alt+3, "^3" = Ctrl+3, "+3" = Shift+3

; ABILITY KEYBINDS (configure once to match in-game keybinds)
global CFG_EARTHEN_PUNCH_KEY := "1"      ; Earthen Punch ability keybind
global CFG_WIND_KICK_KEY := "2"          ; Wind Kick ability keybind
global CFG_SPIRIT_FIST_KEY := "3"        ; Spirit Fist ability keybind
global CFG_FINISHER_KEY := "``"          ; Finisher keybind (backtick default)

; COMBO HOTKEYS (press these keys to trigger combo sequences)
global CFG_EARTH_DAMAGE_HOTKEY := "1"    ; Earth Damage Combo: Earthen Punch → Wind Kick → Finisher
global CFG_EARTH_BUFF_HOTKEY := "!1"     ; Earth Buff Combo: Earthen Punch → Spirit Fist → Finisher
global CFG_WIND_DAMAGE_HOTKEY := "2"     ; Wind Damage Combo: Wind Kick → Earthen Punch → Finisher
global CFG_WIND_BUFF_HOTKEY := "!2"      ; Wind Buff Combo: Wind Kick → Spirit Fist → Finisher
global CFG_SPIRIT_BUFF1_HOTKEY := "3"    ; Spirit Buff 1 Combo: Spirit Fist → Earthen Punch → Finisher
global CFG_SPIRIT_BUFF2_HOTKEY := "!3"   ; Spirit Buff 2 Combo: Spirit Fist → Wind Kick → Finisher

; ========================================
; END CONFIGURATION
; ========================================

; Script constants (do not modify)
global CFG_GCD_DELAY := 1050             ; Global cooldown delay between combo steps (ms)
global CFG_FINISHER_DELAY := 200        ; Delay after combo before finisher fires (ms)

; Include framework components
#Include ..\Framework\EventBus.ahk
#Include ..\Framework\BaseEngine.ahk
#Include ..\Framework\SequenceEngine.ahk
#Include ..\Framework\HotkeyDispatcher.ahk

; ===== MEIKO AUTO-COMBO CLASS =====
class MeikoAutoCombo {
    ; Framework components
    bus := ""
    hotkeyDispatcher := ""
    comboEngines := Map()  ; Map of combo name -> SequenceEngine (with finisher callbacks)

    ; Configuration (loaded from global CFG_* variables at top of script)
    gameProcess := "fellowship-Win64-Shipping.exe"
    gcdDelay := CFG_GCD_DELAY
    finisherDelay := CFG_FINISHER_DELAY
    finisherKey := CFG_FINISHER_KEY

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
        this._SetupComboEngines()  ; Now includes finisher callback integration
        this._SetupComboHotkeys()
        this._SetupChatProtection()
        this._SetupToggleHotkeys()

        ; Subscribe to events for combo triggering
        this.bus.Subscribe("HotkeyPressed", this.HandleComboHotkey.Bind(this))
    }

    ; ===== COMBO ENGINE SETUP =====
    _SetupComboEngines() {
        ; Define all combo sequences using ability keybinds
        ; Format: [{key: "1", delay: 1050}, {key: "2", delay: 0}]
        ; delay = milliseconds to wait AFTER sending key (GCD delay)

        combos := Map(
            "EarthDamageCombo", [{ key: CFG_EARTHEN_PUNCH_KEY, delay: this.gcdDelay }, { key: CFG_WIND_KICK_KEY, delay: 0 }],
            "EarthBuffCombo", [{ key: CFG_EARTHEN_PUNCH_KEY, delay: this.gcdDelay }, { key: CFG_SPIRIT_FIST_KEY, delay: 0 }],
            "WindDamageCombo", [{ key: CFG_WIND_KICK_KEY, delay: this.gcdDelay }, { key: CFG_EARTHEN_PUNCH_KEY, delay: 0 }],
            "WindBuffCombo", [{ key: CFG_WIND_KICK_KEY, delay: this.gcdDelay }, { key: CFG_SPIRIT_FIST_KEY, delay: 0 }],
            "SpiritBuff1Combo", [{ key: CFG_SPIRIT_FIST_KEY, delay: this.gcdDelay }, { key: CFG_EARTHEN_PUNCH_KEY,
                delay: 0 }],
            "SpiritBuff2Combo", [{ key: CFG_SPIRIT_FIST_KEY, delay: this.gcdDelay }, { key: CFG_WIND_KICK_KEY, delay: 0 }]
        )
        ; Create finisher callback function
        ; This will be called 200ms after each combo completes
        ; Unconditionally sends finisher key (no pixel check)
        finisherCallback := this.ExecuteFinisher.Bind(this)
        ; Create SequenceEngine for each combo with finisher callback
        for comboName, steps in combos {
            engine := SequenceEngine(
                this.bus,
                "Meiko" . comboName,  ; Unique engine name
                steps,                 ; Combo sequence steps
                finisherCallback,      ; Finisher callback (called after completion)
                this.finisherDelay     ; 200ms delay before finisher execution
            )
            this.comboEngines[comboName] := engine
        }
    }

    ; ===== FINISHER CALLBACK =====
    ; Called 200ms after each combo completes
    ; Unconditionally executes finisher (no pixel check)
    ExecuteFinisher() {
        ; Send finisher key unconditionally
        Send this.finisherKey

        ; Emit event for tracking/debugging
        this.bus.Emit("FinisherExecuted", {
            timestamp: A_TickCount,
            mode: "auto-combo"
        })
    }

    ; ===== COMBO HOTKEY SETUP =====
    _SetupComboHotkeys() {
        ; Map hotkeys from CFG_* variables to combo names
        ; $ prefix prevents hotkey from triggering itself when Send is used
        hotkeyMap := Map(
            "$" . CFG_EARTH_DAMAGE_HOTKEY, "EarthDamageCombo",
            "$" . CFG_EARTH_BUFF_HOTKEY, "EarthBuffCombo",
            "$" . CFG_WIND_DAMAGE_HOTKEY, "WindDamageCombo",
            "$" . CFG_WIND_BUFF_HOTKEY, "WindBuffCombo",
            "$" . CFG_SPIRIT_BUFF1_HOTKEY, "SpiritBuff1Combo",
            "$" . CFG_SPIRIT_BUFF2_HOTKEY, "SpiritBuff2Combo"
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
        ; Start combo engines (always on, but only execute when hotkey pressed)
        ; Each engine has finisher callback integrated
        for comboName, engine in this.comboEngines {
            engine.Start()
        }

        ; Hotkey dispatcher starts when auto-combo is enabled (toggled with Alt+F1)

        ToolTip "Meiko Auto-Combo Started`nAlt+F1: Toggle Auto-Combo | F10: Exit"
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
            ToolTip "Auto-Combo: ON (includes finisher)"
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
        ToolTip "Shutting down Meiko Auto-Combo..."
        SetTimer () => ToolTip(), -1000

        ; Stop all engines
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
global meikoCombo := MeikoAutoCombo()
meikoCombo.Start()

; Keep script running
return