#Include FileUtils.ahk

class ContextManager {
    ; Get text content from a context item (file, folder, plain text or URL)
    GetTextFromContextItem(item) {
        itemText := ""
        if (this.IsHttpLink(item)) {
             itemText := "URL: " item
        } else if (DirExist(item)) {
            itemText := "Folder:`n" this.ProcessFolder(item)
        } else if (FileExist(item)) {
            if (this.IsImage(item)) {
                base64Image := FileUtils.GetFileAsBase64(item)
                if (base64Image != "") {
                    SplitPath item, , , &ext
                    itemText := "![Image](data:image/" . ext . ";base64," . base64Image . ")"
                } else {
                    itemText := "[Image not found: " . item . "]"
                }
            } else {
                itemText := "File:`n" this.ProcessFile(item)
            }
        } else if (this.IsImage(item)) {
            itemText := "![Image](" item ")"
        } else {
            itemText := "`n```````n" item "`n```````n"
        }
        return itemText
    }

    FormatArticleFromObject(item, article) {
        try {
            if (IsObject(article)) {
                ; Normalize whitespace in textContent
                normalizedText := RegExReplace(article.textContent, "\s+", " ")
                return "URL: " item "`n`nTitle: " article.title "`n`n" normalizedText
            } else if (article != "") {
                return "URL: " item "`n[" article "]"
            } else {
                return "URL: " item
            }
        } catch as e {
            return "URL: " item "`n[Error formatting article: " e.Message "]"
        }
    }

    ; Check if the item is an HTTP link
    IsHttpLink(item) {
        return RegExMatch(item, "i)^https?://") > 0
    }

    IsImage(item) {
        if (FileExist(item)) {
            SplitPath item, , , &ext
            imageExts := "png,jpg,jpeg,gif,bmp,webp"
            if InStr("," imageExts ",", "," ext ",")
                return true
        }
        if (RegExMatch(item, "i)^data:image/")) {
            return true
        }
        return false
    }

    IsPdf(item) {
        if (FileExist(item)) {
            SplitPath item, , , &ext
            if (ext = "pdf")
                return true
        }
        return false
    }

    ProcessFolder(FolderPath) {
        folderText := FolderPath "`n"

        if (DirExist(FolderPath)) {
            loop files, FolderPath "\*.*", "R"  ; Recursively loop through all files
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
        allowedExts :=
            "txt,csv,log,ini,json,xml,html,md,ahk,bat,sh,ps1,yml,toml,cs,ts,js,jsx,tsx,py,java,kt,go,rs,php,rb,pl,swift,c,cpp,h,hpp,m,mm,elm,erl,ex,exs,clj,cljc,cljx,cl,scala,sql,css,scss,sass,yaml,yml,tf"
        return ext && InStr("," allowedExts ",", "," ext ",")
    }


    BuildPromptContext(context, selectedIndices) {
        if (context.Length = 0)
            return ""

        contextText := ""
        
        ; Build general context from checked items (that are not selected and not images/PDFs)
        for index, item in context {
            isSelected := false
            for selectedIndex in selectedIndices {
                if (selectedIndex = index) {
                    isSelected := true
                    break
                }
            }

            if (item.Checked && !isSelected && !this.IsImage(item.Value) && !this.IsPdf(item.Value)) {
                contextText .= this.GetTextFromContextItem(item.Value)
            }
        }

        messageContent := ""

        ; Only add general context if there is any non-selected content
        if (contextText != "") {
            messageContent .= "Use information from the following context. If the information is not relevant, do not use it. If you need more information, ask.`n`n<CONTEXT>`n" contextText "`n<CONTEXT>"
        }

        ; Add selected items as special focus points (excluding images/PDFs)
        if (selectedIndices.Length > 0) {
            selectedContextText := ""
            for index in selectedIndices {
                if (index > 0 && index <= context.Length) {
                    item := context[index]
                    if (item.Checked && !this.IsImage(item.Value) && !this.IsPdf(item.Value)) {
                        selectedContextText .= this.GetTextFromContextItem(item.Value)
                    }
                }
            }
            
            if (selectedContextText != "") {
                messageContent .= "`n`n<SELECTED_CONTEXT>`n" selectedContextText "`n<SELECTED_CONTEXT>"
            }
        }

        return messageContent
    }
}