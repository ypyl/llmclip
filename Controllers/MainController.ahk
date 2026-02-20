#Requires AutoHotkey 2.0

class MainController {
    view := ""

    ; Dependencies
    configManager := ""
    sessionManager := ""
    llmService := ""
    webViewManager := ""
    recordingService := ""
    contextManager := ""
    clipboardParser := ""
    fileService := ""

    ; Commands
    saveConversationCommand := ""
    loadConversationCommand := ""
    clearContextCommand := ""
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    resetAllCommand := ""
    initializeAppCommand := ""
    saveDiagramCommand := ""
    renderMarkdownCommand := ""
    cancelRequestCommand := ""
    executeToolCallsCommand := ""
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    renderLastMessageCommand := ""
    processClipboardCommand := ""
    uncheckImagesCommand := ""
    switchSessionCommand := ""
    toggleBatchModeCommand := ""

    ; Sub-Controllers
    contextViewController := ""
    historyViewController := ""
    notesController := ""
    settingsController := ""
    recordingController := ""

    processingState := "idle" ; idle, processing, tool_pending, tool_running
    currentModelName := ""

    messagePresentationService := ""

    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager, clipboardParser, fileService, messagePresentationService) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
        this.clipboardParser := clipboardParser
        this.fileService := fileService
        this.messagePresentationService := messagePresentationService
    }

    SetCommands(saveConv, loadConv, clearCtx, compress, extract, resetAll, initializeApp, saveDiagram, renderMarkdown, cancelRequest, executeToolCalls, sendToLLM, sendBatchToLLM, renderLastMsg, uncheckImages, processClipboard, switchSession, toggleBatchMode) {
        this.saveConversationCommand := saveConv
        this.loadConversationCommand := loadConv
        this.clearContextCommand := clearCtx
        this.compressHistoryCommand := compress
        this.extractLearningsCommand := extract
        this.resetAllCommand := resetAll
        this.initializeAppCommand := initializeApp
        this.saveDiagramCommand := saveDiagram
        this.renderMarkdownCommand := renderMarkdown
        this.cancelRequestCommand := cancelRequest
        this.executeToolCallsCommand := executeToolCalls
        this.sendToLLMCommand := sendToLLM
        this.sendBatchToLLMCommand := sendBatchToLLM
        this.renderLastMessageCommand := renderLastMsg
        this.uncheckImagesCommand := uncheckImages
        this.processClipboardCommand := processClipboard
        this.switchSessionCommand := switchSession
        this.toggleBatchModeCommand := toggleBatchMode
    }

    SetSubControllers(ctxView, histView, notes, settings, recording) {
        this.contextViewController := ctxView
        this.historyViewController := histView
        this.notesController := notes
        this.settingsController := settings
        this.recordingController := recording
    }

    SetTrayView(trayView) {
        if (this.recordingController)
            this.recordingController.SetTrayView(trayView)
    }

    SetView(view) {
        this.view := view
    }

    CompressHistory(*) {
        ; Disable Ask LLM button while processing
        if (this.view.guiShown) {
            this.view.SetAskButtonText("Compressing...")
            this.view.SetAskButtonEnabled(false)
        }

        try {
            compressedMsg := this.compressHistoryCommand.Execute()

            if (compressedMsg != "") {
                 ; Update UI
                 this.historyViewController.UpdateChatHistoryView()
                 this.RenderMarkdown(this.messagePresentationService.GetPresentationText(compressedMsg))
            }

        } catch as e {
            MsgBox("Compression failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.view.guiShown) {
                this.view.SetAskButtonText("Ask LLM")
                this.view.SetAskButtonEnabled(true)
            }
        }
    }

    ExtractLearnings(*) {
        ; Disable Ask LLM button while processing
        if (this.view.guiShown) {
            this.view.SetAskButtonText("Extracting...")
            this.view.SetAskButtonEnabled(false)
        }

        try {
            extractedNotes := this.extractLearningsCommand.Execute()

            if (extractedNotes != "") {
                presentationText := this.messagePresentationService.GetPresentationText(extractedNotes)
                this.notesController.ShowNotes(presentationText)
            }

        } catch as e {
            MsgBox("Extraction failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.view.guiShown) {
                this.view.SetAskButtonText("Ask LLM")
                this.view.SetAskButtonEnabled(true)
            }
        }
    }

    Start() {
        this.initializeAppCommand.Execute()
        this.Show()
        if (this.recordingController)
            this.recordingController.UpdateUiBasesOnRecordingStatus()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.recordingService.isRecording) {
            this.recordingController.OnStartRecording()
        } else if (!this.view.guiShown) {
            this.view.Show()
        } else {
            this.recordingController.OnStopRecording()
        }
    }

    RenderMarkdown(content) {
        this.renderMarkdownCommand.Execute(content)
    }

    Show(*) {
        this.view.Show()
    }

    OnViewReady() {
        ; Initialize WebView after window is shown
        this.webViewManager.Init(this.view.GetResponseCtrHwnd())
        this.webViewManager.SetInputCallback(ObjBindMethod(this, "AppendToPrompt"))
        this.webViewManager.SetErrorCallback(ObjBindMethod(this, "OnWebViewError"))
        this.webViewManager.SetSaveDiagramCallback(ObjBindMethod(this, "OnSaveWebViewDiagram"))

        ; Update views
        this.historyViewController.UpdateChatHistoryView()
    }

    AskToLLM(*) {
        ; Check if user clicked to cancel tool execution
        if (this.processingState == "tool_running") {
            this.llmService.CancelTools()
            this.SetProcessingState("idle")
            return
        }

        ; 1. Gather UI state
        currentState := this.processingState
        promptText := this.view.GetPromptValue()

        isImageEnabled := this.IsImageInputEnabled[this.CurrentLLMTypeIndex]
        images := isImageEnabled ? this.sessionManager.GetCheckedImages() : []

        selectedIndices := []
        if (selectedIndex := this.view.GetContextBoxValue()) {
            selectedIndices.Push(selectedIndex)
        }

        batchItems := this.sessionManager.batchModeEnabled ? this.sessionManager.GetCheckedContextItems() : []

        if (this.sessionManager.batchModeEnabled && batchItems.Length == 0) {
            this.view.ShowMessage("Please check at least one item in the context list for batch mode.", "No Items Selected")
            return
        }

        ; 2. Update UI state before execution
        if (this.view.guiShown && this.processingState == "idle") {
            this.SetProcessingState("processing")
        }

        ; If we're about to execute pending tools, transition to tool_running state
        if (currentState == "tool_pending") {
            this.SetProcessingState("tool_running")
        }

        try {
            result := {}

            ; 3. Route to appropriate command
            if (currentState == "processing") {
                ; Handle Cancellation
                result := this.cancelRequestCommand.Execute()
            } else if (currentState == "tool_pending") {
                ; Handle Tool Confirmation
                if (this.executeToolCallsCommand.Execute()) {
                    result := this.sendToLLMCommand.Execute(promptText, images, selectedIndices, true)
                } else {
                    result := { action: "idle" }
                }
            } else if (this.sessionManager.batchModeEnabled) {
                ; Handle Batch Mode
                this.sendBatchToLLMCommand.Execute(
                    promptText,
                    batchItems,
                    () => (this.processingState != "processing"),
                    (label, messages) => this.historyViewController.UpdateChatHistoryView()
                )
                result := { action: "idle" }
            } else {
                ; Normal Send Mode
                result := this.sendToLLMCommand.Execute(promptText, images, selectedIndices)
            }

            ; 4. Handle Result and update UI State
            if (result.action == "idle") {
                this.SetProcessingState("idle")
            } else if (result.action == "tool_pending") {
                this.SetProcessingState("tool_pending")
            }

            ; 5. UI Cleanup
            if (result.action != "none") {
                this.view.ClearPrompt()

                if (this.recordingService.isRecording) {
                    this.recordingController.OnStopRecording()
                }
            }
        } catch as e {
            this.SetProcessingState("idle")
            if (e.Message != "Request cancelled") {
                this.view.ShowError("Error: " . e.Message)
            }
        } finally {
            ; 6. Refresh UI components
            this.historyViewController.UpdateChatHistoryView()
            this.renderLastMessageCommand.Execute()

            if (this.uncheckImagesCommand.Execute()) {
                this.contextViewController.UpdateContextView()
            }
        }
    }

    ExitApplication(*) => ExitApp()

    ClipChanged(DataType) {
        if (this.processClipboardCommand.Execute()) {
            ; Update Context in GUI if shown
            if (this.view.guiShown) {
                this.contextViewController.UpdateContextView()
            }
        }
    }

    OnPromptInput() {
        if (GetKeyState("Enter") && !GetKeyState("Shift")) {
            ; Get the current text
            text := this.view.GetPromptValue()
            if (SubStr(text, -1) == "`n") {
                ; Remove the trailing newline
                this.view.SetPromptValue(SubStr(text, 1, -1))
                ; Send the prompt
                this.AskToLLM()
            }
        }
    }

    AppendToPrompt(text) {
        currentText := this.view.GetPromptValue()
        if (currentText != "") {
            currentText .= "`n"
        }
        this.view.SetPromptValue(currentText . "> " . text . "`n")
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state via command
        isEnabled := this.toggleBatchModeCommand.Execute()

        ; Update menu checkmark
        this.view.UpdateBatchModeMenu(isEnabled)
    }

    SetProcessingState(state) {
        this.processingState := state

        if (state == "idle") {
            this.view.SetAskButtonText("Ask LLM")
            this.view.SetAskButtonEnabled(true)
        } else if (state == "processing") {
            this.view.SetAskButtonText("Cancel")
            this.view.SetAskButtonEnabled(true)
        } else if (state == "tool_pending") {
            this.view.SetAskButtonText("Confirm Tool Run")
            this.view.SetAskButtonEnabled(true)
        } else if (state == "tool_running") {
            this.view.SetAskButtonText("Cancel Tool")
            this.view.SetAskButtonEnabled(true)
        }
    }

    ; Event Handlers from UI/Tray
    OnDisplayLLM() => this.Show()
    OnExit() => this.ExitApplication()

    ClearAllContext(*) {
        this.clearContextCommand.Execute()
        this.contextViewController.UpdateContextView()
    }

    OnWebViewError(message) {
        this.view.ShowError(message)
    }

    OnSaveWebViewDiagram(svgData) {
        ; Use service to generate filename
        defaultFilename := this.fileService.GetTimestampedFilename("mermaid", ".svg")

        ; Use view to show dialog
        selectedFile := this.view.ShowSaveFileDialog(defaultFilename, "Save Mermaid Diagram", "SVG Files (*.svg)")

        ; Execute command to save
        this.saveDiagramCommand.Execute(selectedFile, svgData)
    }

    ; Data Properties for UI
    LLMTypes {
        get => this.configManager.llmTypes
    }

    CurrentLLMTypeIndex {
        get => this.sessionManager.GetCurrentSessionLLMType()
    }

    SessionNames {
        get => this.sessionManager.sessionNames
    }

    CurrentSessionIndex {
        get => this.sessionManager.currentSessionIndex
    }

    IsRecording {
        get => this.recordingService.isRecording
    }

    GetSystemPrompts(llmTypeIndex) {
        return this.configManager.GetSystemPromptNames(llmTypeIndex)
    }

    CurrentSystemPromptIndex {
        get => this.sessionManager.GetCurrentSessionSystemPrompt()
    }

    IsImageInputEnabled[llmTypeIndex] {
        get => this.configManager.IsImageInputEnabled(llmTypeIndex)
    }

    SessionChanged(*) {
        this.switchSessionCommand.Execute(this.view.GetSessionSelectValue())

        if (this.settingsController)
            this.settingsController.UpdateCompressionMenuState()

        this.UpdateSessionUI()
    }

    UpdateSessionUI() {
        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]

        ; 1. Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = currentModelIndex) {
                this.view.modelMenu.Check(modelName)
            } else {
                this.view.modelMenu.Uncheck(modelName)
            }
        }

        ; 2. Update menu bar label if model changed
        if (this.currentModelName != newModelName) {
            try this.view.menuBar.Rename(this.currentModelName, newModelName)
            this.currentModelName := newModelName
        }

        ; 3. Update Session Select UI
        this.view.SetSessionSelectValue(this.sessionManager.currentSessionIndex)

        ; 4. Update System Prompt UI
        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(currentModelIndex))
        this.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

        ; 5. Update Tools Menu
        if (this.settingsController)
            this.settingsController.UpdateToolsMenuState()

        ; 6. Refresh sub-views
        this.contextViewController.UpdateContextView()
        this.historyViewController.UpdateChatHistoryView()

        ; 7. Clear response area
        this.RenderMarkdown("")
    }

    ResetAll(*) {
        ; Reset current session
        this.resetAllCommand.Execute()

        ; Update UI
        this.UpdateSessionUI()
    }


    SaveConversation(*) {
        selectedFile := this.view.ShowSaveFileDialog("conversation.json", "Save Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.saveConversationCommand.Execute(selectedFile)
            } catch as e {
                 MsgBox("Failed to save conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

    LoadConversation(*) {
        selectedFile := this.view.ShowOpenFileDialog("Load Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.loadConversationCommand.Execute(selectedFile)
                this.UpdateSessionUI()
            } catch as e {
                MsgBox("Failed to load conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

}
