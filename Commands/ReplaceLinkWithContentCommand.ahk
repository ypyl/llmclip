#Include ..\Lib\Json.ahk
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
        markdownContent := WebContentFetcher.FetchMarkdown(contextItem)
        title := ""
        
        ; Check if the content is JSON
        trimmed := Trim(markdownContent, " `t`n`r")
        if (SubStr(trimmed, 1, 1) == "{" && SubStr(trimmed, -1) == "}") {
            try {
                jsonObj := JSON.Load(trimmed)
                if (jsonObj.Has("success") && jsonObj["success"]) {
                    if (jsonObj.Has("content")) {
                        markdownContent := jsonObj["content"]
                    }
                    if (jsonObj.Has("title")) {
                        title := jsonObj["title"]
                    }
                }
            } catch {
                ; Not valid JSON, proceed with raw content
            }
        }

        ; Update the session context
        formattedContent := "URL: " . contextItem . (title ? "`nTitle: " . title : "") . "`n`n" . markdownContent

        return this.sessionManager.UpdateContextItem(itemIndex, formattedContent)
    }
}
