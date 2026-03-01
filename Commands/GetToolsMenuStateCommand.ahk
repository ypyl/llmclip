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
            execute_powershell: this.configManager.IsToolEnabled(currentLLMIndex, PowerShellTool.TOOL_NAME),
            file_system: this.configManager.IsToolEnabled(currentLLMIndex, FileSystemTool.TOOL_NAME),
            web_search: this.configManager.IsToolEnabled(currentLLMIndex, WebSearchTool.TOOL_NAME),
            web_fetch: this.configManager.IsToolEnabled(currentLLMIndex, WebFetchTool.TOOL_NAME),
            read_url_markdown: this.configManager.IsToolEnabled(currentLLMIndex, MarkdownNewTool.TOOL_NAME)
        }
    }
}
