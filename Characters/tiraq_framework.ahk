#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\Framework\RotationFramework.ahk

configPath := A_ScriptDir "\Configs\tiraq.ini"
rotation := RotationFramework(configPath)

rotation.Start()
rotation.Stop()

ToolTip "Tiraq Rotation Loaded`nPress F1 to start monitoring`nAlt+F1 to enable Thunder Call"
SetTimer () => ToolTip(), -3000

F10:: {
    global rotation
    rotation.Cleanup()
    ExitApp
}
