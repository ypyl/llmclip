class LoadConversationOnStartCommand {
    sessionManager := ""
    configManager := ""
    stateService := ""

    __New(sessionManager, configManager, stateService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.stateService := stateService
    }

    Execute() {
        state := this.stateService.LoadConversation()
        if (state == "")
            return false

        this.sessionManager.ImportSessionState(state)

        ; Update system prompt content to match loaded state
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        return true
    }
}
