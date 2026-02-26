class SaveStateOnExitCommand {
    sessionManager := ""
    stateService := ""

    __New(sessionManager, stateService) {
        this.sessionManager := sessionManager
        this.stateService := stateService
    }

    Execute() {
        stateObj := {
            modelIndex: this.sessionManager.GetCurrentSessionLLMType(),
            systemPromptIndex: this.sessionManager.GetCurrentSessionSystemPrompt(),
            answerSize: this.sessionManager.answerSize,
            batchMode: this.sessionManager.batchModeEnabled,
            sessionIndex: this.sessionManager.currentSessionIndex
        }
        this.stateService.SaveState(stateObj)
    }
}
