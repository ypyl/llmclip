#Include ..\Lib\Json.ahk

class ReplaceLinkWithContentCommand {
    markdownNewTool := ""
    sessionManager := ""
    contextManager := ""

    __New(markdownNewTool, sessionManager, contextManager) {
        this.markdownNewTool := markdownNewTool
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    Execute(itemIndex, contextItem) {
        ; Extract article content using MarkdownNewTool
        markdownContent := this.markdownNewTool.Execute(contextItem)
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
        ; MarkdownNewTool returns raw markdown or JSON which we've parsed, so we just wrap it in the URL header
        formattedContent := "URL: " . contextItem . (title ? "`nTitle: " . title : "") . "`n`n" . markdownContent

        return this.sessionManager.UpdateContextItem(itemIndex, formattedContent)
    }
}
