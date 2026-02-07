#Requires AutoHotkey 2.0

/**
 * Command to render the last message from the current session.
 * Encapsulates logic for formatting (MessagePresentationService) and rendering (WebViewManager).
 */
class RenderLastMessageCommand {
    sessionManager := ""
    messagePresentationService := ""
    webViewManager := ""

    __New(sessionManager, messagePresentationService, webViewManager) {
        this.sessionManager := sessionManager
        this.messagePresentationService := messagePresentationService
        this.webViewManager := webViewManager
    }

    Execute() {
        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messages.Length > 0) {
            lastMsg := messages[messages.Length]
            htmlContent := this.messagePresentationService.GetMessageAsString(lastMsg)
            this.webViewManager.RenderMarkdown(htmlContent)
        }
    }
}
