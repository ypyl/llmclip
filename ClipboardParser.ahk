#Requires AutoHotkey 2.0
#Include ImageFromClipboard.ahk

class ClipboardParser {
    ; Parse clipboard content and return an array of items (text or paths)
    Parse() {
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

        ; If empty, check raw clipboard for file URI
        if (isVsCodeActive && txtFromClipboard = "") {
            try {
                cb_all := ClipboardAll()
                ; Build string byte-by-byte assuming ANSI
                rawData := ""
                Loop cb_all.Size {
                    byte := NumGet(cb_all.Ptr, A_Index - 1, "UChar")
                    if (byte != 0) {  ; Skip null bytes
                        rawData .= Chr(byte)
                    }
                }

                ; Extract all file URIs present
                localTxtFromClipboardArray := []  ; Reset array
                position := 1
                while (position := InStr(rawData, "file:///", false, position)) {
                    uriStart := position
                    uriEnd := InStr(rawData, "`n", false, uriStart) || StrLen(rawData) + 1
                    fileUri := SubStr(rawData, uriStart, uriEnd - uriStart)

                    ; Decode URI to Windows path and add to array
                    decodedPath := this.UriToPath(fileUri)
                    if (decodedPath)
                        localTxtFromClipboardArray.Push(decodedPath)

                    position := uriEnd  ; Move to next position
                }

                ; If no URIs found, fall back to original clipboard text
                if (localTxtFromClipboardArray.Length = 0)
                    localTxtFromClipboardArray := [txtFromClipboard]
            } catch as e {
                MsgBox "Error processing clipboard: " e.Message
            }
        }

        if (localTxtFromClipboardArray.Length = 0 || localTxtFromClipboardArray[1] = "") {
            isImage := ClipboardUtil.TryGetPngFromClipboard()
            if isImage
                return [isImage]
        }

        return localTxtFromClipboardArray
    }

    ; Convert a URI to a Windows path
    UriToPath(uri) {
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
