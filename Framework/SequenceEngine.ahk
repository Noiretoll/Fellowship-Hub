; SequenceEngine.ahk
; Generic step sequencer with configurable action sequences and optional post-sequence callback
; Phase 6: Event-Driven Generic Architecture (no character-specific logic)
; Post-Phase 8: Finisher integration pattern
;
; Purpose: Execute sequences of keypresses with configurable delays, optionally executing
;          a finisher action after sequence completes (e.g., Meiko finisher after 2-step combo)

#Requires AutoHotkey v2.0
#Include BaseEngine.ahk

class SequenceEngine extends BaseEngine {
    ; Configuration properties
    steps := []            ; Array of step objects: [{key: "1", delay: 1050}, ...]
    finisherCallback := "" ; Optional callback function to check/execute finisher after completion
    finisherDelay := 10    ; Delay in ms before calling finisher callback (default: 10ms)

    ; State flags
    sequenceActive := false  ; True during sequence execution
    currentStep := 0         ; Current step index (1-based)

    ; Constructor
    ; Parameters:
    ;   bus              - EventBus reference for all communication
    ;   name             - Engine identifier (any string, e.g., "MeikoCombo", "TiraqRotation")
    ;   steps            - Array of step objects [{key: "1", delay: 1050}, {key: "2", delay: 10}, ...]
    ;   finisherCallback - Optional function to call after sequence completes (for finisher detection/execution)
    ;   finisherDelay    - Delay in ms before calling finisher callback (default: 10ms)
    __New(bus, name, steps := [], finisherCallback := "", finisherDelay := 10) {
        ; Call parent constructor
        super.__New(bus, name)

        ; Validate and store steps
        if !IsObject(steps) {
            throw ValueError("steps must be an array", -1)
        }

        this.steps := steps
        this.finisherCallback := finisherCallback
        this.finisherDelay := finisherDelay
        this.sequenceActive := false
        this.currentStep := 0
    }

    ; Start monitoring (enables sequence execution)
    Start() {
        ; Call parent Start (sets isMonitoring, emits EngineStarted)
        super.Start()
    }

    ; Stop monitoring (disables sequence execution)
    Stop() {
        ; Interrupt any active sequence
        if this.sequenceActive {
            this.InterruptSequence("Engine stopped")
        }

        ; Call parent Stop (sets isMonitoring false, unsubscribes all, emits EngineStopped)
        super.Stop()
    }

    ; Execute the configured sequence
    ; If a sequence is already running, it will be interrupted and restarted
    ExecuteSequence() {
        ; Skip if not monitoring
        if !this.isMonitoring {
            return
        }

        ; Check protection guards via state
        if this.GetState("chatActive", false) {
            return
        }

        if !this.GetState("windowActive", true) {
            return
        }

        ; Interrupt existing sequence if running (immediate restart pattern)
        if this.sequenceActive {
            this.InterruptSequence("New sequence requested")
        }

        ; Start new sequence
        this.sequenceActive := true
        this.currentStep := 1

        ; Emit sequence started event
        this.EmitEvent("SequenceStarted", {
            engine: this.name,
            stepCount: this.steps.Length
        })

        ; Begin execution
        this._ExecuteNextStep()
    }

    ; Execute next step in sequence (recursive timer pattern)
    _ExecuteNextStep() {
        ; Check if sequence was interrupted
        if !this.sequenceActive {
            return
        }

        ; Check if sequence is complete
        if this.currentStep > this.steps.Length {
            this._CompleteSequence()
            return
        }

        ; Get current step
        step := this.steps[this.currentStep]

        ; Emit step event
        this.EmitEvent("SequenceStep", {
            engine: this.name,
            step: this.currentStep,
            key: step.key
        })

        ; Execute step (send key)
        Send step.key

        ; Move to next step
        this.currentStep++

        ; Schedule next step with delay (or execute immediately if delay = 0)
        if step.delay > 0 {
            ; Use one-time timer (negative period) for next step
            SetTimer(() => this._ExecuteNextStep(), -step.delay)
        } else {
            ; Execute immediately (no delay)
            this._ExecuteNextStep()
        }
    }

    ; Interrupt current sequence
    ; Parameters:
    ;   reason - String describing why sequence was interrupted
    InterruptSequence(reason) {
        ; Only interrupt if sequence is active
        if !this.sequenceActive {
            return
        }

        ; Emit interruption event
        this.EmitEvent("SequenceInterrupted", {
            engine: this.name,
            step: this.currentStep,
            reason: reason
        })

        ; Clear sequence state
        this.sequenceActive := false
        this.currentStep := 0
    }

    ; Complete sequence successfully
    _CompleteSequence() {
        ; Emit completion event
        this.EmitEvent("SequenceComplete", {
            engine: this.name,
            steps: this.steps.Length
        })

        ; Reset state
        this.sequenceActive := false
        this.currentStep := 0

        ; Execute finisher callback if provided
        ; Pattern: Wait finisherDelay ms, then call callback to check/execute finisher
        ; Used for Meiko: After 2nd combo key pressed, wait 200ms, check pixel, send finisher if ready
        if IsObject(this.finisherCallback) {
            ; Use one-time timer for delay (negative period = run once)
            SetTimer(() => this._ExecuteFinisher(), -this.finisherDelay)
        }
    }

    ; Execute finisher callback (called after finisherDelay)
    _ExecuteFinisher() {
        ; Check protection guards
        if this.GetState("chatActive", false) {
            return
        }

        if !this.GetState("windowActive", true) {
            return
        }

        ; Call the finisher callback
        ; Callback should check pixel condition and send finisher key if ready
        try {
            this.finisherCallback.Call()
        } catch Error as e {
            ; Emit error event but don't crash
            this.EmitEvent("FinisherError", {
                engine: this.name,
                error: e.Message
            })
        }
    }

    ; Destructor - cleanup
    __Delete() {
        ; Interrupt any active sequence
        if this.sequenceActive {
            this.InterruptSequence("Engine deleted")
        }

        ; Call parent destructor (emits EngineDeleted, cleans subscriptions, removes bus)
        super.__Delete()
    }
}
