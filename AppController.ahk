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
#Include LLM\Types.ahk
#Include ContextViewController.ahk
#Include HistoryViewController.ahk

class AppController {
    askButton := ""
    MyGui := ""
    guiShown := false
    ModelMenu := ""  ; Store reference to Model menu
    HistoryMenu := ""  ; Store reference to History menu
    MyMenuBar := ""  ; Store reference to MenuBar
    currentAnswerSize := "Default"  ; Track current answer size (Small, Default, Long)
    currentModelName := ""  ; Track current model name for MenuBar updates

    AppSettingsValue := ""
    SessionManagerValue := ""
    ClipboardParserValue := ""
    WebViewManagerValue := ""
    ContextManagerValue := ""
    TrayManagerValue := ""
    LLMClientInstance := ""
    
    ContextViewControllerValue := ""
    HistoryViewControllerValue := ""

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

        ; Create WebView manager instance
        this.WebViewManagerValue := WebViewManager()

        this.ContextManagerValue := ContextManager()

        ; Create TrayManager instance
        this.TrayManagerValue := TrayManager(ObjBindMethod(this, "DisplayLLMUserInterface"), ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"), ObjBindMethod(this, "ExitApplication"), this.ContextManagerValue)

        this.ContextViewControllerValue := ContextViewController(this.SessionManagerValue, this.AppSettingsValue, this.ContextManagerValue, this.WebViewManagerValue)
        this.HistoryViewControllerValue := HistoryViewController(this.SessionManagerValue, this.WebViewManagerValue)

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

        this.MyGui.OnEvent("Size", (gui, minMax, width, height) => UIBuilder.GuiResize(gui, minMax, width, height, this))
        this.MyGui.OnEvent("Close", ObjBindMethod(this, "GuiClose"))

        this.ContextViewControllerValue.SetGui(this.MyGui)
        this.HistoryViewControllerValue.SetGui(this.MyGui)

        menus := UIBuilder.CreateMenuBar(this.MyGui, this, this.AppSettingsValue, this.SessionManagerValue)
        this.MyMenuBar := menus.menuBar
        this.ModelMenu := menus.modelMenu
        this.HistoryMenu := menus.historyMenu

        this.UpdateCompressionMenuState()

        ; Initialize current model name
        currentModelIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        this.currentModelName := "Model: " . this.AppSettingsValue.llmTypes[currentModelIndex]

        UIBuilder.CreateTopControls(this.MyGui, this.SessionManagerValue, this.TrayManagerValue, this)

        UIBuilder.CreateContextSection(this.MyGui, this.ContextViewControllerValue)

        UIBuilder.CreateChatHistorySection(this.MyGui, this.HistoryViewControllerValue)

        UIBuilder.CreatePromptSection(this.MyGui, this.SessionManagerValue, this.AppSettingsValue, this)

        this.askButton := UIBuilder.CreateBottomControls(this.MyGui, this.SessionManagerValue, this.AppSettingsValue, this)

        responseCtr := UIBuilder.CreateResponseArea(this.MyGui)

        this.MyGui.Show("w1230 h610")

        this.WebViewManagerValue.Init(responseCtr)
        this.WebViewManagerValue.SetInputCallback(ObjBindMethod(this, "AppendToPrompt"))
        this.guiShown := true

        this.HistoryViewControllerValue.UpdateChatHistoryView()
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
        this.ContextViewControllerValue.UpdateContextView()  ; Update the context view
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get old model name for renaming menu
        oldModelName := this.currentModelName

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
        try this.MyMenuBar.Rename(oldModelName, newModelName)
        this.currentModelName := newModelName

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

        this.UpdateCompressionMenuState()
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
        ; Update Model menu checkmarks and menu bar label
        oldModelName := this.currentModelName

        ; Switch to new session
        this.SessionManagerValue.SwitchSession(this.MyGui["SessionSelect"].Value)

        this.ContextViewControllerValue.UpdateContextView()
        this.HistoryViewControllerValue.UpdateChatHistoryView()

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
            try this.MyMenuBar.Rename(oldModelName, newModelName)
            this.currentModelName := newModelName
        }

        ; Update system prompts for the selected LLM type
        systemPromptCombo := this.MyGui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.AppSettingsValue.GetSystemPromptNames(this.SessionManagerValue.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := this.SessionManagerValue.GetCurrentSessionSystemPrompt()

        ; Clear response field
        this.RenderMarkdown("")  ; Clear the response area
        
        this.UpdateCompressionMenuState()
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

            if (selectedMsg.Role == "user") {
                if (promptText == "") {
                    ; Regeneration case: Load message content into prompt for editing
                    this.MyGui["PromptEdit"].Value := this.SessionManagerValue.GetMessageText(selectedMsg)
                    return true
                } else {
                    ; Edit Mode: Build new message with text and images
                    contextItems := this.SessionManagerValue.GetCurrentSessionContext()
                    isImageEnabled := this.AppSettingsValue.IsImageInputEnabled(this.SessionManagerValue.GetCurrentSessionLLMType())
                    newContent := this.BuildUserMessage(promptText, contextItems, isImageEnabled)

                    ; Replace the message contents
                    selectedMsg.Contents := newContent

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

        if (userMessageContent.Length > 0) {
            messages.Push(ChatMessage("user", userMessageContent))
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
        additionalContext := this.ContextViewControllerValue.BuildAdditionalContextMessage(context, contextBox.Value)
        if (additionalContext != "") {
            messages[1].AddText(additionalContext)
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
                messages.Push(ChatMessage("user", [TextContent(answerSizeMsg)]))
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
                newMessage.AdditionalProperties["duration"] := duration
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
        this.HistoryViewControllerValue.UpdateChatHistoryView()  ; Update the chat history view

        if (messages.Length > 0) {
            this.RenderMarkdown(this.SessionManagerValue.GetMessageAsString(messages[messages.Length]))
        }

        ; Uncheck images after sending
        this.ContextViewControllerValue.UncheckSentImages()
    }

    GuiClose(*) {
        this.MyGui.Destroy()
        this.guiShown := false
    }



    ClearChatHistory(*) {
        this.SessionManagerValue.ClearCurrentMessages()

        ; Update the system prompt content after clearing
        systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

        this.HistoryViewControllerValue.UpdateChatHistoryView()  ; Update the chat history view
        this.RenderMarkdown("")  ; Clear the response area
    }

    ResetAll(*) {
        ; Reset current session
        this.SessionManagerValue.ResetCurrentSession()

        ; Update UI
        this.HistoryViewControllerValue.UpdateChatHistoryView()
        this.ContextViewControllerValue.UpdateContextView()

        ; Clear response and prompt
        this.RenderMarkdown("")  ; Clear the response area
    }

    CompressHistory(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()

        ; Check if there are enough messages to compress (at least 3: system + 2 others)
        if (messages.Length < 3) {
            MsgBox("Not enough messages to compress. Need at least 2 messages besides the system message.", "Info", "Iconi")
            return
        }

        ; Format the conversation history for compression
        conversationText := this.SessionManagerValue.FormatMessagesForCompression()

        if (conversationText == "") {
            MsgBox("No conversation history to compress.", "Info", "Iconi")
            return
        }

        ; Build compression prompt
        compressionPrompt := this.AppSettingsValue.GetCompressionPrompt(this.SessionManagerValue.GetCurrentSessionLLMType())
        
        if (compressionPrompt == "") {
             MsgBox("Compression prompt not configured for this provider.", "Info", "Iconi")
             return
        }
        
        compressionPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Create a temporary message array with just system message and compression request
        tempMessages := [
            messages[1],  ; Keep system message
            ChatMessage("user", [TextContent(compressionPrompt)])
        ]

        ; Disable Ask LLM button while processing
        if (this.MyGui) {
            this.askButton.Text := "Compressing..."
            this.askButton.Enabled := false
        }

        try {
            ; Create LLM client
            settings := this.AppSettingsValue.GetSelectedSettings(this.SessionManagerValue.GetCurrentSessionLLMType())
            settings["tools"] := []  ; No tools for compression

            this.LLMClientInstance := LLMClient(settings)

            ; Call LLM with compression prompt
            startTime := A_TickCount
            newMessages := this.LLMClientInstance.Call(tempMessages)
            duration := (A_TickCount - startTime) / 1000

            ; Replace all messages with system message + compressed summary
            if (newMessages.Length > 0) {
                compressedMsg := newMessages[1]
                compressedMsg.AdditionalProperties["duration"] := duration

                ; Replace session messages
                this.SessionManagerValue.sessionMessages[this.SessionManagerValue.currentSessionIndex] := [
                    messages[1],  ; Keep original system message
                    compressedMsg  ; Add compressed summary
                ]

                ; Update UI
                this.HistoryViewControllerValue.UpdateChatHistoryView()
                this.RenderMarkdown(this.SessionManagerValue.GetMessageAsString(compressedMsg))
            }

        } catch as e {
            MsgBox("Compression failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.MyGui) {
                this.askButton.Text := "Ask LLM"
                this.askButton.Enabled := true
            }
        }
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
            if (InStr(msg.GetText(), newContent))
                return true
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
                this.ContextViewControllerValue.UpdateContextView()
            }
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
        this.ContextViewControllerValue.UpdateContextView()
    }

    ToggleRecording(*) {
        this.TrayManagerValue.ToggleRecording(this.SessionManagerValue)
    }


    BuildUserMessage(userMessageContent, contextItems, isImageEnabled) {
        contentParts := []

        if (!isImageEnabled) {
            if (userMessageContent != "") {
                contentParts.Push(TextContent(userMessageContent))
            }
            return contentParts
        }

        images := []
        for index, item in contextItems {
            ; Check if item is checked in UI
            if (this.ContextViewControllerValue.IsItemChecked(index)) {
                if (this.ContextManagerValue.IsImage(item)) {
                    images.Push(item)
                }
            }
        }

        if (images.Length > 0) {
            if (userMessageContent != "") {
                contentParts.Push(TextContent(userMessageContent))
            }

            for imageValue in images {
                if (RegExMatch(imageValue, "i)^data:image/")) {
                    ; Already data URI
                    contentParts.Push(ImageContent(imageValue))
                } else if (InStr(imageValue, "http") == 1) {
                    contentParts.Push(ImageContent(imageValue))
                } else {
                    base64Image := FileUtils.GetFileAsBase64(imageValue)
                    if (base64Image != "") {
                        extension := SubStr(imageValue, InStr(imageValue, ".", , -1) + 1)
                        mimeType := "image/" . extension
                        contentParts.Push(ImageContent(base64Image, mimeType))
                    }
                }
            }
        } else {
             if (userMessageContent != "") {
                contentParts.Push(TextContent(userMessageContent))
            }
        }

        return contentParts
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
                if result := PowerShellTool.ExecuteToolCall(tool_call) {
                    duration := (A_TickCount - startTime) / 1000
                    result.duration := duration
                    results.Push(result)
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

                ; Update LLM Type
                currentLLMType := this.SessionManagerValue.GetCurrentSessionLLMType()
                newModelName := "Model: " . this.AppSettingsValue.llmTypes[currentLLMType]

                ; Update checkmarks
                for index, modelName in this.AppSettingsValue.llmTypes {
                    if (index = currentLLMType) {
                        this.ModelMenu.Check(modelName)
                    } else {
                        this.ModelMenu.Uncheck(modelName)
                    }
                }

                ; Update MenuBar label
                if (this.currentModelName != newModelName) {
                    try this.MyMenuBar.Rename(this.currentModelName, newModelName)
                    this.currentModelName := newModelName
                }

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
                this.ContextViewControllerValue.UpdateContextView()

                ; Update Chat History View
                this.HistoryViewControllerValue.UpdateChatHistoryView()

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
        ; Refresh Model Menu
        this.ModelMenu.Delete() ; Delete all items
        for index, modelName in this.AppSettingsValue.llmTypes {
            this.ModelMenu.Add(modelName, ObjBindMethod(this, "SelectModel"))
        }

        this.UpdateCompressionMenuState()

        currentLLMType := this.SessionManagerValue.GetCurrentSessionLLMType()

        ; Validate index
        if (currentLLMType > this.AppSettingsValue.llmTypes.Length) {
            currentLLMType := 1
            this.SessionManagerValue.SetCurrentSessionLLMType(1)
        }

        ; Check the current model
        newModelName := "Model: " . this.AppSettingsValue.llmTypes[currentLLMType]
        this.ModelMenu.Check(this.AppSettingsValue.llmTypes[currentLLMType])

        ; Update MenuBar label
        if (this.currentModelName != newModelName) {
            try this.MyMenuBar.Rename(this.currentModelName, newModelName)
            this.currentModelName := newModelName
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
        
        this.UpdateCompressionMenuState()
    }

    UpdateCompressionMenuState() {
        if (!this.HistoryMenu)
            return

        currentLLMIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        compressionPrompt := this.AppSettingsValue.GetCompressionPrompt(currentLLMIndex)

        if (compressionPrompt == "") {
            this.HistoryMenu.Disable("Compress")
        } else {
            this.HistoryMenu.Enable("Compress")
        }
    }
}
