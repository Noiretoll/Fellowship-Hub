; DebugMonitor.ahk
; Optional debugging and event logging system for framework-based scripts
;
; Purpose: Provide real-time visibility into framework events for debugging and development
; Output Modes:
;   - Tooltip: Shows recent events in screen overlay (last 5 events)
;   - File: Logs all events to timestamped log file
;   - Both: Tooltip + File logging
;
; Common Events Monitored:
;   - HotkeyPressed: When registered hotkeys are pressed
;   - PixelStateChanged: When pixel conditions change
;   - FinisherExecuted: When finishers fire (character-specific)
;   - SequenceStarted/Complete: When combos execute
;   - WindowActive/Inactive: When game window focus changes
;   - StateChanged: When EventBus state changes
;
; Usage:
;   debug := DebugMonitor(bus, "tooltip")  ; Tooltip only
;   debug := DebugMonitor(bus, "file")     ; File logging only
;   debug := DebugMonitor(bus, "both")     ; Both modes
;   debug.Start()                          ; Begin monitoring
;   debug.Stop()                           ; Stop monitoring

#Requires AutoHotkey v2.0
#Include BaseEngine.ahk

class DebugMonitor extends BaseEngine {
    ; Configuration
    outputMode := "tooltip"      ; "tooltip", "file", or "both"
    logFilePath := ""            ; Path to log file (auto-generated)
    maxTooltipEvents := 5        ; Number of recent events to show in tooltip
    tooltipUpdateInterval := 100 ; Milliseconds between tooltip updates

    ; State
    eventHistory := []           ; Array of recent events for tooltip
    tooltipTimer := unset        ; Timer for tooltip updates
    logFile := unset             ; File handle for logging

    ; Constructor
    ; Parameters:
    ;   bus - EventBus instance
    ;   outputMode - "tooltip", "file", or "both" (default: "tooltip")
    ;   maxTooltipEvents - Number of events to show in tooltip (default: 5)
    __New(bus, outputMode := "tooltip", maxTooltipEvents := 5) {
        super.__New(bus, "DebugMonitor")

        ; Validate output mode
        if !(outputMode = "tooltip" || outputMode = "file" || outputMode = "both") {
            throw ValueError("outputMode must be 'tooltip', 'file', or 'both'", -1)
        }

        this.outputMode := outputMode
        this.maxTooltipEvents := maxTooltipEvents
        this.eventHistory := []

        ; Create log file if file logging enabled
        if (outputMode = "file" || outputMode = "both") {
            this._CreateLogFile()
        }
    }

    ; Start monitoring events
    Start() {
        super.Start()

        ; Subscribe to common framework events
        this._SubscribeToFrameworkEvents()

        ; Start tooltip update timer if tooltip mode enabled
        if (this.outputMode = "tooltip" || this.outputMode = "both") {
            this.tooltipTimer := this._UpdateTooltip.Bind(this)
            SetTimer(this.tooltipTimer, this.tooltipUpdateInterval)
        }

        ; Log startup
        this._LogEvent("DebugMonitor", "Started", {mode: this.outputMode})
    }

    ; Stop monitoring events
    Stop() {
        ; Log shutdown
        this._LogEvent("DebugMonitor", "Stopped", {})

        ; Stop tooltip timer
        if this.HasProp("tooltipTimer") {
            SetTimer(this.tooltipTimer, 0)
            this.DeleteProp("tooltipTimer")
            ToolTip()  ; Clear tooltip
        }

        ; Close log file
        if this.HasProp("logFile") {
            try {
                this.logFile.Close()
            }
            this.DeleteProp("logFile")
        }

        super.Stop()
    }

    ; Subscribe to all common framework events
    _SubscribeToFrameworkEvents() {
        ; HotkeyDispatcher events
        this.OnEvent("HotkeyPressed", this._OnHotkeyPressed.Bind(this))

        ; PixelMonitor events
        this.OnEvent("PixelStateChanged", this._OnPixelStateChanged.Bind(this))
        this.OnEvent("WindowActive", this._OnWindowActive.Bind(this))
        this.OnEvent("WindowInactive", this._OnWindowInactive.Bind(this))

        ; SequenceEngine events
        this.OnEvent("SequenceStarted", this._OnSequenceStarted.Bind(this))
        this.OnEvent("SequenceComplete", this._OnSequenceComplete.Bind(this))
        this.OnEvent("SequenceInterrupted", this._OnSequenceInterrupted.Bind(this))

        ; Character script events
        this.OnEvent("FinisherExecuted", this._OnFinisherExecuted.Bind(this))

        ; EventBus state changes
        this.OnEvent("StateChanged", this._OnStateChanged.Bind(this))
    }

    ; Event Handlers

    _OnHotkeyPressed(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Hotkey", data.action, {key: data.key})
    }

    _OnPixelStateChanged(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Pixel", data.name, {
            active: data.active,
            color: Format("0x{:06X}", data.color)
        })
    }

    _OnWindowActive(data := unset) {
        this._LogEvent("Window", "Active", {})
    }

    _OnWindowInactive(data := unset) {
        this._LogEvent("Window", "Inactive", {})
    }

    _OnSequenceStarted(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Sequence", "Started", {
            engine: data.engine,
            steps: data.stepCount
        })
    }

    _OnSequenceComplete(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Sequence", "Complete", {
            engine: data.engine,
            steps: data.steps
        })
    }

    _OnSequenceInterrupted(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Sequence", "Interrupted", {
            engine: data.engine,
            reason: data.reason
        })
    }

    _OnFinisherExecuted(data := unset) {
        if !IsSet(data)
            return
        this._LogEvent("Finisher", "Executed", {
            mode: data.HasOwnProp("mode") ? data.mode : "unknown"
        })
    }

    _OnStateChanged(data := unset) {
        if !IsSet(data)
            return

        ; Filter out noisy state changes (only log important ones)
        key := data.key
        if (key = "chatActive" || key = "windowActive" || key ~= "^pixel_") {
            this._LogEvent("State", key, {
                old: IsSet(data.oldValue) ? data.oldValue : "unset",
                new: data.newValue
            })
        }
    }

    ; Core logging function
    ; Parameters:
    ;   category - Event category (e.g., "Hotkey", "Pixel", "Sequence")
    ;   action - Event action (e.g., "Pressed", "Active", "Started")
    ;   details - Map/Object with additional details
    _LogEvent(category, action, details) {
        ; Create formatted timestamp
        timestamp := FormatTime(A_Now, "HH:mm:ss")

        ; Build event string
        eventStr := Format("[{1}] {2}: {3}", timestamp, category, action)

        ; Add details if present
        if IsObject(details) {
            detailStr := ""
            for key, value in details.OwnProps() {
                if (detailStr != "")
                    detailStr .= ", "
                detailStr .= key . "=" . value
            }
            if (detailStr != "")
                eventStr .= " (" . detailStr . ")"
        }

        ; Add to tooltip history
        if (this.outputMode = "tooltip" || this.outputMode = "both") {
            this.eventHistory.Push(eventStr)

            ; Keep only recent events
            while (this.eventHistory.Length > this.maxTooltipEvents) {
                this.eventHistory.RemoveAt(1)
            }
        }

        ; Write to log file
        if (this.outputMode = "file" || this.outputMode = "both") {
            this._WriteToFile(eventStr)
        }
    }

    ; Update tooltip display
    _UpdateTooltip() {
        if !this.isMonitoring
            return

        if (this.eventHistory.Length = 0) {
            ToolTip("DebugMonitor: No events yet")
            return
        }

        ; Build tooltip text from event history
        tooltipText := "=== DebugMonitor ===`n"
        for eventStr in this.eventHistory {
            tooltipText .= eventStr . "`n"
        }

        ; Show tooltip in top-left corner
        ToolTip(tooltipText, 10, 10)
    }

    ; Create log file with timestamp
    _CreateLogFile() {
        ; Create logs directory if it doesn't exist
        logDir := A_ScriptDir . "\Logs"
        if !DirExist(logDir) {
            DirCreate(logDir)
        }

        ; Create log file with timestamp
        timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        this.logFilePath := logDir . "\debug_" . timestamp . ".log"

        try {
            this.logFile := FileOpen(this.logFilePath, "a")
            this.logFile.WriteLine("=== DebugMonitor Log Started ===")
            this.logFile.WriteLine("Timestamp: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))
            this.logFile.WriteLine("Script: " . A_ScriptName)
            this.logFile.WriteLine("=====================================")
            this.logFile.WriteLine("")
        } catch Error as e {
            ; If file creation fails, disable file logging
            this.outputMode := "tooltip"
            throw ValueError("Failed to create log file: " . e.Message, -1)
        }
    }

    ; Write event to log file
    _WriteToFile(eventStr) {
        if !this.HasProp("logFile")
            return

        try {
            this.logFile.WriteLine(eventStr)
            this.logFile.Read(0)  ; Flush to disk
        } catch Error as e {
            ; Ignore write errors
        }
    }

    ; Destructor
    __Delete() {
        ; Clear tooltip
        ToolTip()

        ; Stop timer
        if this.HasProp("tooltipTimer") {
            SetTimer(this.tooltipTimer, 0)
            this.DeleteProp("tooltipTimer")
        }

        ; Close log file
        if this.HasProp("logFile") {
            try {
                this.logFile.WriteLine("")
                this.logFile.WriteLine("=== DebugMonitor Log Ended ===")
                this.logFile.Close()
            }
            this.DeleteProp("logFile")
        }

        super.__Delete()
    }
}
