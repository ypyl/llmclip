class SendBatchToLLMCommand {
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

    Execute(promptText, batchItems, isCancelledCallback, batchUpdateCallback := "", targetSessionIndex := 0) {
        if (!targetSessionIndex)
            targetSessionIndex := this.sessionManager.currentSessionIndex

        userContent := [TextContent(promptText)]
        userMsg := ChatMessage("user", userContent)
        userMsg.AdditionalProperties["isBatchMode"] := true

        mainMessages := this.sessionManager.GetSessionMessages(targetSessionIndex)
        mainMessages.Push(userMsg)

        currentLLM := this.sessionManager.GetSessionModelIndex(targetSessionIndex)
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, PowerShellTool.TOOL_NAME)
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, FileSystemTool.TOOL_NAME)
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, WebSearchTool.TOOL_NAME)
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, WebFetchTool.TOOL_NAME)
        markdownNewEnabled := this.configManager.IsToolEnabled(currentLLM, MarkdownNewTool.TOOL_NAME)

        baseHistory := this.sessionManager.GetMessagesExcludingBatchForSession(targetSessionIndex)

        for item in batchItems {
            if (isCancelledCallback())
                break

            clonedMessages := []
            for msg in baseHistory {
                clonedMessages.Push(msg.Clone())
            }

            activePromptClone := userMsg.Clone()
            clonedMessages.Push(activePromptClone)

            itemLabel := this.contextManager.GetLabelFromContextItem(item)
            itemText := this.contextManager.GetTextFromContextItem(item)

            firstUserMsg := ""
            for msg in clonedMessages {
                if (msg.Role == "user") {
                    firstUserMsg := msg
                    break
                }
            }

            if (firstUserMsg) {
                firstUserMsg.Contents.InsertAt(1, TextContent("Context for this request: [" . itemLabel . "]`n" . itemText))
                firstUserMsg.AdditionalProperties["hasContext"] := true
            }

            tempSession := {
                currentSessionIndex: 1,
                GetSessionMessages: (*) => clonedMessages,
                GetSessionLLMType: (*) => this.sessionManager.GetSessionModelIndex(targetSessionIndex),
                GetMessagesExcludingBatchForSession: (*) => clonedMessages,
                HasUnexecutedToolCallsForSession: (*) => false
            }

            answerSize := this.sessionManager.answerSize
            newMessages := this.llmService.SendToLLM(tempSession, answerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled)

            for respMsg in newMessages {
                respMsg.AdditionalProperties["isBatchResponse"] := true
                respMsg.AdditionalProperties["batchContextItem"] := itemLabel
                mainMessages.Push(respMsg)
            }

            if (batchUpdateCallback) {
                batchUpdateCallback(itemLabel, newMessages)
            }
        }
    }
}
