#Requires AutoHotkey 2.0

class SelectModelCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(modelIndex) {
        this.sessionManager.SetCurrentSessionModelIndex(modelIndex)
    }
}
