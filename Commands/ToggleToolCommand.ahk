class ToggleToolCommand {
    configManager := ""
    sessionManager := ""
    
    __New(configManager, sessionManager) {
        this.configManager := configManager
        this.sessionManager := sessionManager
    }
    
    Execute(toolName) {
        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        isEnabled := this.configManager.IsToolEnabled(currentLLMIndex, toolName)
        
        ; Toggle state
        this.configManager.SetToolEnabled(currentLLMIndex, toolName, !isEnabled)
        
        return !isEnabled
    }
}
