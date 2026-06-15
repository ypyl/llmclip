class SaveStateOnExitCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute() {
        stateObj := {
            modelIndex: this.sessionManager.GetCurrentSessionModelIndex(),
            systemPromptIndex: this.sessionManager.GetCurrentSessionSystemPrompt(),
            sessionIndex: this.sessionManager.currentSessionIndex,
            toolOverrides: this.configManager.toolOverrides
        }
        StateService.SaveState(stateObj)
    }
}
