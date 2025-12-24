#Requires AutoHotkey 2.0
#Include AppSettings.ahk
#Include LLMService.ahk
#Include ClipboardParser.ahk
#Include WebViewManager.ahk
#Include ContextManager.ahk
#Include TrayManager.ahk
#Include UIConfig.ahk
#Include UIBuilder.ahk
#Include LLM\Types.ahk
#Include ContextViewController.ahk
#Include HistoryViewController.ahk
#Include PdfProcessor.ahk
#Include TempFileManager.ahk

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
    LLMServiceValue := ""

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
        this.TrayManagerValue := TrayManager(ObjBindMethod(this, "DisplayLLMUserInterface"), ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"), ObjBindMethod(this,
            "ExitApplication"), this.ContextManagerValue)

        this.ContextViewControllerValue := ContextViewController(this.SessionManagerValue, this.AppSettingsValue, this.ContextManagerValue, this.WebViewManagerValue)
        this.HistoryViewControllerValue := HistoryViewController(this.SessionManagerValue, this.WebViewManagerValue, this.AppSettingsValue)

        this.LLMServiceValue := LLMService(this.AppSettingsValue)
    }

    Start() {
        TempFileManager.CleanUp()
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
                toolResults := this.LLMServiceValue.ExecuteToolCalls(this.SessionManagerValue, msg)
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
        if (this.LLMServiceValue) {
            this.LLMServiceValue.Cancel()
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
                    this.MyGui["PromptEdit"].Value := this.SessionManagerValue.GetUserMessageTextWithoutContext(selectedMsg)
                    return true
                } else {
                    ; Edit Mode: Build new message with text and images
                    isImageEnabled := this.AppSettingsValue.IsImageInputEnabled(this.SessionManagerValue.GetCurrentSessionLLMType())
                    images := isImageEnabled ? this.ContextViewControllerValue.GetCheckedImages() : []
                    newContent := this.SessionManagerValue.BuildUserMessage(promptText, images)

                    ; Check if this is the first user message with context
                    messages := this.SessionManagerValue.GetCurrentSessionMessages()
                    isFirstUserMsg := false
                    for i, msg in messages {
                        if (msg.Role == "user") {
                            isFirstUserMsg := (msg == selectedMsg)
                            break
                        }
                    }

                    ; If first user message with context, preserve the context
                    if (isFirstUserMsg && selectedMsg.AdditionalProperties.Has("hasContext")
                        && selectedMsg.AdditionalProperties["hasContext"]
                        && selectedMsg.Contents.Length > 0 && (selectedMsg.Contents[1] is TextContent)) {
                        ; Keep the context (first TextContent) and add new content after it
                        contextText := selectedMsg.Contents[1]
                        newContentWithContext := [contextText]
                        for part in newContent {
                            newContentWithContext.Push(part)
                        }
                        selectedMsg.Contents := newContentWithContext
                    } else {
                        ; Replace the message contents normally
                        selectedMsg.Contents := newContent
                    }

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

        images := isImageEnabled ? this.ContextViewControllerValue.GetCheckedImages() : []
        userMessageContent := this.SessionManagerValue.BuildUserMessage(userMessageContent, images)

        ; Allow empty user message if there's context to attach
        contextBox := this.MyGui["ContextBox"]
        hasContext := this.ContextViewControllerValue.HasAnyCheckedItem()
        if (userMessageContent.Length > 0 || hasContext) {
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

        ; Build context message content
        additionalContext := this.ContextViewControllerValue.BuildAdditionalContextMessage(context, contextBox.Value)

        ; Find first user message
        firstUserMsg := ""
        for i, msg in messages {
            if (msg.Role == "user") {
                firstUserMsg := msg
                break
            }
        }

        if (firstUserMsg) {
            ; Check if message has existing context
            if (firstUserMsg.AdditionalProperties.Has("hasContext") && firstUserMsg.AdditionalProperties["hasContext"]) {
                if (additionalContext != "") {
                    ; Update existing context (first item in Contents)
                    if (firstUserMsg.Contents.Length > 0 && (firstUserMsg.Contents[1] is TextContent)) {
                        firstUserMsg.Contents[1].Text := additionalContext
                    }
                } else {
                    ; Remove existing context
                    firstUserMsg.Contents.RemoveAt(1)
                    firstUserMsg.AdditionalProperties["hasContext"] := false
                }
            } else {
                ; No existing context
                if (additionalContext != "") {
                    ; Insert new context at the beginning
                    firstUserMsg.Contents.InsertAt(1, TextContent(additionalContext))
                    firstUserMsg.AdditionalProperties["hasContext"] := true
                }
            }
        }

        ; Disable Ask LLM button while processing
        if (this.MyGui) {
            this.askButton.Text := "Cancel"
        }

        try {
            ; Check tool enabled
            powerShellEnabled := this.AppSettingsValue.IsToolEnabled(this.SessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")

            newMessages := this.LLMServiceValue.SendToLLM(this.SessionManagerValue, this.currentAnswerSize, powerShellEnabled)

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
            compressedMsg := this.LLMServiceValue.CompressHistory(this.SessionManagerValue)

            if (compressedMsg != "") {
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

    ExtractLearnings(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()

        ; Check if there are enough messages (at least 2: system + 1 user/assistant)
        if (messages.Length < 2) {
            MsgBox("Not enough conversation history to extract notes.", "Info", "Iconi")
            return
        }

        ; Format the conversation history
        conversationText := this.SessionManagerValue.FormatMessagesForCompression()

        if (conversationText == "") {
            MsgBox("No conversation history to extract from.", "Info", "Iconi")
            return
        }

        ; Get learnings prompt
        learningsPrompt := this.AppSettingsValue.GetLearningsPrompt(this.SessionManagerValue.GetCurrentSessionLLMType())
        learningsPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Create temporary messages for the extraction request
        tempMessages := [
            messages[1],  ; Keep system message
            ChatMessage("user", [TextContent(learningsPrompt)])
        ]

        ; Disable Ask LLM button while processing
        if (this.MyGui) {
            originalButtonText := this.askButton.Text
            this.askButton.Text := "Extracting..."
            this.askButton.Enabled := false
        }

        try {
            extractedNotes := this.LLMServiceValue.ExtractLearnings(this.SessionManagerValue)

            if (extractedNotes != "") {
                UIBuilder.ShowNotesWindow(extractedNotes)
            }

        } catch as e {
            MsgBox("Extraction failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.MyGui) {
                this.askButton.Text := "Ask LLM" ; Reset to default
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
                ; Add the original item first
                if !this.HasContent(context, item) {
                    context.Push(item)

                    ; Check if it's a PDF and process it
                    ; if (this.ContextManagerValue.IsPdf(item)) {
                    ;     ; Check if pdftotext exists
                    ;     pdftotextPath := PdfProcessor.PdfToolsDir . "\pdftotext.exe"
                    ;     if FileExist(pdftotextPath) {
                    ;         ; Extract Text
                    ;         extractedTextFile := PdfProcessor.ExtractText(pdftotextPath, item)
                    ;         if (extractedTextFile && !this.HasContent(context, extractedTextFile)) {
                    ;             context.Push(extractedTextFile)
                    ;         }
                    ;     }

                        ; Extract Images
                        ; extractedImages := PdfProcessor.ExtractImages(item)
                        ; for imgPath in extractedImages {
                        ;      if !this.HasContent(context, imgPath) {
                        ;         context.Push(imgPath)
                        ;      }
                        ; }
                    ; }
                }
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
