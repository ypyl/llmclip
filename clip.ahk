#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include DI\ServiceRegistry.ahk
#Include AppController.ahk

; Register all services
ServiceRegistry.RegisterServices()

; Initialize controller
global app := AppController()
app.Start()

F3:: {
    app.ToggleDisplay()
}
