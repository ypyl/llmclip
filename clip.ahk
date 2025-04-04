#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include <Json>
#Include settings.ahk
; There is a content of settings.ahk file that you can create near the current script file.
; It contains the function GetLLMSettings() that returns a map with settings for different LLMs.
; GetLLMSettings()
; {
;     return Map(
;         "groq", Map(
;             "curl", 'curl -s -S -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer <<KEY>" -d "@{1}" -o "{2}"',
;             "model", "llama-3.3-70b-versatile",
;             "temperature", 0.7,
;             "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
;         ),
;         "google", Map(
;             "curl", 'curl -s -S -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=<<KEY>>" -H "Content-Type: application/json" -d "@{1}" -o "{2}"',
;             "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
;             "temperature", 0.7,
;         ))
; }


; cURL is also should be installed as it is used to actually call LLM providers. Please install it using:`nwinget install cURL.cURL`nor visit https://curl.se/download.html

; Initialize variables
global askButton
global MyGui
settings := GetLLMSettings()
llmTypes := []
for key in settings {
    llmTypes.Push(key)
}
selectedIndex := 1
GetSelectedSettings() {
    global selectedIndex, llmTypes, settings
    selectedLLMType := llmTypes[selectedIndex]
    selectedSettings := settings[selectedLLMType]
    return selectedSettings
}

; Add session management
global currentSessionIndex := 1
global MAX_SESSIONS := 3
global sessionNames := ["Session 1", "Session 2", "Session 3"]
global sessionMessages := []
global sessionContexts := []

; Initialize session arrays
Loop MAX_SESSIONS {
    defaultSystemMessage := "You are a helpful assistant. Be concise and direct in your responses."
    if GetSelectedSettings().Get("system_prompt", "") {
        defaultSystemMessage := GetSelectedSettings()["system_prompt"]
    }
    sessionMessages.Push([{
        role: "system",
        content: defaultSystemMessage
    }])
    sessionContexts.Push([])
}

defaultSystemMessage := "You are a helpful assistant. Be concise and direct in your responses."
if GetSelectedSettings().Get("system_prompt", "") {
    defaultSystemMessage := GetSelectedSettings()["system_prompt"]
}
isRecording := false
context := sessionContexts[currentSessionIndex]
guiShown := false
messages := sessionMessages[currentSessionIndex]

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

; Set default tray icon and tooltip
SetTrayStatus(false)  ; Default state (not recording)

OnMessage(0x404, TrayIconClick)

TrayIconClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202) {  ; Left click
        if (isRecording) {
            StopRecording()  ; Stop recording
        } else {
            StartRecording()  ; Start recording
        }
    }
}

SetTrayStatus(isRecording) {
    if (isRecording) {
        TraySetIcon("shell32.dll", 294)  ; Red circle (recording)
        A_IconTip := "📍 Recording Clipboard..."
        A_TrayMenu.Disable("Start Recording")
        A_TrayMenu.Enable("Stop Recording")
    } else {
        TraySetIcon("shell32.dll", 171)  ; Default clipboard icon
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
            recordedText .= GetTextFromContextItem(item)
        }
        A_Clipboard := recordedText  ; Copy recorded text to clipboard
    }
}

AskLLM(*) {
    global context, MyGui, guiShown, askButton, selectedIndex, llmTypes, currentSessionIndex, MAX_SESSIONS, sessionNames
    if (guiShown) {
        MyGui.Show()
        return
    }
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"

    ; Add LLM type selector at the top
    MyGui.Add("Text", "x20 y15", "LLM Type:")
    llmTypeCombo := MyGui.Add("ComboBox", "x90 y12 w120 vLLMType", llmTypes)
    llmTypeCombo.Value := selectedIndex
    llmTypeCombo.OnEvent("Change", LLMTypeChanged)

    ; Add session selector
    MyGui.Add("Text", "x230 y15", "Session:")
    sessionCombo := MyGui.Add("ComboBox", "x280 y12 w120 vSessionSelect", sessionNames)
    sessionCombo.Value := currentSessionIndex
    sessionCombo.OnEvent("Change", SessionChanged)

    ; Add context list with reduced height
    listBox := MyGui.Add("ListBox", "vListBox x20 y45 w380 h150 VScroll Multi", context)
    listBox.OnEvent("Change", ListBoxSelect)  ; Add this line

    ; Context buttons moved up
    clearAllButton := MyGui.Add("Button", "x20 y205 w120", "Clear All")
    clearAllButton.OnEvent("Click", ClearAllContext)

    clearSelectionButton := MyGui.Add("Button", "x150 y205 w120", "Clear Selection")
    clearSelectionButton.OnEvent("Click", ClearSelection)

    deleteButton := MyGui.Add("Button", "x280 y205 w120", "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)

    ; Add ListView for chat history
    chatHistory := MyGui.Add("ListView", "vChatHistory x20 y245 w380 h150 NoSort", ["Role", "Text"])
    chatHistory.ModifyCol(1, 60)  ; Role column width
    chatHistory.ModifyCol(2, 290) ; Text column width
    chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

    clearHistoryButton := MyGui.Add("Button", "x20 y405 w380", "Clear Chat History")
    clearHistoryButton.OnEvent("Click", ClearChatHistory)

    ; Prompt section with increased height
    promptEdit := MyGui.Add("Edit", "vPromptEdit x20 y445 w380 h140 Multi WantReturn")  ; Add WantReturn option
    promptEdit.OnEvent("Change", PromptChange)

    ; Button section moved down
    resetButton := MyGui.Add("Button", "x20 y595 w90", "Reset All")
    resetButton.OnEvent("Click", ResetAll)

    askButton := MyGui.Add("Button", "x120 y595 w280", "Ask LLM")
    askButton.OnEvent("Click", SendToLLM)

    ; Right panel remains unchanged
    MyGui.Add("Edit", "vResponse x420 y45 w790 h590 ReadOnly Multi VScroll Wrap", "")

    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show("w1230 h650")
    guiShown := true

    UpdateChatHistoryView()
}

LLMTypeChanged(*) {
    global MyGui, llmTypes, selectedIndex
    selectedIndex := MyGui["LLMType"].Value
}

; Add session switching function
SessionChanged(*) {
    global MyGui, currentSessionIndex, context, messages, sessionContexts, sessionMessages

    ; Save current session data
    sessionContexts[currentSessionIndex] := context.Clone()
    sessionMessages[currentSessionIndex] := messages.Clone()

    ; Switch to new session
    currentSessionIndex := MyGui["SessionSelect"].Value
    context := sessionContexts[currentSessionIndex]
    messages := sessionMessages[currentSessionIndex]

    ; Update UI
    listBox := MyGui["ListBox"]
    listBox.Delete()
    listBox.Add(context)

    UpdateChatHistoryView()

    ; Clear response field
    MyGui["Response"].Value := ""
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

    ; Update context in system message if needed
    if (context.Length > 0) {
        contextText := ""
        selectedIndices := []

        ; Get selected indices
        if (listBox.Value is Array) {
            selectedIndices := listBox.Value
        } else if (listBox.Value) {
            selectedIndices := [listBox.Value]
        }

        ; Build context excluding selected items
        for index, item in context {
            if !HasVal(selectedIndices, index) {
                contextText .= GetTextFromContextItem(item)
            }
        }
        messages[1].content := "You are a helpful assistant. Here is the context:`n" contextText "`n\nPlease consider this context when answering the following question."

        ; Add selected items as special focus points
        if (selectedIndices.Length > 0) {
            messages[1].content .= "`n\nThe user has selected these items which may be particularly relevant:`n"
            for index in selectedIndices {
                messages[1].content .= GetTextFromContextItem(context[index]) "`n"
            }
        }
    }

    messages.Push({ role: "user", content: promptText })

    try {
        assistantResponse := CallLLM(messages)
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
        itemText := "======`n" ProcessFolder(item)
    else if (FileExist(item))
        itemText := "======`n" ProcessFile(item)
    else
        itemText := "======`n" item "`n"
    return itemText
}

GetRequestBody(type, messages, settings) {
    body := Map()
    if (type = "groq" || type = "azure") {
        if (model := settings.Get("model", ""))
            body["model"] := model
        body["messages"] := messages
        body["temperature"] := settings.Get("temperature", 0.7)
    } else if (type = "google") {
        contents := []
        systemMessage := ""

        ; First, find and handle system message
        for msg in messages {
            if (msg.role = "system") {
                systemMessage := msg
                break
            }
        }

        ; Add system instruction if present
        if (systemMessage) {
            body["system_instruction"] := {
                parts: [{
                    text: systemMessage.content
                }]
            }
        }

        ; Add other messages to contents
        for msg in messages {
            if (msg.role != "system") { ; Skip system messages as they're handled separately
                contents.Push({
                    role: msg.role = "assistant" ? "model" : msg.role,
                    parts: [{
                        text: msg.content
                    }]
                })
            }
        }

        body["contents"] := contents
        body["generationConfig"] := {
            stopSequences: settings.Get("stopSequences", ["Title"]),
            temperature: settings.Get("temperature", 1.0),
            maxOutputTokens: settings.Get("maxOutputTokens", 800),
            topP: settings.Get("topP", 0.8),
            topK: settings.Get("topK", 10)
        }
    }
    return body
}

CallLLM(messages) {
    global selectedIndex, llmTypes
    try {
        selectedSettings := GetSelectedSettings()
        curl := selectedSettings["curl"]

        ; Disable Ask LLM button and show progress
        if (MyGui) {
            askButton.Enabled := false  ; Disable Ask LLM button
        }

        ; Prepare request body
        body := GetRequestBody(llmTypes[selectedIndex], messages, selectedSettings)

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
        curlCmd := Format(curl, inputFile, outputFile)
        ; Execute curl
        RunWait(curlCmd, , "Hide")

        ; Show error if response file doesn't exist
        if (!FileExist(outputFile)) {
            if (MyGui)
                MyGui["Response"].Value := "Error: No response received from API"
            throw Error("No response file created")
        }

        ; Read response
        if FileExist(outputFile) {
            response := FileRead(outputFile)
            if (response != "") {
                obj := JSON.Load(response)
                if (obj.Has("candidates") && obj["candidates"].Length > 0) {
                    candidate := obj["candidates"][1]
                    if (candidate.Has("content") && candidate["content"].Has("parts") && candidate["content"]["parts"].Length > 0) {
                        return candidate["content"]["parts"][1]["text"]
                    }
                }
                return obj["choices"][1]["message"]["content"]
            }
        }
        throw Error("No response received")

    } catch as e {
        if (MyGui)
            MyGui["Response"].Value := "Error calling LLM: " e.Message
        throw Error("Error calling LLM: " e.Message)
    } finally {
        ; Re-enable Ask LLM button
        if (MyGui)
            askButton.Enabled := true

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
    selectedItems := []
    textContent := ""

    ; Handle multi-select values
    if (listBox.Value is Array) {
        ; Process multiple selections
        for index in listBox.Value {
            selectedItems.Push(context[index])
        }
    } else if (listBox.Value) {
        ; Single selection
        selectedItems.Push(context[listBox.Value])
    }

    ; Process each selected item
    for item in selectedItems {
        textContent .= GetTextFromContextItem(item) "`n"
    }

    MyGui["Response"].Value := textContent
}

DeleteSelected(*) {
    global context, MyGui
    listBox := MyGui["ListBox"]
    selectedIndices := []

    ; Handle multi-select values
    if (listBox.Value is Array) {
        ; Get indices in reverse order (to avoid index shifting when removing)
        for index in listBox.Value {
            selectedIndices.InsertAt(1, index)
        }
    } else if (listBox.Value) {
        selectedIndices.Push(listBox.Value)
    }

    ; Remove selected items
    for index in selectedIndices {
        context.RemoveAt(index)
    }

    ; Refresh the listbox
    listBox.Delete()
    listBox.Add(context)
}

ClearSelection(*) {
    global MyGui
    MyGui["ListBox"].Value := 0  ; Set selection to 0 to clear it
}

ClearChatHistory(*) {
    global messages, MyGui, defaultSystemMessage, currentSessionIndex, sessionMessages

    ; Reset just the current session
    defaultSystemMessage := "You are a helpful assistant. Be concise and direct in your responses."
    if GetSelectedSettings().Get("system_prompt", "") {
        defaultSystemMessage := GetSelectedSettings()["system_prompt"]
    }

    messages := [{
        role: "system",
        content: defaultSystemMessage
    }]

    ; Update the session storage
    sessionMessages[currentSessionIndex] := messages.Clone()

    UpdateChatHistoryView()  ; Update the chat history view
    MyGui["Response"].Value := ""  ; Clear response area
}

ResetAll(*) {
    global MyGui, messages, context, defaultSystemMessage, currentSessionIndex, sessionMessages, sessionContexts

    ; Clear chat history for current session
    defaultSystemMessage := "You are a helpful assistant. Be concise and direct in your responses."
    if GetSelectedSettings().Get("system_prompt", "") {
        defaultSystemMessage := GetSelectedSettings()["system_prompt"]
    }

    messages := [{
        role: "system",
        content: defaultSystemMessage
    }]
    sessionMessages[currentSessionIndex] := messages.Clone()
    UpdateChatHistoryView()

    ; Clear context for current session
    context := []
    sessionContexts[currentSessionIndex] := []
    listBox := MyGui["ListBox"]
    listBox.Delete()

    ; Clear response and prompt
    MyGui["Response"].Value := ""
    MyGui["PromptEdit"].Value := ""
}

ExitApp(*) {
    ExitApp
}

HasVal(haystack, needle) {
    for index, value in haystack {
        if (value = needle)
            return true
    }
    return false
}

HasContent(haystack, newContent) {
    if (newContent = "")
        return true

    ; First check exact matches
    if (HasVal(haystack, newContent))
        return true

    ; Also check in chat history
    for msg in messages {
        v := InStr(msg.content, newContent)
        if (v)
            return true
    }

    ; Then check content matches for files and folders
    newContentText := GetTextFromContextItem(newContent)
    for item in haystack {
        if (GetTextFromContextItem(item) = newContentText)
            return true
    }

    return false
}

OnClipboardChange ClipChanged

ClipChanged(DataType) {
    global isRecording, context, MyGui, guiShown, messages
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
                txtFromClipboard := StrReplace(txtFromClipboard, "`r`n", "`n")
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
        ; Add non-duplicate items to context
        for item in localTxtFromClipboardArray {
            if !HasContent(context, item)
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
            folderText .= "======`n" ProcessFile(A_LoopFileFullPath) "`n"
        }
    } else {
        folderText := "======`nFolder does not contains files`n"
    }

    return folderText
}

ProcessFile(FilePath) {
    ; Check if the file is readable as text
    if CanUseFileRead(FilePath) {
        try {
            content := FileRead(FilePath)
            return FilePath "------`n" content "------`n"
        } catch {
            return FilePath "------`n[Error reading file content]`n"
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

ClearAllContext(*) {
    global context, MyGui, currentSessionIndex, sessionContexts
    context := []
    sessionContexts[currentSessionIndex] := []
    listBox := MyGui["ListBox"]
    listBox.Delete()
}
