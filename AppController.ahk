#Requires AutoHotkey 2.0
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

class AppController {
    askButton := ""
    MyGui := ""
    guiShown := false
    ModelMenu := ""  ; Store reference to Model menu
    MyMenuBar := ""  ; Store reference to MenuBar
    currentAnswerSize := "Default"  ; Track current answer size (Small, Default, Long)
    
    AppSettingsValue := ""
    SessionManagerValue := ""
    ClipboardParserValue := ""
    PowerShellToolValue := ""
    WebViewManagerValue := ""
    ContextManagerValue := ""
    TrayManagerValue := ""
    LLMClientInstance := ""

    __New() {
        ; Create settings instance
        this.AppSettingsValue := AppSettings()

        ; Create session manager instance with default values from AppSettings
        this.SessionManagerValue := SessionManager(
            this.AppSettingsValue.selectedLLMTypeIndex,
            this.AppSettingsValue.GetSystemPromptValue(this.AppSettingsValue.selectedLLMTypeIndex, 1)
        )

        ; Create clipboard parser instance
        this.ClipboardParserValue := ClipboardParser()

        this.PowerShellToolValue := PowerShellTool()

        ; Create WebView manager instance
        this.WebViewManagerValue := WebViewManager()

        this.ContextManagerValue := ContextManager()

        ; Create TrayManager instance
        this.TrayManagerValue := TrayManager(ObjBindMethod(this, "DisplayLLMUserInterface"), ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"), ObjBindMethod(this, "ExitApplication"), this.ContextManagerValue)
        
        this.LLMClientInstance := ""
    }

    Start() {
        this.DisplayLLMUserInterface()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.TrayManagerValue.isRecording) {
            this.TrayManagerValue.StartRecording()
        } else if (!this.guiShown) {
            this.DisplayLLMUserInterface()
        } else {
            this.TrayManagerValue.StopRecording(this.SessionManagerValue)
        }
    }

    RenderMarkdown(content) {
        this.WebViewManagerValue.RenderMarkdown(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.guiShown) {
            if (this.TrayManagerValue.isRecording) {
                this.MyGui["Record"].Text := "Stop"
            } else {
                this.MyGui["Stop"].Text := "Record"
            }
        }
    }

    DisplayLLMUserInterface(*) {
        if (this.guiShown) {
            this.MyGui.Show()
            return
        }
        this.MyGui := Gui()
        this.MyGui.Title := "LLM Assistant"
        this.MyGui.SetFont("s9", "Segoe UI")
        this.MyGui.Opt("+Resize +MinSize800x610")  ; Only main window gets resize option

        this.MyGui.OnEvent("Size", ObjBindMethod(this, "GuiResize"))
        this.MyGui.OnEvent("Close", ObjBindMethod(this, "GuiClose"))

        menuObjects := UIBuilder.CreateMenuBar(this.MyGui, this, this.AppSettingsValue, this.SessionManagerValue)
        this.MyMenuBar := menuObjects.menuBar
        this.ModelMenu := menuObjects.modelMenu

        UIBuilder.CreateTopControls(this.MyGui, this.SessionManagerValue, this.TrayManagerValue, this)

        UIBuilder.CreateContextSection(this.MyGui, this)

        UIBuilder.CreateChatHistorySection(this.MyGui, this)

        UIBuilder.CreatePromptSection(this.MyGui, this.SessionManagerValue, this.AppSettingsValue, this)

        this.askButton := UIBuilder.CreateBottomControls(this.MyGui, this.SessionManagerValue, this.AppSettingsValue, this)

        responseCtr := UIBuilder.CreateResponseArea(this.MyGui)

        this.MyGui.Show("w1230 h610")

        this.WebViewManagerValue.Init(responseCtr)
        this.WebViewManagerValue.SetInputCallback(ObjBindMethod(this, "AppendToPrompt"))
        this.guiShown := true

        this.UpdateChatHistoryView()
    }

    GuiResize(thisGui, MinMax, Width, Height) {
        if (MinMax = -1)  ; If window is minimized
            return

        ; Resize the ResponseCtr control
        thisGui["ResponseCtr"].Move(UIConfig.responseCtrX, UIConfig.responseCtrY, Width - 410, Height - 20)

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
        if this.guiShown {
            this.WebViewManagerValue.Resize(wvRect)
        }

        ; Resize the prompt edit control
        promptEditHeight := Height - UIConfig.promptEditY - UIConfig.bottomControlsHeight
        thisGui["PromptEdit"].Move(UIConfig.promptEditX, UIConfig.promptEditY, UIConfig.promptEditWidth, promptEditHeight)

        ; Move bottom controls
        bottomY := Height - 35  ; 35 pixels from bottom
        thisGui["SystemPrompt"].Move(UIConfig.systemPromptX, bottomY)
        thisGui["AskLLM"].Move(UIConfig.askLLMX, bottomY)

        ; Move PowerShell tool checkbox and icon above bottom controls
        checkBoxY := Height - 30
        thisGui["PowerShellIcon"].Move(UIConfig.llmTypeX, checkBoxY)
        thisGui["PowerShellToolBox"].Move(UIConfig.llmTypeX + 20, checkBoxY)
    }

    GetLabelsForContextItems() {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        predefinedContext := this.AppSettingsValue.GetContext(this.SessionManagerValue.GetCurrentSessionLLMType(),
        this.SessionManagerValue.GetCurrentSessionSystemPrompt())
        labels := []
        for item in predefinedContext {
            if (!this.HasVal(context, item)) {
                context.Push(item)
            }
        }
        this.SessionManagerValue.SetCurrentSessionContext(context)
        for item in context {
            labels.Push(this.ContextManagerValue.GetLabelFromContextItem(item))
        }
        return labels
    }

    SystemPromptChanged(*) {
        this.SessionManagerValue.SetCurrentSessionSystemPrompt(this.MyGui["SystemPrompt"].Value)

        ; Update the system prompt content
        systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        inputTemplate := this.AppSettingsValue.GetInputTemplate(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        if (inputTemplate) {
            this.MyGui["PromptEdit"].Value := inputTemplate  ; Set the prompt edit value to the input template
        }
        this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)
        this.UpdateContextView()  ; Update the context view
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get old model name for renaming menu
        oldModelIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        oldModelName := "Model: " . this.AppSettingsValue.llmTypes[oldModelIndex]

        ; Update session with new model index
        this.SessionManagerValue.SetCurrentSessionLLMType(ItemPos)

        ; Update menu checkmarks
        for index, modelName in this.AppSettingsValue.llmTypes {
            if (index = ItemPos) {
                MyMenu.Check(modelName)
            } else {
                MyMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label to show new model name
        newModelName := "Model: " . this.AppSettingsValue.llmTypes[ItemPos]
        this.MyMenuBar.Rename(oldModelName, newModelName)

        ; Update system prompts for the new model
        systemPromptCombo := this.MyGui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.AppSettingsValue.GetSystemPromptNames(this.SessionManagerValue.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := 1  ; Reset to first prompt when LLM type changes
        this.SessionManagerValue.SetCurrentSessionSystemPrompt(1)

        ; Update tool checkbox based on new LLM type
        powerShellEnabled := this.AppSettingsValue.IsToolEnabled(this.SessionManagerValue.GetCurrentSessionLLMType(),
        "powerShellTool")
        this.MyGui["PowerShellToolBox"].Value := powerShellEnabled ? 1 : 0
    }

    SelectAnswerSize(ItemName, ItemPos, MyMenu) {
        ; Update checkmarks
        for _, size in ["Small", "Default", "Long"] {
            if (size = ItemName) {
                MyMenu.Check(size)
            } else {
                MyMenu.Uncheck(size)
            }
        }
        
        ; Store current answer size
        this.currentAnswerSize := ItemName
    }

    SessionChanged(*) {
        ; Update LLM type and system prompt selections
        ; Update Model menu checkmarks and menu bar label
        oldModelIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        oldModelName := "Model: " . this.AppSettingsValue.llmTypes[oldModelIndex]

        ; Switch to new session
        this.SessionManagerValue.SwitchSession(this.MyGui["SessionSelect"].Value)

        this.UpdateContextView()
        this.UpdateChatHistoryView()

        currentModelIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.AppSettingsValue.llmTypes[currentModelIndex]

        ; Update menu checkmarks
        for index, modelName in this.AppSettingsValue.llmTypes {
            if (index = currentModelIndex) {
                this.ModelMenu.Check(modelName)
            } else {
                this.ModelMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label if model changed
        if (oldModelName != newModelName) {
            this.MyMenuBar.Rename(oldModelName, newModelName)
        }

        ; Update system prompts for the selected LLM type
        systemPromptCombo := this.MyGui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.AppSettingsValue.GetSystemPromptNames(this.SessionManagerValue.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := this.SessionManagerValue.GetCurrentSessionSystemPrompt()

        ; Clear response field
        this.RenderMarkdown("")  ; Clear the response area
    }

    UpdateContextView(*) {
        ; Update local references
        labels := this.GetLabelsForContextItems()

        ; Update UI
        contextBox := this.MyGui["ContextBox"]
        contextBox.Delete()
        contextBox.Add(labels)
    }

    UpdateChatHistoryView(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessagesAsStrings()
        chatHistory := this.MyGui["ChatHistory"]
        chatHistory.Delete()
        for msg in messages {
            duration := msg.HasOwnProp("duration") ? Round(msg.duration, 2) . "s" : ""
            tokens := msg.HasOwnProp("tokens") ? msg.tokens : ""
            chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""), duration,
            tokens)
        }
        this.MyGui["ChatMessageActionButton"].Visible := false  ; Hide the Run Tool button
    }

    HandleToolConfirmation() {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
    
        ; Find and execute all unexecuted tool calls
        executedAny := false
        for msg in messages {
            if (this.SessionManagerValue.HasToolCalls(msg)) {
                toolResults := this.ExecuteToolCalls(msg)
                if (toolResults.Length > 0) {
                    for res in toolResults {
                        messages.Push(res)
                    }
                    executedAny := true
                }
            }
        }
    
        if (executedAny) {
            this.SendToLLM()
        } else {
            ; Should not happen if button is Confirm Tool Run, but reset just in case
            this.MyGui["AskLLM"].Text := "Ask LLM"
        }
    }
    
    HandleCancellation() {
        if (this.LLMClientInstance) {
            this.LLMClientInstance.Cancel()
        }
    }
    
    HandleRegenerationOrEdit(promptText) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        focused_row := chatHistory.GetNext()
    
        if (focused_row > 0) {
            selectedMsg := messages[focused_row]
            if (selectedMsg.role == "user") {
                if (promptText == "") {
                    ; Regeneration case: Load message content into prompt for editing
                    this.MyGui["PromptEdit"].Value := this.SessionManagerValue.GetMessageText(selectedMsg)
                    return true
                } else {
                    ; Edit Mode: Update the message with new content
                    if (this.SessionManagerValue.UpdateMessage(focused_row, promptText)) {
                        ; Truncate history after this message
                        if (this.SessionManagerValue.TruncateMessages(focused_row)) {
                            this.SendToLLM()
                            this.MyGui["PromptEdit"].Value := ""
                            ; Clear selection to exit "Edit Mode"
                            chatHistory.Modify(focused_row, "-Select")
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
    
    AskToLLM(*) {
        ; Check if we are in "Confirm Tool Run" mode (Agent Mode tool execution)
        if (this.MyGui["AskLLM"].Text == "Confirm Tool Run") {
            this.HandleToolConfirmation()
            return
        }
    
        if (this.MyGui["AskLLM"].Text == "Cancel") {
            this.HandleCancellation()
            return
        }
    
        promptText := this.MyGui["PromptEdit"].Value
    
        ; Check for regeneration or edit case
        if (this.HandleRegenerationOrEdit(promptText)) {
            return
        }
    
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        userMessageContent := ""
        if (promptText != "") {
            userMessageContent := promptText
        }
    
        contextItems := this.SessionManagerValue.GetCurrentSessionContext()
        isImageEnabled := this.AppSettingsValue.IsImageInputEnabled(this.SessionManagerValue.GetCurrentSessionLLMType())
    
        userMessageContent := this.BuildUserMessage(userMessageContent, contextItems, isImageEnabled)
    
        if (userMessageContent != "") {
            messages.Push({ role: "user", content: userMessageContent })
        }
        this.SendToLLM()
        this.MyGui["PromptEdit"].Value := ""  ; Clear prompt field
    
        if (this.TrayManagerValue.isRecording) {
            this.TrayManagerValue.StopRecording(this.SessionManagerValue)
        }
    }

    SendToLLM() {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()

        ; Update the system prompt content
        systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

        context := this.SessionManagerValue.GetCurrentSessionContext()
        contextBox := this.MyGui["ContextBox"]

        ; Build and append context message if needed
        additionalContext := this.BuildAdditionalContextMessage(context, contextBox.Value)
        if (additionalContext != "") {
            messages[1].content .= additionalContext
        }

        ; Disable Ask LLM button while processing
        if (this.MyGui) {
            this.askButton.Text := "Cancel"
        }

        try {
            ; Create LLM client if it doesn't exist yet
            settings := this.AppSettingsValue.GetSelectedSettings(this.SessionManagerValue.GetCurrentSessionLLMType())

            ; Update tools property based on checkbox values
            settings["tools"] := this.ConfigureToolSettings()
            ; Add a user message to instruct the model on answer length based on menu selection
            answerSizeMsg := ""
            if (this.currentAnswerSize = "Small") {
                answerSizeMsg := "Please answer as concisely as possible (short answer)."
            } else if (this.currentAnswerSize = "Long") {
                answerSizeMsg := "Please provide a long, detailed answer."
            }
            ; If currentAnswerSize = "Default", no message is added (default behavior)
            if (answerSizeMsg != "") {
                messages.Push({ role: "user", content: answerSizeMsg })
            }

            this.LLMClientInstance := LLMClient(settings)

            ; The LLM client now returns fully-formed messages
            startTime := A_TickCount
            newMessages := this.LLMClientInstance.Call(messages)
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
            if (this.SessionManagerValue.HasUnexecutedToolCalls()) {
                this.MyGui["AskLLM"].Text := "Confirm Tool Run"
            } else {
                this.MyGui["AskLLM"].Text := "Ask LLM"
            }

        } catch as e {
            if (e.Message == "Request cancelled") {
                ; Do nothing on cancellation
            } else {
                throw e
            }
        } finally {
            ; Re-enable Ask LLM button
            if (this.MyGui) {
                if (this.MyGui["AskLLM"].Text == "Cancel") {
                     this.MyGui["AskLLM"].Text := "Ask LLM"
                }
                this.askButton.Enabled := true
            }
        }
        this.UpdateChatHistoryView()  ; Update the chat history view

        ; Render the last message in the series of responses
        if (messages.Length > 0) {
            this.RenderMarkdown(this.SessionManagerValue.GetMessageAsString(messages[messages.Length]))
        }
    }

    GetTextFromContextItem(item) {
        return this.ContextManagerValue.GetTextFromContextItem(item, (url) => this.WebViewManagerValue.LoadArticle(url))
    }

    GuiClose(*) {
        this.MyGui.Destroy()
        this.guiShown := false
    }

    ContextBoxSelect(*) {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        contextBox := this.MyGui["ContextBox"]
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
            textContent .= this.GetTextFromContextItem(item) "`n"
        }

        this.RenderMarkdown(textContent)  ; Render the selected item(s) in the WebView
    }

    DeleteSelected(*) {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        contextBox := this.MyGui["ContextBox"]
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
        labels := this.GetLabelsForContextItems()
        contextBox.Add(labels)
    }

    ResetSelection(*) {
        this.MyGui["ContextBox"].Value := 0  ; Set selection to 0 to clear it
    }

    ClearChatHistory(*) {
        this.SessionManagerValue.ClearCurrentMessages()

        ; Update the system prompt content after clearing
        systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

        this.UpdateChatHistoryView()  ; Update the chat history view
        this.RenderMarkdown("")  ; Clear the response area
    }

    ResetAll(*) {
        ; Reset current session
        this.SessionManagerValue.ResetCurrentSession()

        ; Update UI
        this.UpdateChatHistoryView()
        this.UpdateContextView()

        ; Clear response and prompt
        this.RenderMarkdown("")  ; Clear the response area
    }

    ExitApplication(*) {
        ExitApp
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }

    CheckContentInMessages(messages, newContent) {
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
        return false
    }
    
    HasContent(haystack, newContent) {
        if (newContent = "")
            return true
    
        ; First check exact matches
        if (this.HasVal(haystack, newContent))
            return true
    
        ; Also check in chat history
        if (this.CheckContentInMessages(this.SessionManagerValue.GetCurrentSessionMessages(), newContent))
            return true
    
        return false
    }

    ClipChanged(DataType) {
        if (this.TrayManagerValue.isRecording) {
            localTxtFromClipboardArray := this.ClipboardParserValue.Parse()

            ; Add non-duplicate items to context
            context := this.SessionManagerValue.GetCurrentSessionContext()
            for item in localTxtFromClipboardArray {
                if !this.HasContent(context, item)
                    context.Push(item)
            }

            ; Update session contexts
            this.SessionManagerValue.SetCurrentSessionContext(context)

            ; Update Context in GUI if shown
            if (this.guiShown) {
                this.UpdateContextView()
            }
        }
    }

    ChatHistorySelect(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        if (focused_row := chatHistory.GetNext()) {
            msg := messages[focused_row]
            this.MyGui["ChatMessageActionButton"].Visible := true  ; Show the Copy button
            this.RenderMarkdown(this.SessionManagerValue.GetMessageAsString(msg))  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
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

    AppendToPrompt(text) {
        currentText := this.MyGui["PromptEdit"].Value
        if (currentText != "") {
            currentText .= "`n"
        }
        this.MyGui["PromptEdit"].Value := currentText . "> " . text . "`n"
    }

    PromptChange(GuiCtrl, Info) {
        if (GetKeyState("Enter") && !GetKeyState("Shift")) {
            ; Get the last character
            text := GuiCtrl.Value
            if (SubStr(text, -1) == "`n") {
                ; Remove the trailing newline
                GuiCtrl.Value := SubStr(text, 1, -1)
                ; Send the prompt
                this.AskToLLM()
                return true
            }
        }
    }

    ClearAllContext(*) {
        this.SessionManagerValue.SetCurrentSessionContext([])
        this.UpdateContextView()
    }

    ToggleRecording(*) {
        this.TrayManagerValue.ToggleRecording(this.SessionManagerValue)
    }

    DeleteSelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]

        selectedIndices := []
        focused_row := 0

        ; Collect all selected rows
        while (focused_row := chatHistory.GetNext(focused_row))
            if (focused_row > 1)  ; Don't include system message
                selectedIndices.InsertAt(1, focused_row)

        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices
            messages.RemoveAt(index)

        this.UpdateChatHistoryView()
        this.RenderMarkdown("")  ; Clear the response area
    }

    BuildUserMessage(userMessageContent, contextItems, isImageEnabled) {
        if (!isImageEnabled) {
            return userMessageContent
        }

        images := []
        for item in contextItems {
            if (this.ContextManagerValue.IsImage(item)) {
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
            if !this.HasVal(selectedIndices, index) {
                contextText .= this.GetTextFromContextItem(item)
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
                messageContent .= this.GetTextFromContextItem(context[index]) "`n`n"
            }
        }

        return messageContent
    }

    ConfigureToolSettings() {
        enabledTools := []
        if (this.MyGui["PowerShellToolBox"].Value)
            enabledTools.Push("powerShellTool")
        return enabledTools
    }

    ExecuteToolCalls(msg) {
        tool_calls := this.SessionManagerValue.GetToolCalls(msg)
        results := []

        for tool_call in tool_calls {
            if (!this.SessionManagerValue.IsToolCallExecuted(tool_call.id)) {
                ; Measure tool execution time
                startTime := A_TickCount
                if result := this.PowerShellToolValue.ExecuteToolCall(tool_call) {
                    duration := (A_TickCount - startTime) / 1000
                    result.duration := duration
                    results.Push(result)
                    this.SessionManagerValue.MarkToolCallAsExecuted(tool_call.id)
                }
            }
        }
        return results
    }
    
    SaveConversation(*) {
        state := this.SessionManagerValue.ExportSessionState()
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
        selectedFile := FileSelect("3", , "Load Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                fileContent := FileRead(selectedFile)
                state := JSON.Load(fileContent)

                this.SessionManagerValue.ImportSessionState(state)

                ; Update UI elements to reflect loaded state

                ; Update Session Selector (though we stay in current session index)
                ; Update LLM Type
                this.MyGui["LLMType"].Value := this.SessionManagerValue.GetCurrentSessionLLMType()

                ; Update System Prompt List and Selection
                systemPromptCombo := this.MyGui["SystemPrompt"]
                systemPromptCombo.Delete()
                systemPromptCombo.Add(this.AppSettingsValue.GetSystemPromptNames(this.SessionManagerValue.GetCurrentSessionLLMType()))
                systemPromptCombo.Value := this.SessionManagerValue.GetCurrentSessionSystemPrompt()

                ; Update System Prompt Content
                systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
                    this.SessionManagerValue.GetCurrentSessionLLMType(),
                    this.SessionManagerValue.GetCurrentSessionSystemPrompt()
                )
                this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

                ; Update Context View
                this.UpdateContextView()

                ; Update Chat History View
                this.UpdateChatHistoryView()

                ; Clear Response Area
                this.RenderMarkdown("")
            } catch as e {
                MsgBox("Failed to load conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }
    
    ReloadSettings(*) {
        ; Reload settings from disk
        this.AppSettingsValue.Reload()

        ; Refresh LLM Type dropdown
        llmTypeCombo := this.MyGui["LLMType"]
        currentLLMType := this.SessionManagerValue.GetCurrentSessionLLMType()

        llmTypeCombo.Delete()
        llmTypeCombo.Add(this.AppSettingsValue.llmTypes)

        ; Try to preserve current selection, otherwise default to first
        try {
            llmTypeCombo.Value := currentLLMType
        } catch {
            llmTypeCombo.Value := 1
            this.SessionManagerValue.SetCurrentSessionLLMType(1)
        }

        ; Refresh System Prompt dropdown
        systemPromptCombo := this.MyGui["SystemPrompt"]
        currentSystemPrompt := this.SessionManagerValue.GetCurrentSessionSystemPrompt()

        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.AppSettingsValue.GetSystemPromptNames(this.SessionManagerValue.GetCurrentSessionLLMType()))

        ; Try to preserve current selection, otherwise default to first
        try {
            systemPromptCombo.Value := currentSystemPrompt
        } catch {
            systemPromptCombo.Value := 1
            this.SessionManagerValue.SetCurrentSessionSystemPrompt(1)
        }

        ; Update tool checkbox based on current LLM type
        powerShellEnabled := this.AppSettingsValue.IsToolEnabled(this.SessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")
        this.MyGui["PowerShellToolBox"].Value := powerShellEnabled ? 1 : 0
    }
}
