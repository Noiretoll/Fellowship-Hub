#Requires AutoHotkey v2.0

class PriorityEngine {
    ; Framework references - initialized in __New()
    framework := ""
    abilities := []
    cooldowns := Map()
    abilityEnabled := Map()
    abilityToggles := Map()

    ; State flags
    isMonitoring := false
    lastGCD := 0

    ; Timing configuration
    gcdDelay := 1050
    pollInterval := 50
    keyDelay := 30

    ; Control references
    monitorTimer := ""
    toggleHotkey := ""
    autoExecuteEngine := ""

    __New(framework) {
        this.framework := framework

        this.gcdDelay := framework.config.Has("gcdDelay") ?
            framework.config["gcdDelay"] : 1050

        this.pollInterval := framework.config.Has("pollInterval") ?
            framework.config["pollInterval"] : 50

        this._LoadAbilities()
        this._SetupHotkeys()
    }

    Start() {
        if this.isMonitoring
            return

        this.isMonitoring := true
        this.lastGCD := 0

        this.monitorTimer := ObjBindMethod(this, "MonitorLoop")
        SetTimer this.monitorTimer, this.pollInterval

        ToolTip "Priority Engine Started"
        SetTimer () => ToolTip(), -2000
    }

    Stop() {
        if !this.isMonitoring
            return

        this.isMonitoring := false

        if this.monitorTimer != ""
            SetTimer this.monitorTimer, 0

        this.lastGCD := 0
        this.cooldowns.Clear()

        ToolTip "Priority Engine Stopped"
        SetTimer () => ToolTip(), -2000
    }

    SetAutoExecuteEngine(engine) {
        this.autoExecuteEngine := engine
    }

    MonitorLoop() {
        if !this.isMonitoring
            return

        if this.framework.isChatActive
            return

        if !this.framework.IsGameActive()
            return

        if this.framework.state.Has("comboLocked") && this.framework.state["comboLocked"]
            return

        timeSinceGCD := A_TickCount - this.lastGCD
        if timeSinceGCD < this.gcdDelay
            return

        if this.autoExecuteEngine && this.autoExecuteEngine.isProcessing
            return

        ability := this._GetHighestPriorityAbility()
        if ability
            this._ExecuteAbility(ability)
    }

    Toggle(*) {
        if this.isMonitoring
            this.Stop()
        else
            this.Start()
    }

    _LoadAbilities() {
        configPath := this.framework.config["configPath"]

        for abilityName, ability in this.framework.abilities {
            if ability["type"] = "priority" || ability["priority"] > 0 {
                this.abilities.Push(ability)
                this.cooldowns[abilityName] := 0

                enabledValue := IniRead(configPath, "Ability_" . abilityName, "Enabled", "true")
                this.abilityEnabled[abilityName] := (enabledValue = "true" || enabledValue = "1")
            }
        }

        this.abilities := this._SortAbilitiesByPriority(this.abilities)
    }

    _SortAbilitiesByPriority(abilities) {
        sorted := abilities.Clone()

        for i, ability1 in sorted {
            for j, ability2 in sorted {
                if j <= i
                    continue

                if ability2["priority"] > ability1["priority"] {
                    temp := sorted[i]
                    sorted[i] := sorted[j]
                    sorted[j] := temp
                }
            }
        }

        return sorted
    }

    _GetHighestPriorityAbility() {
        for ability in this.abilities {
            if this._IsAbilityAvailable(ability)
                return ability
        }
        return ""
    }

    _IsAbilityAvailable(ability) {
        abilityName := ability["name"]

        if !this.abilityEnabled[abilityName]
            return false

        timeSinceCooldown := A_TickCount - this.cooldowns[abilityName]
        if timeSinceCooldown < ability["cooldown"]
            return false

        if ability["pixelTarget"] != "" {
            if !this.framework.CheckPixelCondition(ability["pixelTarget"])
                return false
        }

        return true
    }

    _ExecuteAbility(ability) {
        abilityName := ability["name"]

        if !this.framework.IsGameActive()
            return

        SendInput(ability["hotkey"])
        Sleep this.keyDelay

        this.lastGCD := A_TickCount
        this.cooldowns[abilityName] := A_TickCount
    }

    _SetupHotkeys() {
        configPath := this.framework.config["configPath"]

        toggleKey := IniRead(configPath, "Engine_Priority", "ToggleHotkey", "F1")
        if toggleKey != "" {
            this.toggleHotkey := toggleKey
            Hotkey(toggleKey, this.Toggle.Bind(this))
        }

        for ability in this.abilities {
            abilityName := ability["name"]
            abilityToggleKey := IniRead(configPath, "Ability_" . abilityName, "ToggleHotkey", "")

            if abilityToggleKey != "" {
                this.abilityToggles[abilityName] := abilityToggleKey
                Hotkey(abilityToggleKey, this._ToggleAbility.Bind(this, abilityName))
            }
        }
    }

    _ToggleAbility(abilityName, *) {
        if !this.abilityEnabled.Has(abilityName)
            return

        this.abilityEnabled[abilityName] := !this.abilityEnabled[abilityName]

        status := this.abilityEnabled[abilityName] ? "ON" : "OFF"
        ToolTip abilityName " " status
        SetTimer () => ToolTip(), -2000
    }

    __Delete() {
        this.Stop()

        if this.toggleHotkey != ""
            try Hotkey(this.toggleHotkey, "Off")

        for abilityName, toggleKey in this.abilityToggles {
            try Hotkey(toggleKey, "Off")
        }
    }
}
