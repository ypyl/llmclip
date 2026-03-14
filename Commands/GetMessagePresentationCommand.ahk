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
     * @param messageIndex The 1-based index of the message in the current session.
     * @param isThinking Whether to show only the thinking content.
     * @param full Whether to include full details (only applies to real rows; default true).
     * @returns String presentation text (Markdown).
     */
    Execute(messageIndex, isThinking := false, full := true) {
        messages := this.sessionManager.GetCurrentSessionMessages()

        if (messageIndex < 1 || messageIndex > messages.Length)
            return ""

        msg := messages[messageIndex]

        if (isThinking) {
            return this.messagePresentationService.GetThinkingPresentationText(msg)
        } else {
            ; Show the real message — without the thinking block
            return this.messagePresentationService.GetPresentationText(msg, false)
        }
    }
}
