#Requires AutoHotkey 2.0

class PrepareContextCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    /**
     * Executes the prepare context command: merges predefined context into current session.
     */
    Execute() {
        predefinedContext := this.configManager.GetContext(
            this.sessionManager.GetCurrentSessionModelIndex(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )

        return this.sessionManager.AddContextItems(predefinedContext)
    }
}
