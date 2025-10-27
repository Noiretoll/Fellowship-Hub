; EventBus.ahk
; Core event subscription/emission system with zero dependencies
; Phase 1 of Event-Driven Architecture Rework

class EventBus {
    ; Properties
    subscribers := Map()  ; Map<eventName, Array<{callback, priority}>>
    state := Map()        ; Map<key, value> - Shared state storage

    ; Constructor
    __New() {
        this.subscribers := Map()
        this.state := Map()
    }

    ; Subscribe to an event with optional priority
    ; Higher priority (negative numbers) execute first
    ; Returns true on success
    Subscribe(eventName, callback, priority := 0) {
        ; Validate parameters
        if !IsObject(callback) {
            throw ValueError("Callback must be a function object", -1)
        }

        ; Create subscriber array if it doesn't exist
        if !this.subscribers.Has(eventName) {
            this.subscribers[eventName] := []
        }

        ; Add subscriber with priority
        subscribers := this.subscribers[eventName]
        subscribers.Push({callback: callback, priority: priority})

        ; Sort subscribers by priority (high to low)
        this._SortSubscribers(eventName)

        return true
    }

    ; Unsubscribe from an event
    ; Returns true if callback was found and removed, false otherwise
    Unsubscribe(eventName, callback) {
        ; Check if event has subscribers
        if !this.subscribers.Has(eventName) {
            return false
        }

        subscribers := this.subscribers[eventName]

        ; Find and remove the callback
        Loop subscribers.Length {
            index := A_Index
            sub := subscribers[index]

            ; Compare function objects using ObjPtr
            if ObjPtr(sub.callback) = ObjPtr(callback) {
                subscribers.RemoveAt(index)

                ; Clean up empty subscriber arrays
                if subscribers.Length = 0 {
                    this.subscribers.Delete(eventName)
                }

                return true
            }
        }

        return false
    }

    ; Emit an event to all subscribers
    ; Subscribers can return true to stop propagation
    Emit(eventName, eventData := unset) {
        ; Check if event has subscribers
        if !this.subscribers.Has(eventName) {
            return
        }

        subscribers := this.subscribers[eventName]

        ; Call each subscriber in priority order
        for sub in subscribers {
            ; Call with or without data parameter
            result := IsSet(eventData) ? sub.callback.Call(eventData) : sub.callback.Call()

            ; Stop propagation if callback returns true
            if result = true {
                return
            }
        }
    }

    ; Set state value and emit StateChanged event
    SetState(key, value) {
        ; Get old value if it exists
        oldValue := this.state.Has(key) ? this.state[key] : unset

        ; Set new value
        this.state[key] := value

        ; Emit StateChanged event
        this.Emit("StateChanged", {
            key: key,
            oldValue: IsSet(oldValue) ? oldValue : unset,
            newValue: value
        })
    }

    ; Get state value with optional default
    GetState(key, default := unset) {
        if this.state.Has(key) {
            return this.state[key]
        }

        if IsSet(default) {
            return default
        }

        throw ValueError("State key '" key "' not found and no default provided", -1)
    }

    ; Clear all subscribers and state
    Clear() {
        this.subscribers.Clear()
        this.state.Clear()
    }

    ; PRIVATE: Sort subscribers by priority (descending: highest priority first)
    ; Uses bubble sort - simple and adequate for small lists
    _SortSubscribers(eventName) {
        if !this.subscribers.Has(eventName) {
            return
        }

        subscribers := this.subscribers[eventName]
        n := subscribers.Length

        ; Bubble sort by priority (descending)
        Loop n {
            swapped := false

            Loop n - A_Index {
                i := A_Index

                ; Compare priorities: higher priority (more negative) comes first
                ; Sort ascending: -10, 0, 10 (negative values first)
                if subscribers[i].priority > subscribers[i + 1].priority {
                    ; Swap
                    temp := subscribers[i]
                    subscribers[i] := subscribers[i + 1]
                    subscribers[i + 1] := temp
                    swapped := true
                }
            }

            ; If no swaps occurred, array is sorted
            if !swapped {
                break
            }
        }
    }
}
