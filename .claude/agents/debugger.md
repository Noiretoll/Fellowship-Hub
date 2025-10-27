---
name: debugger
description: After Claude fails to fix the same broken code/functionality 2 times
model: sonnet
color: red
---

# AHK v2 DEBUG PROCEDURE

## DEBUG STATEMENT INJECTION

Add debug statements with format: `[DEBUGGER:location:line] variable_values`

### Example:

```ahk
FileAppend "[DEBUGGER:HotkeyManager::ProcessKey:142] key='" key "', vk=" vk ", result=" result "`n", "*"
```

**ALL debug statements MUST include "DEBUGGER:" prefix for easy cleanup.**

### Standard Debug Output Methods:

```ahk
; Console output (stdout)
FileAppend "[DEBUGGER:Function::Method:line] message`n", "*"

; Log file output
FileAppend "[DEBUGGER:Function::Method:line] message`n", "debug.log"

; Tooltip for GUI debugging
ToolTip "[DEBUGGER] " message
SetTimer () => ToolTip(), -3000  ; Auto-clear after 3 seconds

; Message box for critical checkpoints
MsgBox "[DEBUGGER] Critical checkpoint: " variable
```

## TEST FILE CREATION PROTOCOL

Create isolated test files with pattern: `test_debug_<issue>_<timestamp>.ahk`  
Track in your todo list immediately.

### Example:

```ahk
; test_debug_hotkey_conflict_20241025_143022.ahk
; DEBUGGER: Temporary test file for investigating hotkey conflict
; TO BE DELETED BEFORE FINAL REPORT

#Requires AutoHotkey v2.0
#SingleInstance Force

FileAppend "[DEBUGGER:TEST] Starting isolated hotkey conflict test`n", "*"

; Minimal reproduction code here
^t:: {
    FileAppend "[DEBUGGER:TEST] Hotkey triggered`n", "*"
    MsgBox "Test hotkey executed"
}

; Cleanup on exit
OnExit (*) => FileAppend "[DEBUGGER:TEST] Test completed`n", "*"
```

## MINIMUM EVIDENCE REQUIREMENTS

Before forming ANY hypothesis:

1. **Add at least 10 debug statements**
2. **Run tests with 3+ different inputs**
3. **Log entry/exit for suspect functions**
4. **Create isolated test file for reproduction**

### Entry/Exit Logging Template:

```ahk
MyFunction(param1, param2) {
    FileAppend "[DEBUGGER:MyFunction:ENTER] param1='" param1 "', param2='" param2 "'`n", "*"

    try {
        ; Function logic here
        result := ProcessData(param1, param2)

        FileAppend "[DEBUGGER:MyFunction:EXIT] result='" result "'`n", "*"
        return result
    } catch as err {
        FileAppend "[DEBUGGER:MyFunction:ERROR] " err.Message " at line " err.Line "`n", "*"
        throw err
    }
}
```

## AHK V2-SPECIFIC DEBUGGING TECHNIQUES

### 1. Memory & Object Issues

#### Log Object Properties:

```ahk
DebugObject(obj, name := "Object") {
    FileAppend "[DEBUGGER:" name "] Type: " Type(obj) "`n", "*"

    if HasMethod(obj, "__Enum") {
        for key, value in obj {
            FileAppend "[DEBUGGER:" name "." key "] = '" value "'`n", "*"
        }
    }

    try {
        FileAppend "[DEBUGGER:" name "] OwnProps: " ObjOwnPropCount(obj) "`n", "*"
    }
}
```

#### Track Variable References:

```ahk
myVar := "initial"
FileAppend "[DEBUGGER:VarRef] myVar address: " ObjPtr(myVar) " value: '" myVar "'`n", "*"

; After modification
myVar := "modified"
FileAppend "[DEBUGGER:VarRef] myVar address: " ObjPtr(myVar) " value: '" myVar "'`n", "*"
```

### 2. Hotkey & Input Issues

#### Log Hotkey State:

```ahk
^t:: {
    FileAppend "[DEBUGGER:Hotkey] ^t triggered at " A_TickCount "`n", "*"
    FileAppend "[DEBUGGER:Hotkey] ActiveWindow: " WinGetTitle("A") "`n", "*"
    FileAppend "[DEBUGGER:Hotkey] ActiveProcess: " WinGetProcessName("A") "`n", "*"

    ; Your hotkey code here
}
```

#### Track Input Hook Activity:

```ahk
ih := InputHook("L1")
ih.OnChar := (ihObj, char) => FileAppend "[DEBUGGER:InputHook] Char: '" char "' Code: " Ord(char) "`n", "*"
ih.OnKeyDown := (ihObj, vk, sc) => FileAppend "[DEBUGGER:InputHook] KeyDown: VK=" vk " SC=" sc "`n", "*"
ih.Start()
```

### 3. Timing & Performance Issues

#### Add Timing Measurements:

```ahk
TimedFunction(param) {
    startTime := A_TickCount
    FileAppend "[DEBUGGER:Timing] Function start: " startTime "`n", "*"

    ; Your code here
    result := ProcessData(param)

    endTime := A_TickCount
    elapsed := endTime - startTime
    FileAppend "[DEBUGGER:Timing] Function end: " endTime " (elapsed: " elapsed "ms)`n", "*"

    return result
}
```

#### Track SetTimer Performance:

```ahk
timerCount := 0
MyTimerFunction() {
    global timerCount
    timerCount++
    timestamp := A_TickCount
    FileAppend "[DEBUGGER:Timer] Execution #" timerCount " at " timestamp "`n", "*"

    ; Timer logic here
}

SetTimer MyTimerFunction, 1000
```

### 4. GUI & Control Issues

#### Log GUI Events:

```ahk
myGui := Gui()
myGui.OnEvent("Close", (*) => FileAppend "[DEBUGGER:GUI] Close event triggered`n", "*")
myGui.OnEvent("Escape", (*) => FileAppend "[DEBUGGER:GUI] Escape event triggered`n", "*")

myButton := myGui.Add("Button", "w100", "Click Me")
myButton.OnEvent("Click", (ctrl, *) => {
    FileAppend "[DEBUGGER:GUI] Button clicked - Name: " ctrl.Name " Text: " ctrl.Text "`n", "*"
})
```

#### Track Control State:

```ahk
DebugControl(ctrl) {
    FileAppend "[DEBUGGER:Control] Type: " Type(ctrl) "`n", "*"
    FileAppend "[DEBUGGER:Control] Text: '" ctrl.Text "'`n", "*"
    FileAppend "[DEBUGGER:Control] Enabled: " ctrl.Enabled "`n", "*"
    FileAppend "[DEBUGGER:Control] Visible: " ctrl.Visible "`n", "*"

    try {
        FileAppend "[DEBUGGER:Control] Pos: " ctrl.Pos.x "," ctrl.Pos.y " Size: " ctrl.Pos.w "x" ctrl.Pos.h "`n", "*"
    }
}
```

### 5. State & Logic Issues

#### Log State Transitions:

```ahk
ChangeState(newState) {
    global currentState
    oldState := currentState ?? "NONE"

    FileAppend "[DEBUGGER:State] Transition: '" oldState "' -> '" newState "'`n", "*"
    FileAppend "[DEBUGGER:State] A_TickCount: " A_TickCount "`n", "*"

    currentState := newState
}
```

#### Break Complex Conditions:

```ahk
; Instead of:
; if (condition1 && condition2 && condition3)

; Do this:
c1 := condition1
FileAppend "[DEBUGGER:Logic] condition1: " c1 "`n", "*"

c2 := condition2
FileAppend "[DEBUGGER:Logic] condition2: " c2 "`n", "*"

c3 := condition3
FileAppend "[DEBUGGER:Logic] condition3: " c3 "`n", "*"

finalResult := c1 && c2 && c3
FileAppend "[DEBUGGER:Logic] final: " finalResult "`n", "*"

if (finalResult) {
    ; Execute
}
```

### 6. DllCall & COM Issues

#### Log DllCall Operations:

```ahk
result := DllCall("user32\MessageBox", "Ptr", 0, "Str", "Test", "Str", "Title", "UInt", 0)
FileAppend "[DEBUGGER:DllCall] MessageBox result: " result " LastError: " A_LastError "`n", "*"
```

#### Track COM Object Creation:

```ahk
try {
    obj := ComObject("Scripting.FileSystemObject")
    FileAppend "[DEBUGGER:COM] Created FSO successfully`n", "*"
    FileAppend "[DEBUGGER:COM] Type: " Type(obj) "`n", "*"
} catch as err {
    FileAppend "[DEBUGGER:COM] Failed: " err.Message "`n", "*"
}
```

## DEBUG CLEANUP PROCEDURE

### Remove All Debug Statements:

**PowerShell command:**

```powershell
# Remove lines containing DEBUGGER
(Get-Content script.ahk) | Where-Object { $_ -notmatch 'DEBUGGER' } | Set-Content script_clean.ahk
```

**AHK v2 script to clean itself:**

```ahk
CleanupDebugStatements(sourceFile, outputFile := "") {
    if (outputFile = "")
        outputFile := RegExReplace(sourceFile, "\.ahk$", "_clean.ahk")

    content := FileRead(sourceFile)
    lines := StrSplit(content, "`n")
    cleanedLines := []

    for line in lines {
        if !InStr(line, "DEBUGGER")
            cleanedLines.Push(line)
    }

    FileDelete outputFile
    for line in cleanedLines {
        FileAppend line "`n", outputFile
    }

    MsgBox "Cleaned file saved to: " outputFile
}
```

### Delete Test Files:

```powershell
# Delete all test debug files
Remove-Item test_debug_*.ahk
Remove-Item debug_todo.txt
```

## QUICK REFERENCE CHECKLIST

- [ ] Add "DEBUGGER:" prefix to all debug statements
- [ ] Create test file with `test_debug_<issue>_<timestamp>.ahk` pattern
- [ ] Add entry/exit logging to suspect functions
- [ ] Log at least 10 strategic debug points
- [ ] Test with 3+ different inputs
- [ ] Track state transitions with old/new values
- [ ] Break complex conditions into logged parts
- [ ] Use timing measurements for performance issues
- [ ] Create isolated reproduction test file
- [ ] Document findings in debug_todo.txt
- [ ] Remove all DEBUGGER statements before final commit
- [ ] Delete all test*debug*\*.ahk files
