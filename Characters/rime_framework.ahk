; rime_framework.ahk
; Rime character script
; Controls:
;   Alt+F1   - Toggle auto-rotation ON/OFF (default: OFF)
;   F10      - Exit script

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; Include framework components
#Include ..\Framework\EventBus.ahk
#Include ..\Framework\BaseEngine.ahk
#Include ..\Framework\HotkeyDispatcher.ahk
#Include ..\Framework\SequenceEngine.ahk

; ===== RIME CHARACTER CONFIGURATION =====
class RimeCharacter {
    ; Framework components
    bus := ""
    hotkeyDispatcher := ""
    sequenceEngines := Map()

    ; Configuration
    gameProcess := "fellowship-Win64-Shipping.exe"
    gcdDelay := 1050

    autoRotationEnabled := false ; Auto-rotation disabled by default
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
        this._SetupSequenceEngines()
        this._SetupHotkeys()
        this._SetupChatProtection()
        this._SetupToggleHotkeys()

        ; Subscribe to events for sequence triggering
        this.bus.Subscribe("HotkeyPressed", this.HandleHotkeyPress.Bind(this))
    }

    ; ===== SEQUENCE ENGINE SETUP =====
    _SetupSequenceEngines() {
        ; Define all key sequences
        ; Format: [{key: "1", delay: 1050}, {key: "2", delay: 0}]
        ; delay = milliseconds to wait AFTER sending key
        ; Configure your specific sequences here
        ; Each sequence will be triggered by a hotkey defined in _SetupHotkeys()

        sequences := Map(
            ; Sequences (CUSTOMIZE HERE)
            "Burst", [{ key: "{Numpad2}", delay: 5 }, { key: "q", delay: 15 }, { key: "x", delay: 0 }],
            "BigBurst", [{ key: "{Shift down}", delay: 20 }, { key: "q", delay: 1400 }, { key: "{Shift up}", delay: 0 }, { key: "{Numpad2}",
                delay: 5 }, { key: "q", delay: 10 }, { key: "x", delay: 0 }]
        )

        for sequenceName, steps in sequences {
            engine := SequenceEngine(
                this.bus,
                "Rime" . sequenceName,
                steps
            )
            this.sequenceEngines[sequenceName] := engine
        }
    }
    ; ===== HOTKEY SETUP =====
    _SetupHotkeys() {
        ; Map hotkeys to sequence names
        ; $ prefix prevents hotkey from triggering itself when Send is used
        ; TODO: Configure your hotkey bindings here
        ; Each hotkey maps to a sequence name from _SetupSequenceEngines()

        hotkeyMap := Map(
            ; Rotation Hotkeys (CUSTOMIZE HERE)
            "$q", "Burst",
            "$z", "BigBurst"
        )

        this.hotkeyDispatcher := HotkeyDispatcher(
            this.bus,
            hotkeyMap,
            this.gameProcess
        )
    }
    ; ===== CHAT PROTECTION =====
    _SetupChatProtection() {

        this.chatEnterCallback := (*) => this.ToggleChat("Enter")
        Hotkey("$Enter", this.chatEnterCallback)

        this.chatSlashCallback := (*) => this.ToggleChat("/")
        Hotkey("$/", this.chatSlashCallback)

        this.chatEscapeCallback := (*) => this.CancelChat()
        Hotkey("$Escape", this.chatEscapeCallback)
    }
    ; ===== TOGGLE HOTKEY SETUP =====
    _SetupToggleHotkeys() {
        ; Alt+F1 - Toggle auto-rotation
        Hotkey("!F1", (*) => this.ToggleAutoRotation())

        ; F10 - Exit script
        Hotkey("F10", (*) => this.Cleanup())
    }
    ; ===== START ALL SYSTEMS =====
    Start() {

        for sequenceName, engine in this.sequenceEngines {
            engine.Start()
        }

        ToolTip "Rime Script Started`nAlt+F1: Toggle Auto-Rotation | F10: Exit"
        SetTimer () => ToolTip(), -3000
    }
    ; ===== HOTKEY HANDLERS =====

    HandleHotkeyPress(data := unset) {
        if !IsSet(data) {
            return
        }

        if !this.autoRotationEnabled {
            return
        }

        sequenceName := data.action

        if !this.sequenceEngines.Has(sequenceName) {
            return
        }

        engine := this.sequenceEngines[sequenceName]
        engine.ExecuteSequence()
    }

    ToggleAutoRotation() {
        this.autoRotationEnabled := !this.autoRotationEnabled

        if this.autoRotationEnabled {
            this.hotkeyDispatcher.Start()
            ToolTip "Auto-Rotation: ON"
        } else {
            this.hotkeyDispatcher.Stop()
            ToolTip "Auto-Rotation: OFF"
        }

        SetTimer () => ToolTip(), -2000
    }

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

        Send "{" . key . "}"
    }

    CancelChat() {
        if this.chatActive {
            this.chatActive := false
            this.bus.SetState("chatActive", false)

            ToolTip "Chat Cancelled"
            SetTimer () => ToolTip(), -2000
        }

        Send "{Escape}"
    }
    ; ===== CLEANUP =====
    Cleanup() {
        ToolTip "Shutting down Rime script..."
        SetTimer () => ToolTip(), -1000

        for sequenceName, engine in this.sequenceEngines {
            engine.Stop()
        }

        if IsObject(this.hotkeyDispatcher) {
            this.hotkeyDispatcher.Stop()
        }

        try {
            Hotkey("$Enter", "Off")
            Hotkey("$/", "Off")
            Hotkey("$Escape", "Off")
            Hotkey("!F1", "Off")
            Hotkey("F10", "Off")
        } catch {

        }

        if IsObject(this.bus) {
            this.bus.Clear()
        }

        SetTimer () => ExitApp(), -1000
    }

    __Delete() {
        this.Cleanup()
    }
}

; ===== INITIALIZE AND START =====
global rime := RimeCharacter()
rime.Start()

return