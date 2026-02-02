#Requires AutoHotkey 2.0

class SelectModelCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(modelIndex) {
        this.sessionManager.SetCurrentSessionLLMType(modelIndex)
        this.sessionManager.SetCurrentSessionSystemPrompt(1) ; Reset to first prompt
    }
}
