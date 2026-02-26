class LoadStateOnStartCommand {
    sessionManager := ""
    configManager := ""
    stateService := ""

    __New(sessionManager, configManager, stateService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.stateService := stateService
    }

    Execute() {
        state := this.stateService.LoadState()
        if (state == "")
            return false

        isMap := Type(state) = "Map"

        ; Restore model index
        modelIndex := isMap ? state["modelIndex"] : state.modelIndex
        if (modelIndex > 0 && modelIndex <= this.configManager.llmTypes.Length)
            this.sessionManager.SetCurrentSessionLLMType(modelIndex)

        ; Restore system prompt index
        systemPromptIndex := isMap ? state["systemPromptIndex"] : state.systemPromptIndex
        this.sessionManager.SetCurrentSessionSystemPrompt(systemPromptIndex)

        ; Update system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        ; Restore answer size
        hasAnswerSize := isMap ? state.Has("answerSize") : state.HasOwnProp("answerSize")
        if (hasAnswerSize) {
            answerSize := isMap ? state["answerSize"] : state.answerSize
            this.sessionManager.SetAnswerSize(answerSize)
        }

        ; Restore batch mode
        hasBatchMode := isMap ? state.Has("batchMode") : state.HasOwnProp("batchMode")
        if (hasBatchMode) {
            batchMode := isMap ? state["batchMode"] : state.batchMode
            this.sessionManager.SetBatchMode(batchMode)
        }

        ; Restore session index
        hasSessionIndex := isMap ? state.Has("sessionIndex") : state.HasOwnProp("sessionIndex")
        if (hasSessionIndex) {
            sessionIndex := isMap ? state["sessionIndex"] : state.sessionIndex
            this.sessionManager.SwitchSession(sessionIndex)
        }

        return true
    }
}
