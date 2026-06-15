class LoadStateOnStartCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute() {
        state := StateService.LoadState()
        if (state == "")
            return false

        isMap := Type(state) = "Map"

        ; Restore model index
        modelIndex := isMap ? state["modelIndex"] : state.modelIndex
        if (modelIndex > 0 && modelIndex <= this.configManager.models.Length)
            this.sessionManager.SetCurrentSessionModelIndex(modelIndex)

        ; Restore system prompt index
        systemPromptIndex := isMap ? state["systemPromptIndex"] : state.systemPromptIndex
        this.sessionManager.SetCurrentSessionSystemPrompt(systemPromptIndex)

        ; Update system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionModelIndex(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        ; Restore answer size
        hasAnswerSize := isMap ? state.Has("answerSize") : state.HasOwnProp("answerSize")
        if (hasAnswerSize) {
            answerSize := isMap ? state["answerSize"] : state.answerSize
            this.sessionManager.SetAnswerSize(answerSize)
        }

        ; Restore session index
        hasSessionIndex := isMap ? state.Has("sessionIndex") : state.HasOwnProp("sessionIndex")
        if (hasSessionIndex) {
            sessionIndex := isMap ? state["sessionIndex"] : state.sessionIndex
            this.sessionManager.SwitchSession(sessionIndex)
        }

        ; Restore tool overrides
        hasToolOverrides := isMap ? state.Has("toolOverrides") : state.HasOwnProp("toolOverrides")
        if (hasToolOverrides) {
            overrides := isMap ? state["toolOverrides"] : state.toolOverrides
            if (Type(overrides) = "Map") {
                this.configManager.toolOverrides := overrides
            } else {
                ; Convert plain object to Map (from JSON deserialization)
                converted := Map()
                for modelKey, toolMap in overrides {
                    inner := Map()
                    for toolName, enabled in toolMap
                        inner[toolName] := enabled
                    converted[modelKey] := inner
                }
                this.configManager.toolOverrides := converted
            }
        }

        return true
    }
}
