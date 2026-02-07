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
        context := this.sessionManager.GetCurrentSessionContext()
        predefinedContext := this.configManager.GetContext(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        
        addedAny := false
        for item in predefinedContext {
            if (!this.HasVal(context, item)) {
                context.Push(item)
                addedAny := true
            }
        }
        
        if (addedAny) {
            this.sessionManager.SetCurrentSessionContext(context)
        }
        
        return addedAny
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }
}
