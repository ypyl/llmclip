#Requires AutoHotkey 2.0

/**
 * Command to send a message to the LLM.
 * UI-agnostic logic for preparing history, system prompt, context, and calling LLMService.
 */
class SendToLLMCommand {
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
     * Executes the command.
     * @param promptText The user message text.
     * @param images Array of image paths.
     * @param checkedContextIndices Indices of checked items in context list.
     * @param selectedContextIndices Indices of selected items in context box.
     * @param webViewLoader Callback to load articles via WebView.
     * @param isRegeneration Whether this is a regeneration of an existing message.
     * @returns {Array} New messages received from LLM.
     */
    Execute(promptText := "", images := [], checkedContextIndices := [], selectedContextIndices := [], isRegeneration := false) {
        ; 1. Build context
        currentContext := this.sessionManager.GetCurrentSessionContext()
        additionalContext := this.contextManager.BuildPromptContext(
            currentContext, 
            checkedContextIndices, 
            selectedContextIndices
        )

        ; 2. Build and push user message if it has content or context (skip if regeneration)
        if (!isRegeneration) {
            userMessageContent := this.sessionManager.BuildUserMessage(promptText, images)
            
            hasAnyChecked := (checkedContextIndices.Length > 0)
            if (userMessageContent.Length > 0 || hasAnyChecked) {
                this.sessionManager.GetCurrentSessionMessages().Push(ChatMessage("user", userMessageContent))
            }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()

        ; 3. Update the system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        ; 4. Handle context attachment to the last user message
        if (messages.Length > 0 && messages[messages.Length].Role == "user") {
            lastUserMsg := messages[messages.Length]
            if (additionalContext != "") {
                lastUserMsg.Contents.InsertAt(1, TextContent(additionalContext))
                lastUserMsg.AdditionalProperties["hasContext"] := true
            }
        }

        ; 5. Prepare tool status
        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")

        ; 6. Call LLM Service
        return this.llmService.SendToLLM(
            this.sessionManager, 
            this.answerSize, 
            powerShellEnabled, 
            webSearchEnabled, 
            webFetchEnabled, 
            fileSystemEnabled
        )
    }
}
