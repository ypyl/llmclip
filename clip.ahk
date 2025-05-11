#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include AppSettings.ahk
#Include LLMClient.ahk
#Include SessionManager.ahk
#Include ClipboardParser.ahk
#Include ComSpecTool.ahk
#Include FileSystemTool.ahk
#Include WebViewManager.ahk
#Include ContextManager.ahk
#Include TrayManager.ahk

; Initialize variables

global askButton
global MyGui

; Create settings instance
global AppSettingsValue := AppSettings()

; Create session manager instance with default values from AppSettings
global SessionManagerValue := SessionManager(
    AppSettingsValue.selectedLLMTypeIndex,
    AppSettingsValue.GetSystemPromptValue(AppSettingsValue.selectedLLMTypeIndex, 1)
)

; Create clipboard parser instance
global ClipboardParserValue := ClipboardParser()

global ComSpecToolValue := ComSpecTool()
global FileSystemToolValue := FileSystemTool()

; Create WebView manager instance
global WebViewManagerValue := WebViewManager()

global ContextManagerValue := ContextManager()

; Create TrayManager instance
global TrayManagerValue := TrayManager(DisplayLLMUserInterface)

; Response area positioning variables
global responseCtrX := 400
global responseCtrY := 10
global responseCtrWidth := 790
global responseCtrHeight := 580

; PromptEdit positioning variables
global promptEditX := 10
global promptEditY := 405
global promptEditWidth := 380
global promptEditHeight := 140

guiShown := false

F3:: {
    global TrayManagerValue, MyGui, guiShown
    if (!TrayManagerValue.isRecording) {
        TrayManagerValue.StartRecording()
    } else if (!guiShown) {
        DisplayLLMUserInterface()
    } else {
        TrayManagerValue.StopRecording(MyGui, SessionManagerValue)
    }
}

RenderMarkdown(content) {
    global WebViewManagerValue
    WebViewManagerValue.RenderMarkdown(content)
}

DisplayLLMUserInterface(*) {
    global MyGui, guiShown, askButton, AppSettingsValue, SessionManagerValue, WebViewManagerValue, TrayManagerValue
    global responseCtrX, responseCtrY, responseCtrWidth, responseCtrHeight
    global promptEditX, promptEditY, promptEditWidth, promptEditHeight

    if (guiShown) {
        MyGui.Show()
        return
    }
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"
    MyGui.SetFont("s9", "Segoe UI")
    MyGui.Opt("+Resize +MinSize800x610")  ; Only main window gets resize option

    MyGui.OnEvent("Size", GuiResize)

    ; Add session selector
    sessionCombo := MyGui.Add("DropDownList", "x10 y10 w70 vSessionSelect", SessionManagerValue.sessionNames)
    sessionCombo.Value := SessionManagerValue.currentSessionIndex
    sessionCombo.OnEvent("Change", SessionChanged)

    ; Add record button
    recordButtonTitle := TrayManagerValue.isRecording ? "Stop" : "Record"
    recordButton := MyGui.Add("Button", "x90 y10 w90", recordButtonTitle)
    recordButton.OnEvent("Click", ToggleRecording)

    ; Button section moved down
    resetButton := MyGui.Add("Button", "x300 y10 w90", "Reset All")
    resetButton.OnEvent("Click", ResetAll)

    ; Add context list with reduced height
    labels := GetLabelsForContextItems()
    listBox := MyGui.Add("ListBox", "vListBox x10 y40 w380 h150 VScroll HScroll Multi", labels)
    listBox.OnEvent("Change", ListBoxSelect)  ; Add this line

    ; Context buttons moved up
    deleteButton := MyGui.Add("Button", "x10 y190 w120", "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)

    clearSelectionButton := MyGui.Add("Button", "x140 y190 w120", "Reset Selection")
    clearSelectionButton.OnEvent("Click", ResetSelection)

    clearAllButton := MyGui.Add("Button", "x270 y190 w120", "Clear Context")
    clearAllButton.OnEvent("Click", ClearAllContext)

    ; Add ListView for chat history
    chatHistory := MyGui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text"])
    chatHistory.ModifyCol(1, 30)  ; Role column width
    chatHistory.ModifyCol(2, 340) ; Text column width
    chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

    deleteMessageButton := MyGui.Add("Button", "x10 y375 w120", "Delete Selected")
    deleteMessageButton.OnEvent("Click", DeleteSelectedMessage)

    chatMessageButton := MyGui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Run Tool")
    chatMessageButton.OnEvent("Click", RunSelectedTool)

    clearHistoryButton := MyGui.Add("Button", "x270 y375 w120", "Clear History")
    clearHistoryButton.OnEvent("Click", ClearChatHistory)

    ; Prompt section with increased height
    promptEdit := MyGui.Add("Edit", "vPromptEdit x" promptEditX " y" promptEditY " w" promptEditWidth " h" promptEditHeight " Multi WantReturn", "")
    promptEdit.OnEvent("Change", PromptChange)

    ; Add LLM type selector near Reset All button
    llmTypeCombo := MyGui.Add("DropDownList", "x10 y570 w90 vLLMType", AppSettingsValue.llmTypes)
    llmTypeCombo.Value := SessionManagerValue.GetCurrentSessionLLMType()
    llmTypeCombo.OnEvent("Change", LLMTypeChanged)

    ; Add system prompt selector
    systemPromptCombo := MyGui.Add("DropDownList", "x110 y570 w100 vSystemPrompt", AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := SessionManagerValue.GetCurrentSessionSystemPrompt()
    systemPromptCombo.OnEvent("Change", SystemPromptChanged)

    askButton := MyGui.Add("Button", "x220 y570 w170 vAskLLM", "Ask LLM")
    askButton.OnEvent("Click", AskToLLM)

    ; Right panel uses the global variables
    responseCtr := MyGui.Add("Edit", "vResponseCtr x" responseCtrX " y" responseCtrY " w" responseCtrWidth " h" responseCtrHeight " -VScroll", "")

    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show("w1230 h610")

    WebViewManagerValue.Init(responseCtr)
    guiShown := true

    UpdateChatHistoryView()
}


GuiResize(thisGui, MinMax, Width, Height) {
    global WebViewManagerValue
    global responseCtrX, responseCtrY, responseCtrWidth, responseCtrHeight
    global promptEditX, promptEditY, promptEditWidth, promptEditHeight

    if (MinMax = -1)  ; If window is minimized
        return

    ; Calculate new dimensions for ResponseCtr
    responseCtrWidth := Width - 410
    responseCtrHeight := Height - 20

    ; Resize the ResponseCtr control
    thisGui["ResponseCtr"].Move(responseCtrX, responseCtrY, responseCtrWidth, responseCtrHeight)

    ; Resize the WebView2 control to match ResponseCtr
    hCtrl := thisGui["ResponseCtr"].Hwnd
    rect := Buffer(16, 0)  ; RECT: left, top, right, bottom
    DllCall("GetClientRect", "ptr", hCtrl, "ptr", rect)

    widthResponseCtr := NumGet(rect, 8, "Int")   ; right
    heightResponseCtr := NumGet(rect, 12, "Int") ; bottom
    ; Set bounds relative to the ResponseCtr — top-left is (0,0)
    wvRect := Buffer(16, 0)
    NumPut("Int", 0, wvRect, 0)                          ; left
    NumPut("Int", 0, wvRect, 4)                          ; top
    NumPut("Int", widthResponseCtr, wvRect, 8)           ; right
    NumPut("Int", heightResponseCtr, wvRect, 12)         ; bottom
    if guiShown {
        WebViewManagerValue.Resize(wvRect)
    }

    ; Resize the prompt edit control
    bottomControlsHeight := 40  ; Height reserved for bottom controls
    promptEditHeight := Height - promptEditY - bottomControlsHeight
    thisGui["PromptEdit"].Move(promptEditX, promptEditY, promptEditWidth, promptEditHeight)

    ; Move bottom controls
    bottomY := Height - 35  ; 35 pixels from bottom
    thisGui["LLMType"].Move(10, bottomY)
    thisGui["SystemPrompt"].Move(110, bottomY)
    thisGui["AskLLM"].Move(220, bottomY)
}


GetLabelsForContextItems() {
    context := SessionManagerValue.GetCurrentSessionContext()
    labels := []
    for item in context {
        labels.Push(ContextManagerValue.GetLabelFromContextItem(item))
    }
    return labels
}

SystemPromptChanged(*) {
    global MyGui, SessionManagerValue, AppSettingsValue
    SessionManagerValue.SetCurrentSessionSystemPrompt(MyGui["SystemPrompt"].Value)

    ; Update the system prompt content
    systemPrompt := AppSettingsValue.GetSystemPromptValue(
        SessionManagerValue.GetCurrentSessionLLMType(),
        SessionManagerValue.GetCurrentSessionSystemPrompt()
    )
    inputTemplate := AppSettingsValue.GetInputTemplate(
        SessionManagerValue.GetCurrentSessionLLMType(),
        SessionManagerValue.GetCurrentSessionSystemPrompt()
    )
    MyGui["PromptEdit"].Value := inputTemplate  ; Set the prompt edit value to the input template
    SessionManagerValue.UpdateSystemPromptContent(systemPrompt)
}

LLMTypeChanged(*) {
    global MyGui, AppSettingsValue, SessionManagerValue
    SessionManagerValue.SetCurrentSessionLLMType(MyGui["LLMType"].Value)

    systemPromptCombo := MyGui["SystemPrompt"]
    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := 1  ; Reset to first prompt when LLM type changes
    SessionManagerValue.SetCurrentSessionSystemPrompt(1)
}

; Update session switching function
SessionChanged(*) {
    global MyGui, AppSettingsValue, SessionManagerValue

    ; Switch to new session
    SessionManagerValue.SwitchSession(MyGui["SessionSelect"].Value)

    UpdateContextView()
    UpdateChatHistoryView()

    ; Update LLM type and system prompt selections
    MyGui["LLMType"].Value := SessionManagerValue.GetCurrentSessionLLMType()

    ; Update system prompts for the selected LLM type
    systemPromptCombo := MyGui["SystemPrompt"]
    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := SessionManagerValue.GetCurrentSessionSystemPrompt()

    ; Clear response field
    RenderMarkdown("")  ; Clear the response area
}

UpdateContextView(*) {
    ; Update local references
    labels := GetLabelsForContextItems()

    ; Update UI
    listBox := MyGui["ListBox"]
    listBox.Delete()
    listBox.Add(labels)
}

UpdateChatHistoryView(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessagesAsStrings()
    chatHistory := MyGui["ChatHistory"]
    chatHistory.Delete()
    for msg in messages {
        chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""))
    }
    MyGui["ChatMessageActionButton"].Visible := false  ; Hide the Run Tool button
}

AskToLLM(*) {
    global TrayManagerValue
    messages := SessionManagerValue.GetCurrentSessionMessages()
    promptText := MyGui["PromptEdit"].Value
    if (promptText != "") {
        messages.Push({ role: "user", content: promptText })
    }
    SendToLLM()
    MyGui["PromptEdit"].Value := ""  ; Clear prompt field

    if (TrayManagerValue.isRecording) {
        TrayManagerValue.StopRecording(MyGui, SessionManagerValue)
    }
}

SendToLLM() {
    messages := SessionManagerValue.GetCurrentSessionMessages()

    ; Update the system prompt content
    systemPrompt := AppSettingsValue.GetSystemPromptValue(
        SessionManagerValue.GetCurrentSessionLLMType(),
        SessionManagerValue.GetCurrentSessionSystemPrompt()
    )
    SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

    context := SessionManagerValue.GetCurrentSessionContext()

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

        ; Only add general context if there is any non-selected content
        if (contextText != "") {
            messages[1].content .= "`n`nHere is the context:`n`n" contextText "`n`nPlease consider this context when answering the following question."
        }

        ; Add selected items as special focus points
        if (selectedIndices.Length > 0) {
            messages[1].content .= "`nThe user has selected the folloing text which may be particularly relevant:`n`n"
            for index in selectedIndices {
                messages[1].content .= GetTextFromContextItem(context[index]) "`n`n"
            }
        }
    }

    ; Disable Ask LLM button while processing
    if (MyGui) {
        askButton.Enabled := false
    }

    try {
        ; Create LLM client if it doesn't exist yet
        LLMClientInstance := LLMClient(AppSettingsValue.GetSelectedSettings(SessionManagerValue.GetCurrentSessionLLMType()))

        ; The LLM client now returns fully-formed messages
        newMessages := LLMClientInstance.Call(messages)

        ; Simply add the new messages to the session
        for newMessage in newMessages {
            messages.Push(newMessage)
        }
    } finally {
        ; Re-enable Ask LLM button
        if (MyGui) {
            askButton.Enabled := true
        }
    }
    UpdateChatHistoryView()  ; Update the chat history view

    ; Render the last message in the series of responses
    if (messages.Length > 0) {
        RenderMarkdown(SessionManagerValue.GetMessageAsString(messages[messages.Length]))
    }
}

GetTextFromContextItem(item) {
    global WebViewManagerValue
    return ContextManagerValue.GetTextFromContextItem(item, (url) => WebViewManagerValue.LoadArticle(url))
}

GuiClose(*) {
    global MyGui, guiShown
    MyGui.Destroy()
    guiShown := false
}

ListBoxSelect(*) {
    global MyGui
    context := SessionManagerValue.GetCurrentSessionContext()
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

    RenderMarkdown(textContent)  ; Render the selected item(s) in the WebView
}

DeleteSelected(*) {
    global MyGui
    context := SessionManagerValue.GetCurrentSessionContext()
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
    labels := GetLabelsForContextItems()
    listBox.Add(labels)
}

ResetSelection(*) {
    global MyGui
    MyGui["ListBox"].Value := 0  ; Set selection to 0 to clear it
}

ClearChatHistory(*) {
    global MyGui, SessionManagerValue, AppSettingsValue
    SessionManagerValue.ClearCurrentMessages()

    ; Update the system prompt content after clearing
    systemPrompt := AppSettingsValue.GetSystemPromptValue(
        SessionManagerValue.GetCurrentSessionLLMType(),
        SessionManagerValue.GetCurrentSessionSystemPrompt()
    )
    SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

    UpdateChatHistoryView()  ; Update the chat history view
    RenderMarkdown("")  ; Clear the response area
}

ResetAll(*) {
    global MyGui, SessionManagerValue

    ; Reset current session
    SessionManagerValue.ResetCurrentSession()

    ; Update UI
    UpdateChatHistoryView()
    UpdateContextView()

    ; Clear response and prompt
    RenderMarkdown("")  ; Clear the response area
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
    messages := SessionManagerValue.GetCurrentSessionMessages()
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
    global TrayManagerValue, MyGui, guiShown, SessionManagerValue, ClipboardParserValue
    if (TrayManagerValue.isRecording) {
        localTxtFromClipboardArray := ClipboardParserValue.Parse()

        ; Add non-duplicate items to context
        context := SessionManagerValue.GetCurrentSessionContext()
        for item in localTxtFromClipboardArray {
            if !HasContent(context, item)
                context.Push(item)
        }

        ; Update session contexts
        SessionManagerValue.SetCurrentSessionContext(context)

        ; Update ListBox in GUI if shown
        if (guiShown) {
            listBox := MyGui["ListBox"]
            listBox.Delete()
            labels := GetLabelsForContextItems()
            listBox.Add(labels)
        }
    }
}

ChatHistorySelect(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        msg := messages[focused_row]
        MyGui["ChatMessageActionButton"].Visible := true  ; Show the Run Tool button
        RenderMarkdown(SessionManagerValue.GetMessageAsString(msg))  ; Render the selected message in the WebView

        MyGui["ChatMessageActionButton"].Text := SessionManagerValue.HasToolCalls(msg) ? "Run Tool" : "Copy"
    }
}

RunSelectedTool(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        msg := messages[focused_row]
        tool_calls := SessionManagerValue.GetToolCalls(msg)
        if (tool_calls.Length = 0) {
            ; No tool calls, just copy the message
            A_Clipboard := msg.content
            return
        }
        try {
            MyGui["ChatMessageActionButton"].Enable := false
            for tool_call in tool_calls {
                if result := ComSpecToolValue.ExecuteToolCall(tool_call) {
                    messages.Push(result)
                }
                if result := FileSystemToolValue.ExecuteToolCall(tool_call) {
                    messages.Push(result)
                }
            }
            RenderMarkdown(SessionManagerValue.GetMessageAsString(messages[messages.Length]))  ; Render the response in the WebView
            UpdateChatHistoryView()
        } finally {
            MyGui["ChatMessageActionButton"].Enable := true
        }
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
            AskToLLM()
            return true
        }
    }
}

ClearAllContext(*) {
    global MyGui, SessionManagerValue

    SessionManagerValue.SetCurrentSessionContext([])
    UpdateContextView()
}

ToggleRecording(*) {
    global TrayManagerValue, MyGui
    TrayManagerValue.ToggleRecording(MyGui, SessionManagerValue)
}

DeleteSelectedMessage(*) {
    global MyGui, SessionManagerValue
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]

    selectedIndices := []
    focused_row := 0

    ; Collect all selected rows
    while (focused_row := chatHistory.GetNext(focused_row))
        if (focused_row > 1)  ; Don't include system message
            selectedIndices.InsertAt(1, focused_row)

    ; Remove messages in reverse order to maintain correct indices
    for index in selectedIndices
        messages.RemoveAt(index)

    UpdateChatHistoryView()
    RenderMarkdown("")  ; Clear the response area
}
