class SaveConversationOnExitCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        conversationState := this.sessionManager.ExportSessionState()
        StateHelper.SaveConversation(conversationState)
    }
}
