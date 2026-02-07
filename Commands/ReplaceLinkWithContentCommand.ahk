
class ReplaceLinkWithContentCommand {
    webViewManager := ""
    sessionManager := ""
    contextManager := ""

    __New(webViewManager, sessionManager, contextManager) {
        this.webViewManager := webViewManager
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    Execute(itemIndex, contextItem) {
        ; Load the article using webViewManager
        ; Note: This might be synchronous or asynchronous depending on WebViewManager implementation.
        ; Based on analysis, LoadArticle blocks until ready.
        article := this.webViewManager.LoadArticle(contextItem)
        
        ; Format the article content to string
        formattedContent := this.contextManager.FormatArticleFromObject(contextItem, article)
        
        ; Update the session context
        return this.sessionManager.UpdateContextItem(itemIndex, formattedContent)
    }
}
