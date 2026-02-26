#Requires AutoHotkey 2.0
#SingleInstance Force
#Warn
#Include App.ahk

global appInstance := App()
OnExit((*) => appInstance.controller.SaveStateAndConversation())
appInstance.Start()
