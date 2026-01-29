#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include AppController.ahk

; Initialize controller
global app := AppController()
app.Start()

F3:: {
    app.ToggleDisplay()
}
