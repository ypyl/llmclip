class ExecuteToolCallsCommand {
    sessionManager := ""
    llmService := ""
    
    __New(sessionManager, llmService) {
        this.sessionManager := sessionManager
        this.llmService := llmService
    }
    
    Execute() {
        messages := this.sessionManager.GetCurrentSessionMessages()
        executedAny := false

        i := 1
        while (i <= messages.Length) {
            msg := messages[i]
            if (this.sessionManager.HasToolCalls(msg)) {
                toolResults := this.llmService.ExecuteToolCalls(this.sessionManager, msg)
                if (toolResults.Length > 0) {
                    this.sessionManager.AddMessages(toolResults)
                    executedAny := true
                }
            }
            i++
        }
        return executedAny
    }
}