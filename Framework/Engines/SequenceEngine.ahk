#Requires AutoHotkey v2.0

class SequenceEngine {
    ; Framework references - initialized in __New()
    framework := ""
    sequences := Map()

    ; State flags
    isEnabled := false
    isLocked := false
    cancelRequested := false

    ; Timing configuration
    gcdDelay := 1050
    keyDelay := 30
    waitPollStep := 25

    ; Control references
    toggleHotkey := ""
    autoExecuteEngine := ""

    __New(framework) {
        this.framework := framework

        this.gcdDelay := framework.config.Has("gcdDelay") ?
            framework.config["gcdDelay"] : 1050

        this._LoadSequences()
        this._SetupHotkeys()
    }

    Start() {
        if this.isEnabled
            return

        this.isEnabled := true

        ToolTip "Sequence Engine Started"
        SetTimer () => ToolTip(), -2000
    }

    Stop() {
        if !this.isEnabled
            return

        this.isEnabled := false
        this.isLocked := false
        this.cancelRequested := false

        ToolTip "Sequence Engine Stopped"
        SetTimer () => ToolTip(), -2000
    }

    SetAutoExecuteEngine(engine) {
        this.autoExecuteEngine := engine
    }

    RunSequence(abilityName, *) {
        if !this.sequences.Has(abilityName)
            return

        if !this.isEnabled
            return

        if this.framework.isChatActive
            return

        if !this.framework.IsGameActive()
            return

        if this.isLocked
            return

        sequence := this.sequences[abilityName]

        this.isLocked := true
        this.framework.state["comboLocked"] := true
        this.framework.state["comboActive"] := true
        this.cancelRequested := false

        try {
            this._ExecuteSequence(sequence)
        } finally {
            this._FinishSequence()
        }
    }

    Toggle(*) {
        if this.isEnabled
            this.Stop()
        else
            this.Start()
    }

    _LoadSequences() {
        for abilityName, ability in this.framework.abilities {
            if ability["type"] != "sequence" && !ability.Has("sequence")
                continue

            if !ability.Has("sequence")
                continue

            this.sequences[abilityName] := ability
        }
    }

    _SetupHotkeys() {
        configPath := this.framework.config["configPath"]

        toggleKey := IniRead(configPath, "Engine_Sequence", "ToggleHotkey", "!F1")
        if toggleKey != "" {
            this.toggleHotkey := toggleKey
            Hotkey(toggleKey, this.Toggle.Bind(this))
        }

        for abilityName, ability in this.sequences {
            triggerKey := ability["hotkey"]
            if triggerKey != ""
                Hotkey("$" . triggerKey, this.RunSequence.Bind(this, abilityName))
        }
    }

    _ExecuteSequence(ability) {
        if !ability.Has("sequence")
            return

        sequence := ability["sequence"]

        for index, key in sequence {
            key := Trim(key)

            if this._CheckInterrupt()
                break

            if this._SendKey(key)
                break

            if index < sequence.Length {
                if this._WaitWithChecks(this.gcdDelay)
                    break

                if this._CheckInterrupt()
                    break
            }
        }
    }

    _SendKey(key) {
        if this.cancelRequested
            return true

        if this.framework.isChatActive
            return true

        if !this.framework.IsGameActive()
            return true

        SendInput(key)
        Sleep this.keyDelay

        return false
    }

    _WaitWithChecks(duration) {
        endTime := A_TickCount + duration

        while true {
            if this.framework.isChatActive
                return true

            if this._CheckInterrupt()
                return true

            if this.cancelRequested
                return true

            remaining := endTime - A_TickCount
            if remaining <= 0
                break

            sleepChunk := (remaining < this.waitPollStep) ? remaining : this.waitPollStep
            Sleep sleepChunk
        }

        return false
    }

    _CheckInterrupt() {
        if !this.autoExecuteEngine
            return false

        if !this.autoExecuteEngine.isMonitoring
            return false

        if this.framework.CheckPixelCondition(this.autoExecuteEngine.pixelTarget) {
            this.autoExecuteEngine.Execute(true)
            return true
        }

        return false
    }

    _FinishSequence() {
        this.framework.state["comboActive"] := false
        this.framework.state["comboLocked"] := false
        this.cancelRequested := false
        this.isLocked := false

        if this.autoExecuteEngine && this.autoExecuteEngine.isPending {
            this.autoExecuteEngine.isPending := false
            this.autoExecuteEngine.Execute()
        }
    }

    __Delete() {
        this.Stop()

        if this.toggleHotkey != ""
            try Hotkey(this.toggleHotkey, "Off")

        for abilityName, ability in this.sequences {
            triggerKey := ability["hotkey"]
            if triggerKey != ""
                try Hotkey("$" . triggerKey, "Off")
        }
    }
}
