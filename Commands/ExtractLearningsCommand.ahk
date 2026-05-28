class ExtractLearningsCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""

    __New(sessionManager, configManager, llmService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
    }

    Execute(targetSessionIndex := 0) {
        if (!targetSessionIndex)
            targetSessionIndex := this.sessionManager.currentSessionIndex

        messages := this.sessionManager.GetSessionMessages(targetSessionIndex)
        conversationText := this.sessionManager.FormatMessagesForCompressionForSession(targetSessionIndex)
        modelIndex := this.sessionManager.GetSessionModelIndex(targetSessionIndex)

        return this.llmService.ExtractLearnings(messages, conversationText, modelIndex)
    }
}
