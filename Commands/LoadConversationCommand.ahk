#Requires AutoHotkey 2.0

class LoadConversationCommand {
    sessionManager := ""
    configManager := ""
    fileService := ""

    __New(sessionManager, configManager, fileService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.fileService := fileService
    }

    /**
     * Executes the load conversation command
     * @param filePath The path where the conversation should be loaded from
     */
    Execute(filePath) {
        if (filePath == "")
            return

        ; Use file service to read from disk
        fileContent := this.fileService.ReadText(filePath)
        
        ; Parse JSON and import state
        state := JSON.Load(fileContent)
        this.sessionManager.ImportSessionState(state)

        ; Update system prompt content to match loaded state
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
    }
}
