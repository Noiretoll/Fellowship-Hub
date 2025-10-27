; BaseEngine.ahk
; Abstract base class for all engines using event-driven architecture
; Phase 2 of Event-Driven Architecture Rework

#Requires AutoHotkey v2.0
#Include EventBus.ahk

class BaseEngine extends Object {
    ; Properties
    bus := unset           ; EventBus reference (only external reference allowed)
    name := ""             ; Engine identifier
    isMonitoring := false  ; Engine state (running or stopped)
    subscriptions := []    ; Array of {eventName, handler} for cleanup

    ; Constructor
    ; Parameters:
    ;   bus - EventBus instance for all communication
    ;   name - String identifier for this engine (optional, default "")
    __New(bus, name := "") {
        ; Validate bus parameter
        if !IsObject(bus) {
            throw ValueError("Bus must be an EventBus object", -1)
        }

        ; Store parameters
        this.bus := bus
        this.name := name
        this.isMonitoring := false
        this.subscriptions := []
    }

    ; Start the engine (override in subclass)
    ; Subclasses should call super.Start() first, then add custom logic
    Start() {
        this.isMonitoring := true
        this.EmitEvent("EngineStarted", {name: this.name})
    }

    ; Stop the engine (override in subclass)
    ; Subclasses should call super.Stop() first, then add custom logic
    ; Unsubscribes from all events to allow clean restart with Start()
    Stop() {
        this.isMonitoring := false
        this.EmitEvent("EngineStopped", {name: this.name})

        ; Unsubscribe from all events
        for sub in this.subscriptions {
            this.bus.Unsubscribe(sub.eventName, sub.handler)
        }

        ; Clear subscriptions array
        this.subscriptions := []
    }

    ; Subscribe to an event with automatic tracking for cleanup
    ; Parameters:
    ;   eventName - Name of the event to subscribe to
    ;   handler - Function to call when event fires (must be regular function, not fat arrow)
    ;   priority - Priority for execution order (negative = high priority, 0 = normal, positive = low)
    ; Returns: true on success
    OnEvent(eventName, handler, priority := 0) {
        ; Validate parameters
        if !IsObject(handler) {
            throw ValueError("Handler must be a function object", -1)
        }

        ; Subscribe to bus
        this.bus.Subscribe(eventName, handler, priority)

        ; Track subscription for cleanup
        this.subscriptions.Push({eventName: eventName, handler: handler})

        return true
    }

    ; Emit an event to the bus
    ; Parameters:
    ;   eventName - Name of the event to emit
    ;   data - Event data (optional, use object literal {key: value} for structured data)
    EmitEvent(eventName, data := unset) {
        if IsSet(data) {
            this.bus.Emit(eventName, data)
        } else {
            this.bus.Emit(eventName)
        }
    }

    ; Get state value from the bus
    ; Parameters:
    ;   key - State key to retrieve
    ;   default - Default value if key doesn't exist (optional)
    ; Returns: State value or default
    GetState(key, default := unset) {
        if IsSet(default) {
            return this.bus.GetState(key, default)
        } else {
            return this.bus.GetState(key)
        }
    }

    ; Set state value in the bus
    ; Automatically emits "StateChanged" event
    ; Parameters:
    ;   key - State key to set
    ;   value - Value to store
    SetState(key, value) {
        this.bus.SetState(key, value)
    }

    ; Destructor - called when engine is destroyed
    ; Emits "EngineDeleted" event and cleans up all subscriptions
    __Delete() {
        ; Emit deletion event (before cleanup so subscribers can react)
        this.EmitEvent("EngineDeleted", {name: this.name})

        ; Unsubscribe from all events
        for sub in this.subscriptions {
            this.bus.Unsubscribe(sub.eventName, sub.handler)
        }

        ; Clear subscriptions array
        this.subscriptions := []

        ; Break reference to bus to allow proper cleanup
        ; NOTE: DeleteProp safely removes property, never use unset on properties
        this.DeleteProp("bus")
    }
}
