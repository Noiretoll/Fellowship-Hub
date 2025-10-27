; PriorityEngine.ahk
; Generic priority-based rotation engine with configurable ability priority queue
; Phase 7: Event-Driven Generic Architecture (no character-specific logic)

#Requires AutoHotkey v2.0
#Include ..\BaseEngine.ahk

class PriorityEngine extends BaseEngine {
    ; Configuration properties
    abilities := []        ; Array of ability objects (sorted by priority, descending)
    pollInterval := 100    ; How often to check rotation (ms)
    gcdDelay := 1500       ; Global cooldown duration (ms)

    ; Timer reference for cleanup
    timer := unset

    ; Constructor
    ; Parameters:
    ;   bus          - EventBus reference for all communication
    ;   name         - Engine identifier (any string, e.g., "TiraqRotation")
    ;   abilities    - Array of ability objects [{name, priority, keybind, cooldown}, ...]
    ;   pollInterval - How often to check rotation (ms, default 100)
    ;   gcdDelay     - GCD duration in milliseconds (default 1500)
    __New(bus, name, abilities := [], pollInterval := 100, gcdDelay := 1500) {
        ; Call parent constructor
        super.__New(bus, name)

        ; Validate parameters
        if !IsObject(abilities) {
            throw ValueError("abilities must be an array", -1)
        }

        ; Store configuration
        this.pollInterval := pollInterval
        this.gcdDelay := gcdDelay

        ; Initialize abilities with default values and sort by priority
        this.abilities := this._InitializeAbilities(abilities)
    }

    ; Initialize abilities with default values and sort by priority
    ; Ensures all abilities have required properties and sorts descending by priority
    _InitializeAbilities(abilities) {
        initialized := []

        ; Add default values to each ability
        for ability in abilities {
            ; Validate required properties
            if !ability.HasProp("name") || ability.name = "" {
                throw ValueError("Each ability must have a non-empty 'name' property", -1)
            }
            if !ability.HasProp("priority") {
                throw ValueError("Ability '" ability.name "' missing 'priority' property", -1)
            }
            if !ability.HasProp("keybind") || ability.keybind = "" {
                throw ValueError("Ability '" ability.name "' missing 'keybind' property", -1)
            }
            if !ability.HasProp("cooldown") {
                throw ValueError("Ability '" ability.name "' missing 'cooldown' property", -1)
            }

            ; Initialize runtime properties
            if !ability.HasProp("lastUsed") {
                ability.lastUsed := 0  ; Never used
            }
            if !ability.HasProp("enabled") {
                ability.enabled := true  ; Default enabled
            }

            initialized.Push(ability)
        }

        ; Sort by priority (descending - higher priority first)
        return this._SortAbilitiesByPriority(initialized)
    }

    ; Sort abilities by priority using bubble sort (higher priority = lower index)
    _SortAbilitiesByPriority(abilities) {
        sorted := abilities.Clone()
        n := sorted.Length

        ; Bubble sort - outer loop
        loop n - 1 {
            swapped := false

            ; Inner loop
            loop n - A_Index {
                i := A_Index
                ; Compare priorities (descending order)
                if sorted[i + 1].priority > sorted[i].priority {
                    ; Swap
                    temp := sorted[i]
                    sorted[i] := sorted[i + 1]
                    sorted[i + 1] := temp
                    swapped := true
                }
            }

            ; If no swaps occurred, array is sorted
            if !swapped {
                break
            }
        }

        return sorted
    }

    ; Start monitoring rotation
    ; Creates timer that emits RotationTick events for rotation checking
    Start() {
        ; Call parent Start (sets isMonitoring, emits EngineStarted)
        super.Start()

        ; Subscribe to own RotationTick events
        this.OnEvent("RotationTick", this.OnRotationTick.Bind(this))

        ; Start self-timer that emits RotationTick events
        this.timer := () => this.EmitEvent("RotationTick", {engine: this.name})
        SetTimer(this.timer, this.pollInterval)
    }

    ; Stop monitoring rotation
    ; Stops timer and unsubscribes from events
    Stop() {
        ; Call parent Stop (sets isMonitoring false, unsubscribes all, emits EngineStopped)
        super.Stop()

        ; Stop timer if it exists
        if this.HasProp("timer") {
            SetTimer(this.timer, 0)
            this.DeleteProp("timer")
        }
    }

    ; Handle RotationTick event (self-emitted)
    ; Finds highest priority ready ability and executes it
    OnRotationTick(data := unset) {
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

        ; Check GCD state (managed externally or by this engine)
        if this.GetState("gcdActive", false) {
            return
        }

        ; Find highest priority ready ability
        ability := this._GetHighestPriorityAbility()

        ; Execute if found
        if IsObject(ability) {
            this._ExecuteAbility(ability)
        }
    }

    ; Find the highest priority ability that is ready to use
    ; Returns ability object or "" if none available
    _GetHighestPriorityAbility() {
        ; Abilities already sorted by priority (descending)
        for ability in this.abilities {
            if this._IsAbilityReady(ability) {
                return ability
            }
        }

        return ""
    }

    ; Check if an ability is ready to use
    ; Checks: enabled flag, cooldown, pixel condition (if specified)
    _IsAbilityReady(ability) {
        ; Check enabled flag
        if !ability.enabled {
            return false
        }

        ; Check cooldown
        timeSinceUse := A_TickCount - ability.lastUsed
        if timeSinceUse < ability.cooldown {
            return false
        }

        ; Check pixel condition if specified
        if ability.HasProp("pixelTarget") && ability.pixelTarget != "" {
            pixelStateKey := "pixel_" . ability.pixelTarget
            if !this.GetState(pixelStateKey, false) {
                return false
            }
        }

        return true
    }

    ; Execute an ability
    ; Sends keybind, updates cooldown, sets GCD state, emits event
    _ExecuteAbility(ability) {
        ; Emit pre-execution event
        this.EmitEvent("AbilityUsed", {
            engine: this.name,
            ability: ability.name,
            keybind: ability.keybind,
            priority: ability.priority
        })

        ; Send keybind
        Send ability.keybind

        ; Update ability cooldown timestamp
        ability.lastUsed := A_TickCount

        ; Set GCD state (will be cleared after gcdDelay)
        this.SetState("gcdActive", true)
        SetTimer(() => this.SetState("gcdActive", false), -this.gcdDelay)
    }

    ; Enable an ability by name
    EnableAbility(abilityName) {
        for ability in this.abilities {
            if ability.name = abilityName {
                ability.enabled := true
                return
            }
        }
    }

    ; Disable an ability by name
    DisableAbility(abilityName) {
        for ability in this.abilities {
            if ability.name = abilityName {
                ability.enabled := false
                return
            }
        }
    }

    ; Toggle an ability by name
    ToggleAbility(abilityName) {
        for ability in this.abilities {
            if ability.name = abilityName {
                ability.enabled := !ability.enabled
                return ability.enabled
            }
        }
        return false
    }

    ; Destructor - cleanup timer
    __Delete() {
        ; Stop timer if it exists
        if this.HasProp("timer") {
            SetTimer(this.timer, 0)
            this.DeleteProp("timer")
        }

        ; Call parent destructor (emits EngineDeleted, cleans subscriptions, removes bus)
        super.__Delete()
    }
}
