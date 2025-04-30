#Requires AutoHotkey 2.0

class ContextManager {
    ; Get text content from a context item (file, folder, plain text or URL)
    GetTextFromContextItem(item, callback := "") {
        itemText := ""
        if (this.IsHttpLink(item)) {
            article := WebViewManagerValue.LoadArticle(item)
            itemText := "URL: " item "`n`n### " article.title "`n`n" article.textContent
        } else if (DirExist(item))
            itemText := "Folder:`n" this.ProcessFolder(item)
        else if (FileExist(item))
            itemText := "File:`n" this.ProcessFile(item)
        else
            itemText := "`n```````n" item "`n```````n"
        return itemText
    }

    ; Check if the item is an HTTP link
    IsHttpLink(item) {
        return RegExMatch(item, "i)^https?://") > 0
    }

    ; Callback for when an article is loaded
    OnArticleLoaded(article) {
        if (this.pendingUrl && this.articleCallback) {
            url := this.pendingUrl
            callback := this.articleCallback

            ; Format the article content
            content := "URL: " url "`n`n### " article.title "`n`n" article.textContent

            ; Clear pending state
            this.pendingUrl := ""
            this.articleCallback := ""

            ; Call the original callback with the content
            callback.Call(content)
        }
    }

    ProcessFolder(FolderPath) {
        folderText := FolderPath "`n"

        if (DirExist(FolderPath)) {
            Loop Files, FolderPath "\*.*", "R"  ; Recursively loop through all files
            {
                folderText .= "File:`n" this.ProcessFile(A_LoopFileFullPath)
            }
        } else {
            folderText := "`nFolder does not contains files`n"
        }

        return folderText
    }

    ProcessFile(FilePath) {
        ; Check if the file is readable as text
        if this.CanUseFileRead(FilePath) {
            try {
                content := FileRead(FilePath)
                return FilePath "`n```````n" content "`n```````n"
            } catch {
                return FilePath "`n[Error reading file content]`n"
            }
        }
        return FilePath
    }

    CanUseFileRead(filePath) {
        SplitPath filePath, , , &ext
        allowedExts := "txt,csv,log,ini,json,xml,html,md,ahk,bat,sh,ps1,yml,toml,cs,ts,js,jsx,tsx,py,java,kt,go,rs,php,rb,pl,swift,c,cpp,h,hpp,m,mm,elm,erl,ex,exs,clj,cljc,cljx,cl,scala,sql"
        return ext && InStr("," allowedExts ",", "," ext ",")
    }

    GetLabelFromContextItem(item) {
        if (this.IsHttpLink(item)) {
            return "🌐 " item
        }
        if (DirExist(item)) {
            SplitPath item, &name
            return "📁 " name " - " item
        }
        else if (FileExist(item)) {
            SplitPath item, &name, &dir
            return "📄 " name " - " dir
        }
        else {
            truncatedText := SubStr(item, 1, 50)
            if (StrLen(item) > 50)
                truncatedText .= "..."
            return "📝 " truncatedText
        }
    }
}
