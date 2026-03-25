#Requires AutoHotkey 2.0

class SwitchSessionCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(sessionIndex) {
        currentModelIndex := this.sessionManager.GetCurrentSessionModelIndex()
        this.sessionManager.SwitchSession(sessionIndex)
        this.sessionManager.SetCurrentSessionModelIndex(currentModelIndex)
    }
}
