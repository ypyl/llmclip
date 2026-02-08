#Requires AutoHotkey 2.0

class GetMessagePresentationCommand {
    sessionManager := ""
    messagePresentationService := ""

    __New(sessionManager, messagePresentationService) {
        this.sessionManager := sessionManager
        this.messagePresentationService := messagePresentationService
    }

    /**
     * Executes the command to get the presentation text for a specific message.
     * @param index The index of the message in the current session.
     * @param full Whether to include all details (default true).
     * @returns String presentation text (Markdown).
     */
    Execute(index, full := true) {
        messages := this.sessionManager.GetCurrentSessionMessages()
        
        if (index > 0 && index <= messages.Length) {
            msg := messages[index]
            return this.messagePresentationService.GetPresentationText(msg, full)
        }
        
        return ""
    }
}
