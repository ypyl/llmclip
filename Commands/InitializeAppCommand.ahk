#Requires AutoHotkey 2.0
#Include ..\Utils\TempFileManager.ahk

class InitializeAppCommand {
    Execute() {
        TempFileManager.CleanUp()
    }
}
