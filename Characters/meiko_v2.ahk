;MEIKO FINISHER SCRIPT
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay -1
CoordMode "Pixel", "Screen"

; ===== ROTATION CONTROLLER =====
class MeikoRotation {
    static gameProcess := "fellowship-Win64-Shipping.exe"

    static Config := Map(
        "keyRegistrationDelay", 30,
        "monitorPollInterval", 50,
        "finisherSafetyDelay", 50,
        "finisherConfirmDelay", 100,
        "finisherFallbackDelay", 200,
        "tooltipDisplayDuration", 2000,
        "waitPollStep", 25,
        "chatToggleKey", "Enter",
        "chatCancelKey", "Escape"
    )

    static finisher := Map(
        "x", 1205,
        "y", 1119,
        "inactiveColor", 0x505050,
        "tolerance", 10
    )
    static rotation := Map(
        "gcdDelay", 1050,
        "segmentGap", 0
    )
    static comboTable := Map(
        "3", ["3", "1"],
        "!3", ["3", "2"],
        "1", ["1", "2"],
        "!1", ["1", "3"],
        "2", ["2", "1"],
        "!2", ["2", "3"]
    )
    static state := Map(
        "isMonitoring", false,
        "comboActive", false,
        "comboCancelRequested", false,
        "comboLocked", false,
        "isFinisherProcessing", false,
        "finisherPending", false,
        "activeComboHotkey", "",
        "isChatActive", false
    )
    static monitorTimer := ""

    static finisherX {
        get => this.finisher["x"]
        set => this.finisher["x"] := value
    }

    static finisherY {
        get => this.finisher["y"]
        set => this.finisher["y"] := value
    }

    static finisherInactiveColor {
        get => this.finisher["inactiveColor"]
        set => this.finisher["inactiveColor"] := value
    }

    static finisherTolerance {
        get => this.finisher["tolerance"]
        set => this.finisher["tolerance"] := value
    }

    static gcdDelay {
        get => this.rotation["gcdDelay"]
        set => this.rotation["gcdDelay"] := value
    }

    static segmentGap {
        get => this.rotation["segmentGap"]
        set => this.rotation["segmentGap"] := value
    }

    static isMonitoring {
        get => this.state["isMonitoring"]
        set => this.state["isMonitoring"] := value
    }

    static Init() {
        this.monitorTimer := ObjBindMethod(this, "MonitorLoop")
        for hotkeyName, keys in this.comboTable {
            Hotkey("$" . hotkeyName, ObjBindMethod(this, "RunCombo", keys, hotkeyName))
        }
    }

    ; ===== MONITOR TOGGLE =====
    static ToggleMonitoring() {
        this.isMonitoring := !this.isMonitoring

        if (this.isMonitoring) {
            ToolTip "Meiko Monitoring ON - Press F1 to stop"
            SetTimer () => ToolTip(), -this.Config["tooltipDisplayDuration"]
            SetTimer this.monitorTimer, this.Config["monitorPollInterval"]
        } else {
            ToolTip "Meiko Monitoring OFF"
            SetTimer () => ToolTip(), -this.Config["tooltipDisplayDuration"]
            SetTimer this.monitorTimer, 0
            ; Reset chat state when monitoring is disabled
            this.state["isChatActive"] := false
        }
    }

    ; ===== RESOURCE CLEANUP =====
    static Cleanup() {
        ; Stop monitor timer
        if (this.monitorTimer)
            SetTimer this.monitorTimer, 0

        ; Reset all state flags
        this.state["isMonitoring"] := false
        this.state["comboActive"] := false
        this.state["comboCancelRequested"] := false
        this.state["comboLocked"] := false
        this.state["isFinisherProcessing"] := false
        this.state["finisherPending"] := false
        this.state["activeComboHotkey"] := ""
        this.state["isChatActive"] := false
    }

    ; ===== CHAT MANAGEMENT =====
    static ToggleChat() {
        state := this.state
        state["isChatActive"] := !state["isChatActive"]

        if (state["isChatActive"]) {
            ; Clear pending finisher when entering chat
            state["finisherPending"] := false
            ToolTip "Chat Mode ON"
            SetTimer () => ToolTip(), -this.Config["tooltipDisplayDuration"]
        } else {
            ToolTip "Chat Mode OFF"
            SetTimer () => ToolTip(), -this.Config["tooltipDisplayDuration"]
        }
    }

    static HandleEscape() {
        state := this.state
        if (state["isChatActive"]) {
            state["isChatActive"] := false
            state["finisherPending"] := false
            ToolTip "Chat Cancelled"
            SetTimer () => ToolTip(), -this.Config["tooltipDisplayDuration"]
        }
    }

    static MonitorLoop() {
        state := this.state
        finisher := this.finisher

        if (!state["isMonitoring"])
            return

        if (state["isChatActive"])
            return

        if (!WinActive("ahk_exe " . this.gameProcess))
            return

        currentColor := PixelGetColor(finisher["x"], finisher["y"])
        if (!this.ColorMatch(currentColor, finisher["inactiveColor"], finisher["tolerance"]))
            this.TryExecuteFinisher()
    }

    ; ===== COMBO EXECUTION =====
    static RunCombo(keys, hotkeyName := "", *) {
        if !(keys is Array)
            return

        state := this.state

        if (state["isChatActive"])
            return

        if (state["comboLocked"])
            return

        state["comboLocked"] := true
        state["comboActive"] := true
        state["comboCancelRequested"] := false
        state["activeComboHotkey"] := this.NormalizeHotkey(hotkeyName != "" ? hotkeyName : A_ThisHotkey)

        segments := (keys.Length > 0 && keys[1] is Array) ? keys : [keys]
        rotation := this.rotation

        try {
            for index, segment in segments {
                if !(segment is Array)
                    continue

                if (this.TryExecuteFinisher(true))
                    break

                if (this.ExecuteSegment(segment))
                    break

                if (this.TryExecuteFinisher(true))
                    break

                if (index < segments.Length) {
                    if (this.WaitWithFinisher(rotation["gcdDelay"], true))
                        break

                    if (this.TryExecuteFinisher(true))
                        break

                    if (rotation["segmentGap"] > 0 && this.WaitWithFinisher(rotation["segmentGap"], true))
                        break

                    if (this.TryExecuteFinisher(true))
                        break
                }
            }
        } finally {
            this.FinishCombo()
        }
    }

    static ExecuteSegment(segment) {
        rotation := this.rotation
        for index, key in segment {
            if (this.SendComboStep(key))
                return true

            if (index < segment.Length) {
                if (this.WaitWithFinisher(rotation["gcdDelay"], true))
                    return true
            }
        }

        return false
    }

    static SendComboStep(key) {
        state := this.state
        if (state["comboCancelRequested"])
            return true

        if (state["isChatActive"])
            return true

        SendInput(key)
        Sleep this.Config["keyRegistrationDelay"]

        return false
    }

    static WaitWithFinisher(duration, allowFinisher := false) {
        state := this.state
        step := this.Config["waitPollStep"]
        endTime := A_TickCount + duration

        while true {
            if (state["isChatActive"])
                return true

            if (allowFinisher)
                this.TryExecuteFinisher(true)

            if (state["comboCancelRequested"])
                return true

            remaining := endTime - A_TickCount
            if (remaining <= 0)
                break

            sleepChunk := (remaining < step) ? remaining : step
            Sleep sleepChunk
        }

        return false
    }

    static FinishCombo() {
        state := this.state
        state["comboActive"] := false
        state["comboCancelRequested"] := false
        state["comboLocked"] := false
        state["activeComboHotkey"] := ""

        if (state["finisherPending"])
            this.TryExecuteFinisher()
    }

    static TryExecuteFinisher(force := false) {
        state := this.state
        finisher := this.finisher

        if (state["isFinisherProcessing"])
            return false

        if (!force && state["comboLocked"]) {
            state["finisherPending"] := true
            return false
        }

        currentColor := PixelGetColor(finisher["x"], finisher["y"])
        if (this.ColorMatch(currentColor, finisher["inactiveColor"], finisher["tolerance"])) {
            if (!force)
                state["finisherPending"] := false
            return false
        }

        state["finisherPending"] := false
        state["isFinisherProcessing"] := true

        Sleep this.Config["finisherSafetyDelay"]
        Send "``"
        Sleep this.Config["finisherConfirmDelay"]

        shouldCancel := false
        if (state["comboLocked"]) {
            state["comboCancelRequested"] := true
            shouldCancel := true
        }

        currentColor := PixelGetColor(finisher["x"], finisher["y"])
        if (this.ColorMatch(currentColor, finisher["inactiveColor"], finisher["tolerance"])) {
            Sleep this.Config["finisherFallbackDelay"]
        }

        state["isFinisherProcessing"] := false
        return shouldCancel
    }

    ; ===== UTILITIES =====
    static NormalizeHotkey(hotkey) {
        if (!hotkey)
            return ""

        hotkey := Trim(hotkey)
        while (SubStr(hotkey, 1, 1) = "$")
            hotkey := SubStr(hotkey, 2)

        return hotkey
    }

    static ColorMatch(color1, color2, tolerance) {
        r1 := (color1 >> 16) & 0xFF
        g1 := (color1 >> 8) & 0xFF
        b1 := color1 & 0xFF

        r2 := (color2 >> 16) & 0xFF
        g2 := (color2 >> 8) & 0xFF
        b2 := color2 & 0xFF

        return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
    }
}

; ===== INITIALIZE HOTKEYS =====
MeikoRotation.Init()

; Toggle monitoring with F1
F1:: {
    MeikoRotation.ToggleMonitoring()
}

; Exit script with F10
F10:: {
    MeikoRotation.Cleanup()
    ExitApp
}

; Chat key hooks with passthrough
$Enter:: {
    MeikoRotation.ToggleChat()
    Send "{Enter}"
}

$/:: {
    MeikoRotation.ToggleChat()
    Send "/"
}

$Escape:: {
    MeikoRotation.HandleEscape()
    Send "{Escape}"
}
