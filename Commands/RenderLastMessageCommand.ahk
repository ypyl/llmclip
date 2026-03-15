#Requires AutoHotkey 2.0

/**
 * Command to render the last message from the current session.
 * Encapsulates logic for formatting (MessagePresentationService) and rendering (WebViewManager).
 */
class RenderLastMessageCommand {
    sessionManager := ""
    webViewManager := ""

    __New(sessionManager, webViewManager) {
        this.sessionManager := sessionManager
        this.webViewManager := webViewManager
    }

    Execute() {
        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messages.Length > 0) {
            lastMsg := messages[messages.Length]
            htmlContent := MessagePresentationService.GetMessageAsString(lastMsg)
            this.webViewManager.RenderMarkdown(htmlContent)
        }
    }
}
