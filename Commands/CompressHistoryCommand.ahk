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

        if (messages.Length < 3) {
            throw Error("Not enough messages to compress. Need at least 2 messages besides the system message.")
        }

        conversationText := this.sessionManager.FormatMessagesForCompressionForSession(targetSessionIndex)

        if (conversationText == "") {
            throw Error("No conversation history to compress.")
        }

        compressionPrompt := this.configManager.GetCompressionPrompt(this.sessionManager.GetSessionModelIndex(targetSessionIndex))

        if (compressionPrompt == "") {
            throw Error("Compression prompt not configured for this provider.")
        }

        ; Call service to get compressed summary
        compressedMsg := this.llmService.CompressHistory(this.sessionManager, targetSessionIndex)
        
        ; Mutate state: replace history with compressed version
        if (compressedMsg != "") {
            this.sessionManager.ReplaceWithCompressedForSession(targetSessionIndex, compressedMsg)
        }
        
        return compressedMsg
    }
}
