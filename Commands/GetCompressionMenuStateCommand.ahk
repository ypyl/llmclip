class GetCompressionMenuStateCommand {
    configManager := ""
    sessionManager := ""
    
    __New(configManager, sessionManager) {
        this.configManager := configManager
        this.sessionManager := sessionManager
    }
    
    Execute() {
        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        compressionPrompt := this.configManager.GetCompressionPrompt(currentLLMIndex)
        return (compressionPrompt != "")
    }
}
