class LoadConversationOnStartCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        state := StateHelper.LoadConversation()
        if (state == "")
            return false

        ; Only the all-sessions format is supported.
        ; An old-format or corrupt file throws here; MainController.Start()'s
        ; safety net turns that into a fresh start with the 5 empty sessions.
        this.sessionManager.ImportAllSessions(state)
        return true
    }
}
