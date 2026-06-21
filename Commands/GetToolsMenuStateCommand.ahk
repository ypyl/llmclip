class GetToolsMenuStateCommand {
    configManager := ""
    sessionManager := ""
    toolDefinitions := ""

    __New(configManager, sessionManager, toolDefinitions) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.toolDefinitions := toolDefinitions
    }

    Execute() {
        currentLLMIndex := this.sessionManager.GetCurrentSessionModelIndex()

        result := []
        for def in this.toolDefinitions {
            result.Push({
                label: def.label,
                checked: this.configManager.IsToolEnabled(currentLLMIndex, def.id)
            })
        }
        return result
    }
}
