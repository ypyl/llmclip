#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn

; Initialize variables
isRecording := false
context := []
guiShown := false
messages := [{
    role: "system",
    content: "You are a helpful assistant. Be concise and direct in your responses."
}]
global MyGui
#Include settings.ahk
; GetLLMSettings()
; {
;     return Map(
;         "endpoint", "https://api.groq.com/openai/v1/chat/completions",
;         "api_key", "<<KEY>",
;         "model", "llama-3.3-70b-versatile"
;     )
; }

settings := Map(
    "settings", GetLLMSettings()
)

A_TrayMenu.Delete()  ; Remove default menu items
A_TrayMenu.Add("Start Recording", StartRecording)
A_TrayMenu.Add("Stop Recording", StopRecording)
A_TrayMenu.Add("Ask LLM", AskLLM)
A_TrayMenu.Add("Exit", ExitApp)

F3:: {
    global isRecording, MyGui, guiShown
    if (!isRecording) {
        StartRecording()
    } else if (!guiShown) {
        AskLLM()
    } else {
        StopRecording()
    }
}

#Include <Json>

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
    } else {
        TraySetIcon("shell32.dll", 177)  ; Default clipboard icon
        A_IconTip := ""
        A_TrayMenu.Enable("Start Recording")
        A_TrayMenu.Disable("Stop Recording")
    }
}

StartRecording(*) {
    global isRecording, context
    if (!isRecording) {
        isRecording := true
        context := []
        SetTrayStatus(true)  ; Update icon & tooltip
    }
}

StopRecording(*) {
    global isRecording, context
    if (isRecording) {
        isRecording := false
        SetTrayStatus(false)  ; Update icon & tooltip
        recordedText := ""  ; Clear recorded text
        for item in context {
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

AskLLM(*) {
    global context, MyGui, guiShown
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"

    ; Create left panel for context with reduced height
    leftPanel := MyGui.Add("GroupBox", "x10 y10 w400 h180", "Context")

    ; Add context list with reduced height
    listBox := MyGui.Add("ListBox", "vListBox x20 y30 w380 h120 VScroll", context)
    listBox.OnEvent("Change", ListBoxSelect)  ; Add this line

    ; Context buttons moved up
    deleteButton := MyGui.Add("Button", "x20 y160 w185", "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)

    clearSelectionButton := MyGui.Add("Button", "x215 y160 w185", "Clear Selection")
    clearSelectionButton.OnEvent("Click", ClearSelection)

    ; Create left panel for chat history, moved up
    historyPanel := MyGui.Add("GroupBox", "x10 y200 w400 h220", "Chat History")

    ; Add ListView for chat history
    chatHistory := MyGui.Add("ListView", "vChatHistory x20 y220 w380 h160 NoSort", ["Role", "Text"])
    chatHistory.ModifyCol(1, 60)  ; Role column width
    chatHistory.ModifyCol(2, 290) ; Text column width
    chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

    clearHistoryButton := MyGui.Add("Button", "x20 y390 w380", "Clear Chat History")
    clearHistoryButton.OnEvent("Click", ClearChatHistory)

    ; Prompt section with increased height
    MyGui.Add("GroupBox", "x10 y430 w400 h200", "Your prompt")
    promptEdit := MyGui.Add("Edit", "vPromptEdit x20 y450 w380 h140 Multi WantReturn")  ; Add WantReturn option
    promptEdit.OnEvent("Change", PromptChange)

    ; Button section moved down
    askButton := MyGui.Add("Button", "x20 y600 w380", "Ask LLM")
    askButton.OnEvent("Click", SendToLLM)

    ; Right panel remains unchanged
    rightPanel := MyGui.Add("GroupBox", "x420 y10 w800 h610", "LLM Response")
    MyGui.Add("Edit", "vResponse x430 y30 w780 h580 ReadOnly Multi VScroll Wrap", "")

    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show("w1230 h640")
    guiShown := true

    UpdateChatHistoryView()
}

UpdateChatHistoryView(*) {
    global MyGui, messages
    chatHistory := MyGui["ChatHistory"]
    chatHistory.Delete()
    for msg in messages {
        chatHistory.Add(, msg.role, SubStr(msg.content, 1, 50) (StrLen(msg.content) > 50 ? "..." : ""))
    }
}

SendToLLM(*) {
    global MyGui, messages, context
    promptText := MyGui["PromptEdit"].Value
    listBox := MyGui["ListBox"]
    selectedIndex := listBox.Value

    ; Update context in system message if needed
    if (context.Length > 0) {
        contextText := ""
        ; Skip selected item when building context
        for index, item in context {
            if (index != selectedIndex) {
                contextText .= GetTextFromContextItem(item)
            }
        }
        messages[1].content := "You are a helpful assistant. Here is the context:`n" contextText "`n\nPlease consider this context when answering the following question."
    }

    ; Check for selected text and add it as a special focus point
    listBox := MyGui["ListBox"]
    selectedIndex := listBox.Value
    if (selectedIndex > 0) {
        selectedItem := context[selectedIndex]
        selectedText := GetTextFromContextItem(selectedItem)
        messages[1].content .= "`n\nThe user has selected this text which may be particularly relevant: " selectedText
    }

    messages.Push({ role: "user", content: promptText })

    try {
        assistantResponse := CallLLM("settings", messages)
        messages.Push({ role: "assistant", content: assistantResponse })
        MyGui["Response"].Value := assistantResponse
        UpdateChatHistoryView()  ; Update the chat history view
    } catch as e {
        MyGui["Response"].Value := "Error: " e.Message
    }
}

GetTextFromContextItem(item) {
    itemText := ""
    if (DirExist(item))
        itemText := "`n======`n" ProcessFolder(item)
    else if (FileExist(item))
        itemText := "`n======`n" ProcessFile(item)
    else
        itemText := "`n======`n" item
    return itemText
}

CallLLM(provider, messages) {
    try {
        endpoint := settings[provider]["endpoint"]
        apiKey := settings[provider]["api_key"]
        model := settings[provider].Get("model", "")

        ; Prepare request body
        body := {}
        if (model)
            body.model := model
        body.messages := messages
        body.temperature := 0.7

        ; Create temporary files for input/output
        tempDir := A_Temp "\llmclip"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        inputFile := tempDir "\request.json"
        outputFile := tempDir "\response.json"

        ; Write request body to temp file
        try FileDelete(inputFile)
        FileAppend(JSON.Dump(body), inputFile)

        ; Prepare curl command
        curlCmd := model ?
            Format('curl -s -S -X POST "{1}" -H "Content-Type: application/json" -H "Authorization: Bearer {2}" -d "@{3}" -o "{4}"',
                endpoint, apiKey, inputFile, outputFile) :
            Format('curl -s -S -X POST "{1}" -H "Content-Type: application/json" -H "api-key: {2}" -d "@{3}" -o "{4}"',
                endpoint, apiKey, inputFile, outputFile)

        ; Execute curl
        RunWait(curlCmd, , "Hide")

        ; Read response
        if FileExist(outputFile) {
            response := FileRead(outputFile)
            if (response != "") {
                obj := JSON.Load(response)
                return obj["choices"][1]["message"]["content"]
            }
        }
        throw Error("No response received")

    } catch as e {
        throw Error("Error calling LLM: " e.Message)
    } finally {
        ; Cleanup temp files
        try {
            FileDelete(inputFile)
            FileDelete(outputFile)
        }
    }
}

GuiClose(*) {
    global MyGui, guiShown
    MyGui.Destroy()
    guiShown := false
}

ListBoxSelect(*) {
    global MyGui, context
    listBox := MyGui["ListBox"]
    selectedIndex := listBox.Value
    if (selectedIndex > 0) {
        selectedItem := context[selectedIndex]
        textContent := GetTextFromContextItem(selectedItem)
        MyGui["Response"].Value := textContent
    }
}

DeleteSelected(*) {
    global context, MyGui
    listBox := MyGui["ListBox"]
    selectedIndex := listBox.Value
    if (selectedIndex > 0) {
        context.RemoveAt(selectedIndex)
        listBox.Delete()
        listBox.Add(context)
    }
}

ClearSelection(*) {
    global MyGui
    MyGui["ListBox"].Value := 0  ; Set selection to 0 to clear it
}

ClearChatHistory(*) {
    global messages, MyGui
    messages := [{
        role: "system",
        content: "You are a helpful assistant. Be concise and direct in your responses."
    }]
    UpdateChatHistoryView()  ; Update the chat history view
    MyGui["Response"].Value := ""  ; Clear response area
}

ExitApp(*) {
    ExitApp
}

OnClipboardChange ClipChanged

ClipChanged(DataType) {
    global isRecording, context, MyGui, guiShown
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

        ; MsgBox "Clipboard processed as: " txtFromClipboard
        for item in localTxtFromClipboardArray {
            context.Push(item)
        }

        ; Update ListBox in GUI if shown
        if (guiShown) {
            listBox := MyGui["ListBox"]
            listBox.Delete()
            listBox.Add(context)
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

ChatHistorySelect(*) {
    global MyGui, messages
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        MyGui["Response"].Value := messages[focused_row].content
    }
}

PromptChange(GuiCtrl, Info) {
    if (GetKeyState("Enter") && !GetKeyState("Shift")) {
        ; Get the last character
        text := GuiCtrl.Value
        if (SubStr(text, -1) == "`n") {
            ; Remove the trailing newline
            GuiCtrl.Value := SubStr(text, 1, -1)
            ; Send the prompt
            SendToLLM()
            return true
        }
    }
}
