class SaveStateOnExitCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute() {
        stateObj := {
            modelIndex: this.sessionManager.GetCurrentSessionLLMType(),
            systemPromptIndex: this.sessionManager.GetCurrentSessionSystemPrompt(),
            answerSize: this.sessionManager.answerSize,
            batchMode: this.sessionManager.batchModeEnabled,
            sessionIndex: this.sessionManager.currentSessionIndex
        }
        StateService.SaveState(stateObj)
    }
}
