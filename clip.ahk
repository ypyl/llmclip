#SingleInstance Force  ; Prevent multiple instances
#Warn

; Initialize variables
isRecording := false
txtFromClipboardArray := []
global MyGui

A_TrayMenu.Delete()  ; Remove default menu items
A_TrayMenu.Add("Start Recording", StartRecording)
A_TrayMenu.Add("Stop Recording", StopRecording)
A_TrayMenu.Add("Show Copied Text", ShowCopiedText)
A_TrayMenu.Add("Exit", ExitApp)

; Set default tray icon and tooltip
SetTrayStatus(false)  ; Default state (not recording)

OnMessage(0x404, TrayIconClick)

TrayIconClick(wParam, lParam, msg, hwnd) {
    ; If left-clicked (lParam = 0x202)
    if (lParam = 0x202) {
        if (isRecording) {
            StopRecording()  ; Stop recording
        } else {
            StartRecording()  ; Start recording
        }
    }
}

SetTrayStatus(isRecording) {
    if (isRecording) {
        TraySetIcon("shell32.dll", 132)  ; Red circle (recording)
        A_IconTip := "📍 Recording Clipboard..."
        A_TrayMenu.Disable("Start Recording")
        A_TrayMenu.Enable("Stop Recording")
        A_TrayMenu.Enable("Show Copied Text")
    } else {
        TraySetIcon("shell32.dll", 177)  ; Default clipboard icon
        A_IconTip := ""
        A_TrayMenu.Enable("Start Recording")
        A_TrayMenu.Disable("Stop Recording")
        A_TrayMenu.Disable("Show Copied Text")
    }
}

^!r:: {
    if (isRecording) {
        StopRecording()
    } else {
        StartRecording()
    }
}

StartRecording(*) {
    global isRecording, txtFromClipboardArray
    if (!isRecording) {
        isRecording := true
        txtFromClipboardArray := []
        SetTrayStatus(true)  ; Update icon & tooltip
    }
}

StopRecording(*) {
    global isRecording, txtFromClipboardArray
    if (isRecording) {
        isRecording := false
        SetTrayStatus(false)  ; Update icon & tooltip
        recordedText := ""  ; Clear recorded text
        for item in txtFromClipboardArray {
            if (DirExist(item)) {
                recordedText .= "`n======`n" ProcessFolder(item)
            } else if (FileExist(item)) {
                recordedText .= "`n======`n" ProcessFile(item)
            } else {
                recordedText .= "`n======`n" item
            }
        }
        A_Clipboard := recordedText  ; Copy recorded text to clipboard
    }
}

ShowCopiedText(*) {
    global txtFromClipboardArray, MyGui
    MyGui := Gui("+AlwaysOnTop")
    MyGui.Add("ListBox", "vListBox w400 h300", txtFromClipboardArray)
    deleteButton := MyGui.Add("Button", , "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)
    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show()
}

GuiClose(*) {
    global MyGui
    MyGui.Destroy()
}

ListBoxSelect(*) {
    ; Handle list box selection if needed
}

DeleteSelected(*) {
    global txtFromClipboardArray, MyGui
    listBox := MyGui["ListBox"]
    selectedIndex := listBox.Value
    if (selectedIndex > 0) {
        txtFromClipboardArray.RemoveAt(selectedIndex)
        listBox.Delete()
        listBox.Add(txtFromClipboardArray)
    }
}

ExitApp(*) {
    ExitApp
}

OnClipboardChange ClipChanged

ClipChanged(DataType) {
    global isRecording, txtFromClipboardArray
    if (isRecording) {
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
                localTxtFromClipboardArray := [txtFromClipboard]
                break
            }
        }

        activeClass := WinGetClass("A")  ; Get handle of active window
        activeTitle := WinGetTitle("A")  ; Get handle of active window

        ; Check for VS Code using class and title
        isVsCodeActive := (activeClass = "Chrome_WidgetWin_1" && InStr(activeTitle, "Visual Studio Code"))

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
                    decodedPath := UriToPath(fileUri)
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

        ; ; Debug: Show what we got
        ; MsgBox "Clipboard processed as: " txtFromClipboard
        for item in localTxtFromClipboardArray {
            txtFromClipboardArray.Push(item)
        }
    }
}

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

ProcessFolder(FolderPath) {
    folderText := FolderPath

    if (DirExist(FolderPath)) {
        Loop Files, FolderPath "\*.*", "R"  ; Recursively loop through all files
        {
            folderText .= "`n======`n" ProcessFile(A_LoopFileFullPath)
        }
    } else {
        folderText := "`n======`nFolder does not contains files"
    }

    return folderText
}

ProcessFile(FilePath) {
    ; Check if the file is readable as text
    if CanUseFileRead(FilePath) {
        try {
            content := FileRead(FilePath)
            return FilePath "`n------`n" content
        } catch {
            return FilePath "`n------`n[Error reading file content]"
        }
    }
    return FilePath
}

CanUseFileRead(filePath) {
    SplitPath filePath, , , &ext
    allowedExts := "txt,csv,log,ini,json,xml,html,md,ahk,bat,sh,ps1,yml,toml,cs,ts,js,jsx,tsx,py,java,kt,go,rs,php,rb,pl,swift,c,cpp,h,hpp,m,mm,elm,erl,ex,exs,clj,cljc,cljx,cl,scala,sql"
    return ext && InStr("," allowedExts ",", "," ext ",")
}

HasValue(haystack, needle) {
    if (!isObject(haystack))
        return false
    for k, v in haystack
        if (v == needle)
            return true
    return false
}
