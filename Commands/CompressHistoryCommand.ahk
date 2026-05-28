class CompressHistoryCommand {
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

        ; Call service to get compressed summary
        compressedMsg := this.llmService.CompressHistory(messages, conversationText, modelIndex)
        
        ; Mutate state: replace history with compressed version
        if (compressedMsg != "") {
            this.sessionManager.ReplaceWithCompressedForSession(targetSessionIndex, compressedMsg)
        }
        
        return compressedMsg
    }
}
