#Requires AutoHotkey 2.0
#Include ClipboardImageHelper.ahk

class ClipboardParserHelper {
    ; Parse clipboard content and return an array of items (text or paths)
    static Parse() {
        ; First try plain text from A_Clipboard
        txtFromClipboard := Trim(A_Clipboard, '"')
        localTxtFromClipboardArray := [txtFromClipboard]

        ; Check if the clipboard content contains paths
        if (InStr(txtFromClipboard, "`r`n") || InStr(txtFromClipboard, "`n")) {
            localTxtFromClipboardArray := StrSplit(txtFromClipboard, "`r`n")
            if (localTxtFromClipboardArray.Length = 1) {
                localTxtFromClipboardArray := StrSplit(txtFromClipboard, "`n")
            }
        }

        ; Validate if the split items are paths
        for index, item in localTxtFromClipboardArray {
            if (!FileExist(item) && !DirExist(item)) {
                ; If any item is not a valid path, treat the whole content as plain text
                txtFromClipboard := StrReplace(txtFromClipboard, "`r`n", "`n")
                localTxtFromClipboardArray := [txtFromClipboard]
                break
            }
        }

        try {
            activeClass := WinGetClass("A")  ; Get handle of active window
            activeTitle := WinGetTitle("A")  ; Get handle of active window
        } catch as e {
            activeClass := ""
            activeTitle := ""
        }

        ; Check for VS Code using class and title
        isVsCodeActive := (activeClass = "Chrome_WidgetWin_1" && (InStr(activeTitle, "Visual Studio Code") || InStr(activeTitle, "Antigravity")))

        ; If empty, scan raw clipboard for file paths
        if (isVsCodeActive && txtFromClipboard = "") {
            try {
                localTxtFromClipboardArray := []  ; Reset array

                cb_all := ClipboardAll()
                rawData := ""
                Loop cb_all.Size {
                    byte := NumGet(cb_all.Ptr, A_Index - 1, "UChar")
                    if (byte != 0) {  ; Skip null bytes
                        rawData .= Chr(byte)
                    }
                }

                ; 1) Try file:/// URIs
                position := 1
                while (position := InStr(rawData, "file:///", false, position)) {
                    uriStart := position
                    uriEnd := InStr(rawData, "`n", false, uriStart) || StrLen(rawData) + 1
                    fileUri := SubStr(rawData, uriStart, uriEnd - uriStart)

                    decodedPath := this.UriToPath(fileUri)
                    if (decodedPath)
                        localTxtFromClipboardArray.Push(decodedPath)

                    position := uriEnd
                }

                ; 2) If no URIs, scan for bare Windows drive-letter paths (e.g. C:\Users\...)
                if (localTxtFromClipboardArray.Length = 0) {
                    searchPos := 1
                    while (foundPos := RegExMatch(rawData, "[A-Za-z]:\\", &match, searchPos)) {
                        ; Extract from drive letter to end, then trim trailing garbage
                        candidate := SubStr(rawData, foundPos)
                        while (candidate != "" && !FileExist(candidate) && !DirExist(candidate))
                            candidate := SubStr(candidate, 1, -1)
                        if (candidate != "")
                            localTxtFromClipboardArray.Push(candidate)
                        searchPos := foundPos + StrLen(candidate)  ; Advance past this path
                    }
                }

                ; 3) If still nothing, fall back to original clipboard text
                if (localTxtFromClipboardArray.Length = 0)
                    localTxtFromClipboardArray := [txtFromClipboard]
            } catch as e {
                MsgBox "Error processing clipboard: " e.Message
            }
        }

        if (localTxtFromClipboardArray.Length = 0 || localTxtFromClipboardArray[1] = "") {
            isImage := ClipboardImageHelper.TryGetPngFromClipboard()
            if isImage
                return [isImage]
        }

        return localTxtFromClipboardArray
    }

    ; Convert a URI to a Windows path
    static UriToPath(uri) {
        ; Remove "file:///" prefix
        path := SubStr(uri, 8)

        ; Decode URL-encoded characters
        path := StrReplace(path, "%20", " ")
        path := StrReplace(path, "%3A", ":")
        path := StrReplace(path, "%5C", "\")
        path := StrReplace(path, "%2F", "/")

        ; Convert forward slashes to backslashes for Windows
        path := StrReplace(path, "/", "\")

        ; Remove leading slash if present
        if (SubStr(path, 1, 1) = "\") {
            path := SubStr(path, 2)
        }

        return path
    }
}
