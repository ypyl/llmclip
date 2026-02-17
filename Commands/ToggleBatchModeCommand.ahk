#Requires AutoHotkey 2.0

class ToggleBatchModeCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        this.sessionManager.SetBatchMode(!this.sessionManager.batchModeEnabled)
        return this.sessionManager.batchModeEnabled
    }
}
