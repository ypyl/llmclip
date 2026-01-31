class ResetAllCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        this.sessionManager.ResetCurrentSession()
    }
}
