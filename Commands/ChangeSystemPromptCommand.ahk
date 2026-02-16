#Requires AutoHotkey 2.0

class ChangeSystemPromptCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute(systemPromptIndex) {
        this.sessionManager.SetCurrentSessionSystemPrompt(systemPromptIndex)
        
        systemPromptContent := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            systemPromptIndex
        )
        
        this.sessionManager.UpdateSystemPromptContent(systemPromptContent)
    }
}
