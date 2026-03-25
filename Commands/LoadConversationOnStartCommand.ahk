class LoadConversationOnStartCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute() {
        state := StateService.LoadConversation()
        if (state == "")
            return false

        this.sessionManager.ImportSessionState(state)

        ; Update system prompt content to match loaded state
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionModelIndex(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        return true
    }
}
