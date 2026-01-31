class CompressHistoryCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""

    __New(sessionManager, configManager, llmService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
    }

    Execute() {
        messages := this.sessionManager.GetCurrentSessionMessages()

        if (messages.Length < 3) {
            throw Error("Not enough messages to compress. Need at least 2 messages besides the system message.")
        }

        conversationText := this.sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
            throw Error("No conversation history to compress.")
        }

        compressionPrompt := this.configManager.GetCompressionPrompt(this.sessionManager.GetCurrentSessionLLMType())

        if (compressionPrompt == "") {
            throw Error("Compression prompt not configured for this provider.")
        }

        ; Note: llmService.CompressHistory already handles adding the conversationText or using the sessionManager
        return this.llmService.CompressHistory(this.sessionManager)
    }
}
