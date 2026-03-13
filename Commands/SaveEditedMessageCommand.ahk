#Requires AutoHotkey 2.0

class SaveEditedMessageCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute(index, newText) {
        if (index == 1) {
            llmIndex := this.sessionManager.GetCurrentSessionLLMType()
            promptIndex := this.sessionManager.GetCurrentSessionSystemPrompt()
            promptNames := this.configManager.GetSystemPromptNames(llmIndex)
            
            if (promptIndex > 0 && promptIndex <= promptNames.Length) {
                promptName := promptNames[promptIndex]
                this.configManager.SaveRawSystemPromptValue(llmIndex, promptName, newText)
            }
        }
        
        return this.sessionManager.UpdateMessageText(index, newText)
    }
}
