#Include ..\Utils\WebContentFetcher.ahk

class ReplaceLinkWithContentCommand {
    sessionManager := ""
    contextManager := ""

    __New(sessionManager, contextManager) {
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    Execute(itemIndex, contextItem) {
        ; Fetch web content using WebContentFetcher
        parsed := WebContentFetcher.ParseMarkdownResponse(WebContentFetcher.FetchMarkdown(contextItem))
        title := parsed.title

        ; Update the session context
        formattedContent := "URL: " . contextItem . (title ? "`nTitle: " . title : "") . "`n`n" . parsed.content

        return this.sessionManager.UpdateContextItem(itemIndex, formattedContent)
    }
}
