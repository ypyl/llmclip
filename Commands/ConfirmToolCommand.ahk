#Requires AutoHotkey 2.0

/**
 * Command to execute unexecuted tool calls in the session.
 */
class ConfirmToolCommand {
    sessionManager := ""
    llmService := ""
    sendToLLMCommand := ""

    __New(sessionManager, llmService, sendToLLMCommand) {
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.sendToLLMCommand := sendToLLMCommand
    }

    /**
     * Executes unexecuted tool calls.
     * @returns {Boolean} True if any tools were executed and follow-up request sent.
     */
    Execute() {
        messages := this.sessionManager.GetCurrentSessionMessages()
        executedAny := false
        
        ; We need to iterate over a copy because LLMService might push new messages
        ; Using indexed loop to handle message additions safely
        i := 1
        while (i <= messages.Length) {
            msg := messages[i]
            if (this.sessionManager.HasToolCalls(msg)) {
                toolResults := this.llmService.ExecuteToolCalls(this.sessionManager, msg)
                if (toolResults.Length > 0) {
                    for res in toolResults {
                        messages.Push(res)
                    }
                    executedAny := true
                }
            }
            i++
        }

        if (executedAny) {
            this.sendToLLMCommand.Execute()
            return true
        }
        return false
    }
}
