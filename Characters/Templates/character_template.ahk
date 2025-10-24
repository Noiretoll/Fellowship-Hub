#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ../../Framework/RotationFramework.ahk

configPath := A_ScriptDir "\..\Configs\character_name.ini"
rotation := RotationFramework(configPath)

rotation.Start()

F10:: {
    global rotation
    rotation.Cleanup()
    ExitApp
}
