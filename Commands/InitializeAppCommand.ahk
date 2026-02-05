#Requires AutoHotkey 2.0
#Include ..\Services\LLM\TempFileManager.ahk

class InitializeAppCommand {
    Execute() {
        TempFileManager.CleanUp()
    }
}
