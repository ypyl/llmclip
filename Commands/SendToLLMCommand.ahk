#Requires AutoHotkey 2.0

/**
 * Command to send a message to the LLM.
 * UI-agnostic logic for preparing history, system prompt, context, and calling LLMService.
 */
class SendToLLMCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""
    answerSize := ""
    
    __New(sessionManager, configManager, llmService, answerSize := "Default") {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
        this.answerSize := answerSize
    }

    /**
     * Executes the command.
     * @param additionalContext Text to be prepended to the first user message.
     * @returns {Array} New messages received from LLM.
     */
    Execute(additionalContext := "") {
        messages := this.sessionManager.GetCurrentSessionMessages()

        ; 1. Update the system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        ; 2. Handle context attachment
        ; Find first user message to attach or update context
        firstUserMsg := ""
        for i, msg in messages {
            if (msg.Role == "user") {
                firstUserMsg := msg
                break
            }
        }

        if (firstUserMsg) {
            hasExistingContext := firstUserMsg.AdditionalProperties.Has("hasContext") && firstUserMsg.AdditionalProperties["hasContext"]
            
            if (additionalContext != "") {
                if (hasExistingContext) {
                    ; Update existing context (first item in Contents)
                    if (firstUserMsg.Contents.Length > 0 && (firstUserMsg.Contents[1] is TextContent)) {
                        firstUserMsg.Contents[1].Text := additionalContext
                    }
                } else {
                    ; Insert new context at the beginning
                    firstUserMsg.Contents.InsertAt(1, TextContent(additionalContext))
                    firstUserMsg.AdditionalProperties["hasContext"] := true
                }
            } else if (hasExistingContext) {
                ; Remove existing context if additionalContext is empty
                firstUserMsg.Contents.RemoveAt(1)
                firstUserMsg.AdditionalProperties["hasContext"] := false
            }
        }

        ; 3. Prepare tool status
        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")

        ; 4. Call LLM Service
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
