class ExtractLearningsCommand {
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

        if (messages.Length < 2) {
            throw Error("Not enough conversation history to extract notes.")
        }

        conversationText := this.sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
            throw Error("No conversation history to extract from.")
        }

        return this.llmService.ExtractLearnings(this.sessionManager)
    }
}
