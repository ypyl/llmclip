#Requires AutoHotkey 2.0

/**
 * Command to process multiple context items in batch mode.
 */
class SendBatchToLLMCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""
    contextManager := ""
    answerSize := ""
    
    __New(sessionManager, configManager, llmService, contextManager, answerSize := "Default") {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
        this.contextManager := contextManager
        this.answerSize := answerSize
    }

    /**
     * Executes the batch command.
     * @param promptText The user's prompt text.
     * @param items An array of context items (raw paths/URLs/text) to process.
     * @param updateCallback A callback function(itemLabel, responseMessages) for each completed item.
     * @param isCancelled Callback function returning true if processing should stop.
     * @param webViewLoader Callback to load articles via WebView.
     */
    Execute(promptText, items, updateCallback, isCancelled, webViewLoader := "") {
        ; Create and mark the user message in main session
        userContent := [TextContent(promptText)]
        userMsg := ChatMessage("user", userContent)
        userMsg.AdditionalProperties["isBatchMode"] := true
        
        mainMessages := this.sessionManager.GetCurrentSessionMessages()
        mainMessages.Push(userMsg)

        ; Prepare common tool settings
        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")

        ; Prepare base history (filtered but WITHOUT the current trigger message)
        baseHistory := this.sessionManager.GetMessagesExcludingBatch()

        for item in items {
            if (isCancelled())
                break

            ; Deep clone history and trigger message
            clonedMessages := []
            for msg in baseHistory {
                clonedMessages.Push(msg.Clone())
            }
            
            activePromptClone := userMsg.Clone()
            clonedMessages.Push(activePromptClone)
            
            ; Get context for this item
            itemLabel := this.contextManager.GetLabelFromContextItem(item)
            itemText := this.contextManager.GetTextFromContextItem(item, webViewLoader)
            
            ; Attach context to the clone
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

            ; Temp session manager for LLMService
            tempSession := {
                GetCurrentSessionMessages: (*) => clonedMessages,
                GetCurrentSessionLLMType: (*) => this.sessionManager.GetCurrentSessionLLMType(),
                GetMessagesExcludingBatch: (*) => clonedMessages,
                HasUnexecutedToolCalls: (*) => false
            }

            ; Send request
            newMessages := this.llmService.SendToLLM(tempSession, this.answerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled)

            ; Mark responses and add to main history
            for respMsg in newMessages {
                respMsg.AdditionalProperties["isBatchResponse"] := true
                respMsg.AdditionalProperties["batchContextItem"] := itemLabel
                mainMessages.Push(respMsg)
            }

            ; Notify completion of this item
            updateCallback(itemLabel, newMessages)
        }
    }
}
