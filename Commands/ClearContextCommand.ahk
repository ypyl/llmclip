#Requires AutoHotkey 2.0

class ClearContextCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the clear context command
     */
    Execute() {
        this.sessionManager.SetCurrentSessionContext([])
    }
}
