class SendToLLMCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""
    contextManager := ""

    __New(sessionManager, configManager, llmService, contextManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
        this.contextManager := contextManager
    }

    Execute(promptText, images := [], selectedContextIndices := [], isRegeneration := false) {
        currentContext := this.sessionManager.GetCurrentSessionContext()
        additionalContext := this.contextManager.BuildPromptContext(currentContext, selectedContextIndices)

        if (!isRegeneration) {
            userMessageContent := this.sessionManager.BuildUserMessage(promptText, images)

            if (additionalContext != "") {
                userMessageContent.InsertAt(1, TextContent(additionalContext))
            }

            if (userMessageContent.Length > 0) {
                userChangeMessage := ChatMessage("user", userMessageContent)
                userChangeMessage.AdditionalProperties["hasContext"] := additionalContext != ""
                this.sessionManager.GetCurrentSessionMessages().Push(userChangeMessage)
            }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()

        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")
        markdownNewEnabled := this.configManager.IsToolEnabled(currentLLM, "markdownNew")
        answerSize := this.sessionManager.answerSize

        try {
            newMessages := this.llmService.SendToLLM(
                this.sessionManager,
                answerSize,
                powerShellEnabled,
                webSearchEnabled,
                webFetchEnabled,
                fileSystemEnabled,
                markdownNewEnabled
            )

            if (newMessages.Length > 0) {
                this.sessionManager.AddMessages(newMessages)
            }

            hasUnexecuted := this.sessionManager.HasUnexecutedToolCalls()
            return {
                action: hasUnexecuted ? "tool_pending" : "idle",
                hasUnexecutedToolCalls: hasUnexecuted
            }
        } catch as e {
            if (e.Message == "Request cancelled") {
                return { action: "idle" }
            }
            throw e
        }
    }
}
