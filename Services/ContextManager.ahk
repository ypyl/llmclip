#Include FileUtils.ahk

class ContextManager {
    ; Get text content from a context item (file, folder, plain text or URL)
    GetTextFromContextItem(item, articleExtract := "") {
        itemText := ""
        if (articleExtract && this.IsHttpLink(item)) {
            try {
                article := articleExtract.Call(item)  ; Use .Call() method to properly invoke the function
                if (IsObject(article)) {
                    ; Normalize whitespace in textContent
                    normalizedText := RegExReplace(article.textContent, "\s+", " ")
                    itemText := "URL: " item "`n`nTitle: " article.title "`n`n" normalizedText
                } else if (article != "") {
                    itemText := "URL: " item "`n[" article "]"
                } else {
                    itemText := "URL: " item
                }
            } catch as e {
                itemText := "URL: " item "`n[Error extracting article: " e.Message "]"
            }
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
            if (this.IsImage(item)) {
                return "🖼️ " name " - " dir
            }
            if (this.IsPdf(item)) {
                return "📕 " name " - " dir
            }
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