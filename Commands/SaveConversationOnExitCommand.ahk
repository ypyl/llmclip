class SaveConversationOnExitCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        conversationState := this.sessionManager.ExportAllSessions()
        StateHelper.SaveConversation(conversationState)
    }
}
