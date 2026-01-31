#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include App.ahk

; Initialize application
global appInstance := App()
appInstance.Start()

F3:: {
    appInstance.ToggleDisplay()
}
