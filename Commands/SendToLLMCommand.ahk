#Include ..\Services\ProcessingState.ahk

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

    Execute(promptText, images := [], selectedContextIndices := [], isRegeneration := false, targetSessionIndex := 0) {
        if (!targetSessionIndex)
            targetSessionIndex := this.sessionManager.currentSessionIndex

        currentContext := this.sessionManager.GetSessionContext(targetSessionIndex)
        additionalContext := this.contextManager.BuildPromptContext(currentContext, selectedContextIndices)

        if (!isRegeneration) {
            userMessageContent := this.sessionManager.BuildUserMessage(promptText, images)

            if (additionalContext != "") {
                userMessageContent.InsertAt(1, TextContent(additionalContext))
            }

            if (userMessageContent.Length > 0) {
                userChangeMessage := ChatMessage("user", userMessageContent)
                userChangeMessage.AdditionalProperties["hasContext"] := additionalContext != ""
                this.sessionManager.GetSessionMessages(targetSessionIndex).Push(userChangeMessage)
            }
        }

        messages := this.sessionManager.GetSessionMessages(targetSessionIndex)

        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetSessionLLMType(targetSessionIndex),
            this.sessionManager.GetSessionSystemPrompt(targetSessionIndex)
        )
        this.sessionManager.UpdateSystemPromptContentForSession(targetSessionIndex, systemPrompt)

        currentLLM := this.sessionManager.GetSessionLLMType(targetSessionIndex)
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, PowerShellTool.TOOL_NAME)
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, FileSystemTool.TOOL_NAME)
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, WebSearchTool.TOOL_NAME)
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, WebFetchTool.TOOL_NAME)
        markdownNewEnabled := this.configManager.IsToolEnabled(currentLLM, MarkdownNewTool.TOOL_NAME)
        answerSize := this.sessionManager.answerSize

        try {
            newMessages := this.llmService.SendToLLM(
                this.sessionManager,
                answerSize,
                powerShellEnabled,
                webSearchEnabled,
                webFetchEnabled,
                fileSystemEnabled,
                markdownNewEnabled,
                targetSessionIndex
            )

            if (newMessages.Length > 0) {
                this.sessionManager.AddMessagesToSession(targetSessionIndex, newMessages)
            }

            hasUnexecuted := this.sessionManager.HasUnexecutedToolCallsForSession(targetSessionIndex)

            return {
                action: hasUnexecuted ? ProcessingState.TOOL_PENDING : ProcessingState.IDLE,
                hasUnexecutedToolCalls: hasUnexecuted
            }
        } catch as e {
            if (e.Message == "Request cancelled") {
                return { action: ProcessingState.IDLE }
            }
            throw e
        }
    }
}
