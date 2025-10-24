#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\Framework\RotationFramework.ahk

configPath := A_ScriptDir "\Configs\meiko.ini"
rotation := RotationFramework(configPath)

rotation.Start()

ToolTip "Meiko Rotation Loaded`nAuto-Finisher: ON (F1 to toggle)`nAuto-Combo: OFF (Alt+F1 to toggle)"
SetTimer () => ToolTip(), -3000

F10:: {
    global rotation
    rotation.Cleanup()
    ExitApp
}
