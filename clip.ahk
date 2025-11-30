#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include AppSettings.ahk
#Include LLMClient.ahk
#Include SessionManager.ahk
#Include ClipboardParser.ahk
#Include PowerShellTool.ahk
#Include WebViewManager.ahk
#Include ContextManager.ahk
#Include TrayManager.ahk
#Include UIConfig.ahk
#Include UIBuilder.ahk

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

global PowerShellToolValue := PowerShellTool()

; Create WebView manager instance
global WebViewManagerValue := WebViewManager()

global ContextManagerValue := ContextManager()

; Create TrayManager instance
global TrayManagerValue := TrayManager(DisplayLLMUserInterface, UpdateUiBasesOnRecordingStatus)

global LLMClientInstance := ""

; Response area positioning variables
global responseCtrX := 400
global responseCtrY := 10
global responseCtrWidth := 790
global responseCtrHeight := 580

; PromptEdit positioning variables
global promptEditX := 10
global promptEditY := 405
global promptEditWidth := 380
global promptEditHeight := 120

; Bottom controls positioning
global llmTypeX := 10
global llmTypeY := 570
global llmTypeWidth := 90
global systemPromptX := 110
global systemPromptY := 570
global systemPromptWidth := 100
global askLLMX := 220
global askLLMY := 570
global askLLMWidth := 170
global bottomControlsHeight := 60  ; Height reserved for bottom controls

guiShown := false
DisplayLLMUserInterface()

F3:: {
    global TrayManagerValue, MyGui, guiShown
    if (!TrayManagerValue.isRecording) {
        TrayManagerValue.StartRecording()
    } else if (!guiShown) {
        DisplayLLMUserInterface()
    } else {
        TrayManagerValue.StopRecording(SessionManagerValue)
    }
}

RenderMarkdown(content) {
    global WebViewManagerValue
    WebViewManagerValue.RenderMarkdown(content)
}

UpdateUiBasesOnRecordingStatus(*) {
    if (guiShown) {
        if (TrayManagerValue.isRecording) {
            MyGui["Record"].Text := "Stop"
        } else {
            MyGui["Stop"].Text := "Record"
        }
    }
}

DisplayLLMUserInterface(*) {
    global MyGui, guiShown, askButton, AppSettingsValue, SessionManagerValue, WebViewManagerValue, TrayManagerValue
    global responseCtrX, responseCtrY, responseCtrWidth, responseCtrHeight
    global promptEditX, promptEditY, promptEditWidth, promptEditHeight
    global llmTypeX, llmTypeY, llmTypeWidth, systemPromptX, systemPromptY, systemPromptWidth, askLLMX, askLLMY,
        askLLMWidth

    if (guiShown) {
        MyGui.Show()
        return
    }
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"
    MyGui.SetFont("s9", "Segoe UI")
    MyGui.Opt("+Resize +MinSize800x610")  ; Only main window gets resize option

    MyGui.OnEvent("Size", GuiResize)

    UIBuilder.CreateMenuBar(MyGui)

    UIBuilder.CreateTopControls(MyGui, SessionManagerValue, TrayManagerValue)

    UIBuilder.CreateContextSection(MyGui)

    UIBuilder.CreateChatHistorySection(MyGui)

    UIBuilder.CreatePromptSection(MyGui, SessionManagerValue, AppSettingsValue)

    askButton := UIBuilder.CreateBottomControls(MyGui, SessionManagerValue, AppSettingsValue)

    responseCtr := UIBuilder.CreateResponseArea(MyGui)

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
    global llmTypeX, systemPromptX, askLLMX, bottomControlsHeight

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
    promptEditHeight := Height - promptEditY - bottomControlsHeight
    thisGui["PromptEdit"].Move(promptEditX, promptEditY, promptEditWidth, promptEditHeight)

    ; Move bottom controls
    bottomY := Height - 35  ; 35 pixels from bottom
    thisGui["LLMType"].Move(llmTypeX, bottomY)
    thisGui["SystemPrompt"].Move(systemPromptX, bottomY)
    thisGui["AskLLM"].Move(askLLMX, bottomY)

    ; Move PowerShell tool checkbox and icon above bottom controls
    checkBoxY := bottomY - 20
    thisGui["PowerShellIcon"].Move(llmTypeX + 40, checkBoxY)
    thisGui["PowerShellToolBox"].Move(llmTypeX, checkBoxY)
    thisGui["AnswerSizeBox"].Move(llmTypeX + 290, checkBoxY - 5)
}

GetLabelsForContextItems() {
    context := SessionManagerValue.GetCurrentSessionContext()
    predefinedContext := AppSettingsValue.GetContext(SessionManagerValue.GetCurrentSessionLLMType(),
    SessionManagerValue.GetCurrentSessionSystemPrompt())
    labels := []
    for item in predefinedContext {
        if (!HasVal(context, item)) {
            context.Push(item)
        }
    }
    SessionManagerValue.SetCurrentSessionContext(context)
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
    if (inputTemplate) {
        MyGui["PromptEdit"].Value := inputTemplate  ; Set the prompt edit value to the input template
    }
    SessionManagerValue.UpdateSystemPromptContent(systemPrompt)
    UpdateContextView()  ; Update the context view
}

LLMTypeChanged(*) {
    global MyGui, AppSettingsValue, SessionManagerValue
    SessionManagerValue.SetCurrentSessionLLMType(MyGui["LLMType"].Value)

    systemPromptCombo := MyGui["SystemPrompt"]
    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := 1  ; Reset to first prompt when LLM type changes
    SessionManagerValue.SetCurrentSessionSystemPrompt(1)

    ; Update tool checkbox based on new LLM type
    powerShellEnabled := AppSettingsValue.IsToolEnabled(SessionManagerValue.GetCurrentSessionLLMType(),
    "powerShellTool")
    MyGui["PowerShellToolBox"].Value := powerShellEnabled ? 1 : 0
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
    contextBox := MyGui["ContextBox"]
    contextBox.Delete()
    contextBox.Add(labels)
}

UpdateChatHistoryView(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessagesAsStrings()
    chatHistory := MyGui["ChatHistory"]
    chatHistory.Delete()
    for msg in messages {
        duration := msg.HasOwnProp("duration") ? Round(msg.duration, 2) . "s" : ""
        tokens := msg.HasOwnProp("tokens") ? msg.tokens : ""
        chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""), duration,
        tokens)
    }
    MyGui["ChatMessageActionButton"].Visible := false  ; Hide the Run Tool button
}

AskToLLM(*) {
    global TrayManagerValue, MyGui, ContextManagerValue, SessionManagerValue, LLMClientInstance

    ; Check if we are in "Confirm Tool Run" mode (Agent Mode tool execution)
    if (MyGui["AskLLM"].Text == "Confirm Tool Run") {
        messages := SessionManagerValue.GetCurrentSessionMessages()

        ; Find and execute all unexecuted tool calls
        executedAny := false
        for msg in messages {
            if (SessionManagerValue.HasToolCalls(msg)) {
                toolResults := ExecuteToolCalls(msg)
                if (toolResults.Length > 0) {
                    for res in toolResults {
                        messages.Push(res)
                    }
                    executedAny := true
                }
            }
        }

        if (executedAny) {
            SendToLLM()
        } else {
            ; Should not happen if button is Confirm Tool Run, but reset just in case
            MyGui["AskLLM"].Text := "Ask LLM"
        }
        return
    }

    if (MyGui["AskLLM"].Text == "Cancel") {
        if (LLMClientInstance) {
            LLMClientInstance.Cancel()
        }
        return
    }

    messages := SessionManagerValue.GetCurrentSessionMessages()
    promptText := MyGui["PromptEdit"].Value

    ; Check for regeneration case: Empty prompt + Selected message
    if (promptText == "") {
        chatHistory := MyGui["ChatHistory"]
        focused_row := chatHistory.GetNext()
        if (focused_row > 0) {
            selectedMsg := messages[focused_row]
            if (selectedMsg.role == "user") {
                ; Load message content into prompt for editing
                MyGui["PromptEdit"].Value := SessionManagerValue.GetMessageText(selectedMsg)
                return
            }
        }
    } else {
        ; Check if we are in "Edit Mode" (Prompt not empty + User message selected)
        chatHistory := MyGui["ChatHistory"]
        focused_row := chatHistory.GetNext()
        if (focused_row > 0) {
            selectedMsg := messages[focused_row]
            if (selectedMsg.role == "user") {
                ; Update the message with new content
                if (SessionManagerValue.UpdateMessage(focused_row, promptText)) {
                    ; Truncate history after this message
                    if (SessionManagerValue.TruncateMessages(focused_row)) {
                        SendToLLM()
                        MyGui["PromptEdit"].Value := ""
                        ; Clear selection to exit "Edit Mode"
                        chatHistory.Modify(focused_row, "-Select")
                        return
                    }
                }
            }
        }
    }

    userMessageContent := ""
    if (promptText != "") {
        userMessageContent := promptText
    }

    contextItems := SessionManagerValue.GetCurrentSessionContext()
    isImageEnabled := AppSettingsValue.IsImageInputEnabled(SessionManagerValue.GetCurrentSessionLLMType())

    userMessageContent := BuildUserMessage(userMessageContent, contextItems, isImageEnabled)

    if (userMessageContent != "") {
        messages.Push({ role: "user", content: userMessageContent })
    }
    SendToLLM()
    MyGui["PromptEdit"].Value := ""  ; Clear prompt field

    if (TrayManagerValue.isRecording) {
        TrayManagerValue.StopRecording(SessionManagerValue)
    }
}

SendToLLM() {
    global MyGui, SessionManagerValue, AppSettingsValue, askButton, LLMClientInstance
    messages := SessionManagerValue.GetCurrentSessionMessages()

    ; Update the system prompt content
    systemPrompt := AppSettingsValue.GetSystemPromptValue(
        SessionManagerValue.GetCurrentSessionLLMType(),
        SessionManagerValue.GetCurrentSessionSystemPrompt()
    )
    SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

    context := SessionManagerValue.GetCurrentSessionContext()
    contextBox := MyGui["ContextBox"]

    ; Build and append context message if needed
    additionalContext := BuildAdditionalContextMessage(context, contextBox.Value)
    if (additionalContext != "") {
        messages[1].content .= additionalContext
    }

    ; Disable Ask LLM button while processing
    if (MyGui) {
        askButton.Text := "Cancel"
    }

    try {
        ; Create LLM client if it doesn't exist yet
        settings := AppSettingsValue.GetSelectedSettings(SessionManagerValue.GetCurrentSessionLLMType())

        ; Update tools property based on checkbox values
        settings["tools"] := ConfigureToolSettings()
        ; Add a user message to instruct the model on answer length based on slider position
        answerSizeMsg := ""
        answerSize := MyGui["AnswerSizeBox"].Value
        if (answerSize = 0) {
            answerSizeMsg := "Please answer as concisely as possible (short answer)."
        } else if (answerSize = 2) {
            answerSizeMsg := "Please provide a long, detailed answer."
        }
        ; If answerSize = 1 (middle position), no message is added (default behavior)
        if (answerSizeMsg != "") {
            messages.Push({ role: "user", content: answerSizeMsg })
        }

        LLMClientInstance := LLMClient(settings)

        ; The LLM client now returns fully-formed messages
        startTime := A_TickCount
        newMessages := LLMClientInstance.Call(messages)
        duration := (A_TickCount - startTime) / 1000

        ; Remove the answer size instruction message after receiving the answer
        if (answerSizeMsg != "") {
            messages.RemoveAt(messages.Length)
        }

        ; Simply add the new messages to the session
        for newMessage in newMessages {
            newMessage.duration := duration
            messages.Push(newMessage)
        }

        ; Check for unexecuted Tool Calls
        if (SessionManagerValue.HasUnexecutedToolCalls()) {
            MyGui["AskLLM"].Text := "Confirm Tool Run"
        } else {
            MyGui["AskLLM"].Text := "Ask LLM"
        }

    } catch as e {
        if (e.Message == "Request cancelled") {
            ; Do nothing on cancellation
        } else {
            throw e
        }
    } finally {
        ; Re-enable Ask LLM button
        if (MyGui) {
            if (MyGui["AskLLM"].Text == "Cancel") {
                 MyGui["AskLLM"].Text := "Ask LLM"
            }
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

ContextBoxSelect(*) {
    global MyGui
    context := SessionManagerValue.GetCurrentSessionContext()
    contextBox := MyGui["ContextBox"]
    selectedItems := []
    textContent := ""

    ; Handle multi-select values
    if (contextBox.Value is Array) {
        ; Process multiple selections
        for index in contextBox.Value {
            selectedItems.Push(context[index])
        }
    } else if (contextBox.Value) {
        ; Single selection
        selectedItems.Push(context[contextBox.Value])
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
    contextBox := MyGui["ContextBox"]
    selectedIndices := []

    ; Handle multi-select values
    if (contextBox.Value is Array) {
        ; Get indices in reverse order (to avoid index shifting when removing)
        for index in contextBox.Value {
            selectedIndices.InsertAt(1, index)
        }
    } else if (contextBox.Value) {
        selectedIndices.Push(contextBox.Value)
    }

    ; Remove selected items
    for index in selectedIndices {
        context.RemoveAt(index)
    }

    ; Refresh the listbox
    contextBox.Delete()
    labels := GetLabelsForContextItems()
    contextBox.Add(labels)
}

ResetSelection(*) {
    global MyGui
    MyGui["ContextBox"].Value := 0  ; Set selection to 0 to clear it
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
        if (IsObject(msg.content)) {
            for part in msg.content {
                if (part.HasOwnProp("text") && InStr(part.text, newContent))
                    return true
            }
        } else {
            if (InStr(msg.content, newContent))
                return true
        }
    }

    ; Then check content matches for files and folders
    ; Removed expensive check that reads file content
    ; newContentText := GetTextFromContextItem(newContent)
    ; for item in haystack {
    ;     if (GetTextFromContextItem(item) = newContentText)
    ;         return true
    ; }

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

        ; Update Context in GUI if shown
        if (guiShown) {
            UpdateContextView()
        }
    }
}

ChatHistorySelect(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        msg := messages[focused_row]
        MyGui["ChatMessageActionButton"].Visible := true  ; Show the Copy button
        RenderMarkdown(SessionManagerValue.GetMessageAsString(msg))  ; Render the selected message in the WebView
    }
}

CopySelectedMessage(*) {
    global MyGui, SessionManagerValue
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        msg := messages[focused_row]
        content := msg.content
        textContent := ""
        if (IsObject(content)) {
            for part in content {
                if (part.type = "text") {
                    textContent .= part.text
                }
            }
        } else {
            textContent := content
        }

        ClipText := StrReplace(textContent, "`r`n", "`n")
        ClipText := StrReplace(ClipText, "`r", "`n")
        ClipText := StrReplace(ClipText, "`n", "`r`n")
        A_Clipboard := ClipText
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
    global TrayManagerValue
    TrayManagerValue.ToggleRecording(SessionManagerValue)
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

BuildUserMessage(userMessageContent, contextItems, isImageEnabled) {
    global ContextManagerValue

    if (!isImageEnabled) {
        return userMessageContent
    }

    images := []
    for item in contextItems {
        if (ContextManagerValue.IsImage(item)) {
            images.Push(item)
        }
    }

    if (images.Length > 0) {
        contentParts := []
        if (userMessageContent != "") {
            contentParts.Push({ type: "text", text: userMessageContent })
        }

        for imageValue in images {
            if (RegExMatch(imageValue, "i)^data:image/")) {
                contentParts.Push({ type: "image_url", image_url: { url: imageValue } })
            } else {
                base64Image := FileUtils.GetFileAsBase64(imageValue)
                if (base64Image != "") {
                    extension := SubStr(imageValue, InStr(imageValue, ".", , -1) + 1)
                    contentParts.Push({ type: "image_url", image_url: { url: "data:image/" . extension . ";base64," .
                        base64Image } })
                }
            }
        }

        if (contentParts.Length > 0) {
            return contentParts
        }
    }

    return userMessageContent
}

BuildAdditionalContextMessage(context, contextBoxValue) {
    if (context.Length = 0)
        return ""

    contextText := ""
    selectedIndices := []

    ; Get selected indices
    if (contextBoxValue is Array) {
        selectedIndices := contextBoxValue
    } else if (contextBoxValue) {
        selectedIndices := [contextBoxValue]
    }

    ; Build context excluding selected items
    for index, item in context {
        if !HasVal(selectedIndices, index) {
            contextText .= GetTextFromContextItem(item)
        }
    }

    messageContent := ""

    ; Only add general context if there is any non-selected content
    if (contextText != "") {
        messageContent .= "`n`nHere is the context:`n`n" contextText "`n`nPlease consider this context when providing the answer."
    }

    ; Add selected items as special focus points
    if (selectedIndices.Length > 0) {
        messageContent .= "`nThe user has selected the folloing text which may be particularly relevant:`n`n"
        for index in selectedIndices {
            messageContent .= GetTextFromContextItem(context[index]) "`n`n"
        }
    }

    return messageContent
}

ConfigureToolSettings() {
    global MyGui
    enabledTools := []
    if (MyGui["PowerShellToolBox"].Value)
        enabledTools.Push("powerShellTool")
    return enabledTools
}

ExecuteToolCalls(msg) {
    global SessionManagerValue, PowerShellToolValue
    tool_calls := SessionManagerValue.GetToolCalls(msg)
    results := []

    for tool_call in tool_calls {
        if (!SessionManagerValue.IsToolCallExecuted(tool_call.id)) {
            ; Measure tool execution time
            startTime := A_TickCount
            if result := PowerShellToolValue.ExecuteToolCall(tool_call) {
                duration := (A_TickCount - startTime) / 1000
                result.duration := duration
                results.Push(result)
            }
        }
    }
    return results
}

ReloadSettings(*) {
    global MyGui, AppSettingsValue, SessionManagerValue

    ; Reload settings from disk
    AppSettingsValue.Reload()

    ; Refresh LLM Type dropdown
    llmTypeCombo := MyGui["LLMType"]
    currentLLMType := SessionManagerValue.GetCurrentSessionLLMType()

    llmTypeCombo.Delete()
    llmTypeCombo.Add(AppSettingsValue.llmTypes)

    ; Try to preserve current selection, otherwise default to first
    try {
        llmTypeCombo.Value := currentLLMType
    } catch {
        llmTypeCombo.Value := 1
        SessionManagerValue.SetCurrentSessionLLMType(1)
    }

    ; Refresh System Prompt dropdown
    systemPromptCombo := MyGui["SystemPrompt"]
    currentSystemPrompt := SessionManagerValue.GetCurrentSessionSystemPrompt()

    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))

    ; Try to preserve current selection, otherwise default to first
    try {
        systemPromptCombo.Value := currentSystemPrompt
    } catch {
        systemPromptCombo.Value := 1
        SessionManagerValue.SetCurrentSessionSystemPrompt(1)
    }

    ; Update tool checkbox based on current LLM type
    powerShellEnabled := AppSettingsValue.IsToolEnabled(SessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")
    MyGui["PowerShellToolBox"].Value := powerShellEnabled ? 1 : 0
}

SaveConversation(*) {
    global SessionManagerValue, MyGui

    state := SessionManagerValue.ExportSessionState()
    jsonStr := JSON.Dump(state, true) ; Pretty print

    selectedFile := FileSelect("S16", "conversation.json", "Save Conversation", "JSON Files (*.json)")
    if (selectedFile) {
        if (FileExist(selectedFile)) {
            FileDelete(selectedFile)
        }
        FileAppend(jsonStr, selectedFile)
    }
}

LoadConversation(*) {
    global SessionManagerValue, MyGui, AppSettingsValue

    selectedFile := FileSelect("3", , "Load Conversation", "JSON Files (*.json)")
    if (selectedFile) {
        try {
            fileContent := FileRead(selectedFile)
            state := JSON.Load(fileContent)

            SessionManagerValue.ImportSessionState(state)

            ; Update UI elements to reflect loaded state

            ; Update Session Selector (though we stay in current session index)
            ; Update LLM Type
            MyGui["LLMType"].Value := SessionManagerValue.GetCurrentSessionLLMType()

            ; Update System Prompt List and Selection
            systemPromptCombo := MyGui["SystemPrompt"]
            systemPromptCombo.Delete()
            systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
            systemPromptCombo.Value := SessionManagerValue.GetCurrentSessionSystemPrompt()

            ; Update System Prompt Content
            systemPrompt := AppSettingsValue.GetSystemPromptValue(
                SessionManagerValue.GetCurrentSessionLLMType(),
                SessionManagerValue.GetCurrentSessionSystemPrompt()
            )
            SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

            ; Update Context View
            UpdateContextView()

            ; Update Chat History View
            UpdateChatHistoryView()

            ; Clear Response Area
            RenderMarkdown("")
        } catch as e {
            MsgBox("Failed to load conversation: " . e.Message, "Error", "Iconx")
        }
    }
}
