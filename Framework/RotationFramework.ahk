#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

#Include Engines\AutoExecuteEngine.ahk
#Include Engines\SequenceEngine.ahk
#Include Engines\PriorityEngine.ahk

class RotationFramework {
    config := Map()
    pixelTargets := Map()
    abilities := Map()
    state := Map()
    timers := Map()
    engines := Map()

    gameProcess := ""
    isRunning := false
    isChatActive := false

    __New(configPath) {
        this._LoadConfig(configPath)
        this._InitializeState()
        this._RegisterPixelTargets()
        this._RegisterAbilities()
    }

    Start() {
        if this.isRunning
            return

        this.isRunning := true
        this._InitializeEngines()
        this._StartChatProtection()

        for engineName, engine in this.engines {
            engine.Start()
        }

        ToolTip "Rotation Framework Started"
        SetTimer () => ToolTip(), -2000
    }

    Stop() {
        if !this.isRunning
            return

        this.isRunning := false

        for engineName, engine in this.engines {
            engine.Stop()
        }

        for timerName, timerFunc in this.timers {
            SetTimer timerFunc, 0
        }

        ToolTip "Rotation Framework Stopped"
        SetTimer () => ToolTip(), -2000
    }

    Cleanup() {
        this.Stop()

        this.config.Clear()
        this.pixelTargets.Clear()
        this.abilities.Clear()
        this.state.Clear()
        this.timers.Clear()
        this.engines.Clear()
    }

    __Delete() {
        this.Cleanup()
    }

    IsGameActive() {
        return WinActive("ahk_exe " . this.gameProcess)
    }

    CheckPixelCondition(targetName) {
        if !this.pixelTargets.Has(targetName)
            return false

        target := this.pixelTargets[targetName]
        currentColor := PixelGetColor(target["x"], target["y"])

        isMatch := this.ColorMatch(
            currentColor,
            target["activeColor"],
            target["tolerance"]
        )

        return target.Has("invert") && target["invert"] ? !isMatch : isMatch
    }

    ColorMatch(color1, color2, tolerance) {
        r1 := (color1 >> 16) & 0xFF
        g1 := (color1 >> 8) & 0xFF
        b1 := color1 & 0xFF

        r2 := (color2 >> 16) & 0xFF
        g2 := (color2 >> 8) & 0xFF
        b2 := color2 & 0xFF

        return (Abs(r1 - r2) <= tolerance)
            && (Abs(g1 - g2) <= tolerance)
            && (Abs(b1 - b2) <= tolerance)
    }

    _LoadConfig(configPath) {
        if !FileExist(configPath)
            throw Error("Config file not found: " . configPath)

        this.config["configPath"] := configPath
        this.gameProcess := IniRead(configPath, "Game", "Process", "fellowship-Win64-Shipping.exe")
        this.config["rotationType"] := IniRead(configPath, "General", "RotationType", "sequence")
        this.config["gcdDelay"] := Integer(IniRead(configPath, "General", "GCDDelay", "1050"))
        this.config["pollInterval"] := Integer(IniRead(configPath, "General", "PollInterval", "50"))
        this.config["chatToggleKey"] := IniRead(configPath, "General", "ChatToggleKey", "Enter")
        this.config["chatCancelKey"] := IniRead(configPath, "General", "ChatCancelKey", "Escape")
    }

    _InitializeState() {
        this.state["isMonitoring"] := false
        this.state["comboLocked"] := false
        this.state["inCombat"] := false
    }

    _RegisterPixelTargets() {
        configPath := this.config["configPath"]
        sections := this._GetIniSections(configPath)

        for section in sections {
            if InStr(section, "Pixel_") = 1 {
                targetName := SubStr(section, 7)

                target := Map(
                    "x", Integer(IniRead(configPath, section, "X", "0")),
                    "y", Integer(IniRead(configPath, section, "Y", "0")),
                    "activeColor", Integer(IniRead(configPath, section, "ActiveColor", "0x000000")),
                    "tolerance", Integer(IniRead(configPath, section, "Tolerance", "10"))
                )

                invertValue := IniRead(configPath, section, "Invert", "")
                if invertValue != ""
                    target["invert"] := (invertValue = "true" || invertValue = "1")

                this.pixelTargets[targetName] := target
            }
        }
    }

    _RegisterAbilities() {
        configPath := this.config["configPath"]
        sections := this._GetIniSections(configPath)

        for section in sections {
            if InStr(section, "Ability_") = 1 {
                abilityName := SubStr(section, 9)

                ability := Map(
                    "name", abilityName,
                    "hotkey", IniRead(configPath, section, "Hotkey", ""),
                    "type", IniRead(configPath, section, "Type", "normal"),
                    "pixelTarget", IniRead(configPath, section, "PixelTarget", ""),
                    "priority", Integer(IniRead(configPath, section, "Priority", "0")),
                    "cooldown", Integer(IniRead(configPath, section, "Cooldown", "0"))
                )

                sequence := IniRead(configPath, section, "Sequence", "")
                if sequence != ""
                    ability["sequence"] := StrSplit(sequence, ",")

                this.abilities[abilityName] := ability
            }
        }
    }

    _InitializeEngines() {
        ; ARCHITECTURE NOTE: Use direct Map assignment to avoid variable scope issues
        ; Store engines in this.engines Map - single source of truth
        ; Check Map.Has() instead of IsSet() to avoid AHK v2 scope ambiguity

        rotationType := this.config["rotationType"]

        ; Find and initialize auto-execute ability if present
        ; Store directly in Map with canonical key name
        for abilityName, ability in this.abilities {
            if ability["type"] = "auto_execute" {
                try {
                    engine := AutoExecuteEngine(this, abilityName)
                    this.engines["auto_execute"] := engine
                    break
                } catch Error as e {
                    MsgBox "Failed to initialize auto-execute ability: " . abilityName . "`n`n"
                        . "Error: " . e.Message . "`n"
                        . "File: " . e.File . "`n"
                        . "Line: " . e.Line . "`n`n"
                        . "Check your configuration file for this ability.",, "IconX"
                    throw e
                }
            }
        }

        ; Initialize primary rotation engine based on type
        ; Check Map directly for auto_execute engine
        switch rotationType {
            case "priority":
                engine := PriorityEngine(this)
                if this.engines.Has("auto_execute")
                    engine.SetAutoExecuteEngine(this.engines["auto_execute"])
                this.engines["priority"] := engine

            case "sequence":
                engine := SequenceEngine(this)
                if this.engines.Has("auto_execute")
                    engine.SetAutoExecuteEngine(this.engines["auto_execute"])
                this.engines["sequence"] := engine

            default:
                if !this.engines.Has("auto_execute")
                    throw Error("Unknown rotation type: " . rotationType)
        }
    }

    _StartChatProtection() {
        chatToggleKey := this.config["chatToggleKey"]
        chatCancelKey := this.config["chatCancelKey"]

        if chatToggleKey != "" {
            Hotkey("$" . chatToggleKey, this._HandleChatToggle.Bind(this))
            if chatToggleKey != "/"
                Hotkey("$/", this._HandleChatToggle.Bind(this))
        }

        if chatCancelKey != ""
            Hotkey("$" . chatCancelKey, this._HandleChatCancel.Bind(this))
    }

    _HandleChatToggle(*) {
        this.isChatActive := !this.isChatActive

        if this.isChatActive {
            ToolTip "Chat Mode ON"
            SetTimer () => ToolTip(), -2000
        } else {
            ToolTip "Chat Mode OFF"
            SetTimer () => ToolTip(), -2000
        }

        chatKey := A_ThisHotkey
        chatKey := StrReplace(chatKey, "$", "")
        Send "{" . chatKey . "}"
    }

    _HandleChatCancel(*) {
        if this.isChatActive {
            this.isChatActive := false
            ToolTip "Chat Cancelled"
            SetTimer () => ToolTip(), -2000
        }
        Send "{Escape}"
    }

    _GetIniSections(filePath) {
        sections := []

        try {
            fileContent := FileRead(filePath)
            lines := StrSplit(fileContent, "`n", "`r")

            for line in lines {
                line := Trim(line)
                if RegExMatch(line, "^\[(.+)\]$", &match)
                    sections.Push(match[1])
            }
        } catch as err {
            throw Error("Failed to read config file: " . err.Message)
        }

        return sections
    }
}
