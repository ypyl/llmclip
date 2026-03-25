#Requires AutoHotkey 2.0

class GetMessagePresentationCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the command to get the presentation text for a specific message.
     * @param messageIndex The 1-based index of the message in the current session.
     * @param isThinking Whether to show only the thinking content.
     * @param full Whether to include full details (only applies to real rows; default true).
     * @param isContext Whether to show only the context content.
     * @returns String presentation text (Markdown).
     */
    Execute(messageIndex, isThinking := false, full := true, isContext := false) {
        messages := this.sessionManager.GetCurrentSessionMessages()

        if (messageIndex < 1 || messageIndex > messages.Length)
            return ""

        msg := messages[messageIndex]

        if (isThinking) {
            return MessagePresentationService.GetThinkingPresentationText(msg)
        } else if (isContext) {
            return MessagePresentationService.GetContextPresentationText(msg)
        } else {
            ; Show the real message — without the thinking block
            return MessagePresentationService.GetPresentationText(msg, false)
        }
    }
}
