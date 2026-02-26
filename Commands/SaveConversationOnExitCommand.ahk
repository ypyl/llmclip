class SaveConversationOnExitCommand {
    sessionManager := ""
    stateService := ""

    __New(sessionManager, stateService) {
        this.sessionManager := sessionManager
        this.stateService := stateService
    }

    Execute() {
        conversationState := this.sessionManager.ExportSessionState()
        this.stateService.SaveConversation(conversationState)
    }
}
