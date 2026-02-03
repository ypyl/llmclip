class GetToolsMenuStateCommand {
    configManager := ""
    sessionManager := ""
    
    __New(configManager, sessionManager) {
        this.configManager := configManager
        this.sessionManager := sessionManager
    }
    
    Execute() {
        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        
        return {
            powerShell: this.configManager.IsToolEnabled(currentLLMIndex, "powerShellTool"),
            fileSystem: this.configManager.IsToolEnabled(currentLLMIndex, "fileSystemTool"),
            webSearch: this.configManager.IsToolEnabled(currentLLMIndex, "webSearch"),
            webFetch: this.configManager.IsToolEnabled(currentLLMIndex, "webFetch")
        }
    }
}
