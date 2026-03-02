#Include ..\ProcessingState.ahk

class SendToLLMCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""
    contextManager := ""
    executeToolCallsCommand := ""

    __New(sessionManager, configManager, llmService, contextManager, executeToolCallsCommand) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
        this.contextManager := contextManager
        this.executeToolCallsCommand := executeToolCallsCommand
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
                markdownNewEnabled
            )

            if (newMessages.Length > 0) {
                this.sessionManager.AddMessages(newMessages)
            }

            hasUnexecuted := this.sessionManager.HasUnexecutedToolCalls()

            ; Check if auto-approval is enabled for these tool calls
            if (hasUnexecuted) {
                lastMsg := messages[messages.Length]
                if (this.executeToolCallsCommand.ShouldAutoApprove(lastMsg)) {
                    ; Auto-execute and continue
                    if (this.executeToolCallsCommand.Execute()) {
                        return this.Execute("", [], [], true)
                    }
                }
            }

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
