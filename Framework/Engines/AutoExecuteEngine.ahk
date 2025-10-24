#Requires AutoHotkey v2.0

class AutoExecuteEngine {
    ; Framework references - initialized in __New()
    framework := ""
    ability := Map()
    pixelTarget := ""

    ; State flags
    isMonitoring := false
    isProcessing := false
    isPending := false

    ; Timing configuration
    pollInterval := 50
    safetyDelay := 50
    confirmDelay := 100
    fallbackDelay := 200

    ; Control references
    monitorTimer := ""
    toggleHotkey := ""

    __New(framework, abilityName) {
        ; Validate framework object
        if !IsObject(framework)
            throw Error("Framework parameter is not an object")

        if !framework.abilities.Has(abilityName)
            throw Error("Ability not found: " . abilityName)

        ; Set framework reference
        this.framework := framework

        ; Get ability configuration
        this.ability := framework.abilities[abilityName]

        ; Validate ability has pixelTarget field
        if !this.ability.Has("pixelTarget")
            throw Error("Ability '" . abilityName . "' is missing 'pixelTarget' field")

        this.pixelTarget := this.ability["pixelTarget"]

        ; Validate pixel target exists
        if this.pixelTarget = "" || !framework.pixelTargets.Has(this.pixelTarget)
            throw Error("Valid pixel target required for auto-execute ability: " . abilityName . "`nPixelTarget specified: '" . this.pixelTarget . "'")

        ; Set poll interval
        this.pollInterval := framework.config.Has("pollInterval") ?
            framework.config["pollInterval"] : 50

        ; Get enabled state from config
        if !framework.config.Has("configPath")
            throw Error("Framework config is missing 'configPath' field")

        configPath := framework.config["configPath"]
        enabledValue := IniRead(configPath, "Ability_" . abilityName, "Enabled", "true")
        this.isMonitoring := (enabledValue = "true" || enabledValue = "1")

        this._SetupHotkeys()
    }

    Start() {
        if this.isMonitoring
            return

        this.isMonitoring := true
        this.monitorTimer := ObjBindMethod(this, "MonitorLoop")
        SetTimer this.monitorTimer, this.pollInterval

        ToolTip "Auto-Execute ON - " . this.ability["name"]
        SetTimer () => ToolTip(), -2000
    }

    Stop() {
        if !this.isMonitoring
            return

        this.isMonitoring := false

        if this.monitorTimer != ""
            SetTimer this.monitorTimer, 0

        this.isPending := false
        this.isProcessing := false

        ToolTip "Auto-Execute OFF - " . this.ability["name"]
        SetTimer () => ToolTip(), -2000
    }

    MonitorLoop() {
        if !this.isMonitoring
            return

        if this.framework.isChatActive
            return

        if !this.framework.IsGameActive()
            return

        if this.isProcessing
            return

        if this.framework.CheckPixelCondition(this.pixelTarget)
            this.Execute()
    }

    Execute(force := false) {
        if this.isProcessing
            return false

        if !this.framework.IsGameActive()
            return false

        if !force && this.framework.state.Has("comboLocked") && this.framework.state["comboLocked"] {
            this.isPending := true
            return false
        }

        if !force && !this.framework.CheckPixelCondition(this.pixelTarget) {
            this.isPending := false
            return false
        }

        this.isPending := false
        this.isProcessing := true

        Sleep this.safetyDelay
        Send this.ability["hotkey"]
        Sleep this.confirmDelay

        shouldCancel := false
        if this.framework.state.Has("comboLocked") && this.framework.state["comboLocked"] {
            this.framework.state["comboCancelRequested"] := true
            shouldCancel := true
        }

        if this.framework.CheckPixelCondition(this.pixelTarget)
            Sleep this.fallbackDelay

        this.isProcessing := false
        return shouldCancel
    }

    Toggle(*) {
        if this.isMonitoring
            this.Stop()
        else
            this.Start()
    }

    _SetupHotkeys() {
        toggleKey := IniRead(
            this.framework.config["configPath"],
            "Ability_" . this.ability["name"],
            "ToggleHotkey",
            "F1"
        )

        if toggleKey != "" {
            this.toggleHotkey := toggleKey
            Hotkey(toggleKey, this.Toggle.Bind(this))
        }
    }

    __Delete() {
        this.Stop()

        if this.toggleHotkey != ""
            try Hotkey(this.toggleHotkey, "Off")
    }
}
