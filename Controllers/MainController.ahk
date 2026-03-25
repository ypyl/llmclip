#Requires AutoHotkey 2.0
#Include ..\Services\ProcessingState.ahk

class MainController {
    view := ""

    ; Dependencies
    configManager := ""
    sessionManager := ""
    llmService := ""
    webViewManager := ""
    recordingService := ""
    contextManager := ""


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
    setProcessingStateCommand := ""
    executeToolCallsCommand := ""
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    renderLastMessageCommand := ""
    processClipboardCommand := ""
    uncheckContextCommand := ""
    switchSessionCommand := ""
    toggleBatchModeCommand := ""
    saveStateOnExitCommand := ""
    saveConversationOnExitCommand := ""
    loadStateOnStartCommand := ""
    loadConversationOnStartCommand := ""

    ; Sub-Controllers
    contextViewController := ""
    historyViewController := ""
    notesController := ""
    settingsController := ""
    recordingController := ""


    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
    }

    SetCommands(saveConv, loadConv, clearCtx, compress, extract, resetAll, initializeApp, saveDiagram, renderMarkdown, cancelRequest, executeToolCalls, sendToLLM, sendBatchToLLM, renderLastMsg, uncheckContext, processClipboard, switchSession, toggleBatchMode, saveStateOnExit, saveConvOnExit, loadStateOnStart, loadConvOnStart, setProcessingState) {
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
        this.uncheckContextCommand := uncheckContext
        this.processClipboardCommand := processClipboard
        this.switchSessionCommand := switchSession
        this.toggleBatchModeCommand := toggleBatchMode
        this.saveStateOnExitCommand := saveStateOnExit
        this.saveConversationOnExitCommand := saveConvOnExit
        this.loadStateOnStartCommand := loadStateOnStart
        this.loadConversationOnStartCommand := loadConvOnStart
        this.setProcessingStateCommand := setProcessingState
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
        this.SetProcessingState(ProcessingState.COMPRESSING)

        try {
            compressedMsg := this.compressHistoryCommand.Execute()

            if (compressedMsg != "") {
                 ; Update UI
                 this.historyViewController.UpdateChatHistoryView()
                 this.RenderMarkdown(MessagePresentationService.GetPresentationText(compressedMsg))
            }

        } catch as e {
            this.view.ShowError("Compression failed: " . e.Message)
        } finally {
            this.SetProcessingState(ProcessingState.IDLE)
        }
    }

    ExtractLearnings(*) {
        this.SetProcessingState(ProcessingState.EXTRACTING)

        try {
            extractedNotes := this.extractLearningsCommand.Execute()

            if (extractedNotes != "") {
                presentationText := MessagePresentationService.GetPresentationText(extractedNotes)
                this.notesController.ShowNotes(presentationText)
            }

        } catch as e {
            this.view.ShowError("Extraction failed: " . e.Message)
        } finally {
            this.SetProcessingState(ProcessingState.IDLE)
        }
    }

    Start() {
        ; Load persisted state and conversation before initializing
        try {
            this.loadStateOnStartCommand.Execute()
            this.loadConversationOnStartCommand.Execute()
        }

        this.initializeAppCommand.Execute()
        this.Show()
        this.UpdateSessionUI()
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
        if (this.sessionManager.GetCurrentProcessingState() == ProcessingState.TOOL_RUNNING) {
            this.cancelRequestCommand.Execute()
            this.SetProcessingState(ProcessingState.IDLE)
            return
        }

        ; 1. Gather UI state
        currentState := this.sessionManager.GetCurrentProcessingState()
        promptText := this.view.GetPromptValue()

        isImageEnabled := this.IsImageInputEnabled[this.CurrentModelIndex]
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
        if (this.view.guiShown && this.sessionManager.GetCurrentProcessingState() == ProcessingState.IDLE) {
            this.SetProcessingState(ProcessingState.PROCESSING)
        }

        ; If we're about to execute pending tools, transition to tool_running state
        if (currentState == ProcessingState.TOOL_PENDING) {
            this.SetProcessingState(ProcessingState.TOOL_RUNNING)
        }

        try {
            result := {}

            ; 3. Route to appropriate command
            if (currentState == ProcessingState.PROCESSING) {
                ; Handle Cancellation
                result := this.cancelRequestCommand.Execute()
            } else if (currentState == ProcessingState.TOOL_PENDING || currentState == ProcessingState.TOOL_RUNNING) {
                ; Handle Tool Confirmation
                if (this.executeToolCallsCommand.Execute()) {
                    result := this.sendToLLMCommand.Execute("", [], [], true)
                } else {
                    result := { action: ProcessingState.IDLE }
                }
            } else if (this.sessionManager.batchModeEnabled) {
                ; Handle Batch Mode
                this.sendBatchToLLMCommand.Execute(
                    promptText,
                    batchItems,
                    () => (this.sessionManager.GetCurrentProcessingState() != ProcessingState.PROCESSING),
                    (label, messages) => this.historyViewController.UpdateChatHistoryView()
                )
                result := { action: ProcessingState.IDLE }
            } else {
                ; Normal Send Mode
                result := this.sendToLLMCommand.Execute(promptText, images, selectedIndices)
            }

            ; 4. Handle auto-approval loop if needed
            while (result.action == ProcessingState.TOOL_PENDING && result.hasUnexecutedToolCalls) {
                messages := this.sessionManager.GetSessionMessages(this.sessionManager.currentSessionIndex)
                lastMsg := messages[messages.Length]
                
                if (this.executeToolCallsCommand.ShouldAutoApprove(lastMsg)) {
                    this.SetProcessingState(ProcessingState.TOOL_RUNNING)
                    if (this.executeToolCallsCommand.Execute()) {
                        result := this.sendToLLMCommand.Execute("", [], [], true)
                        continue
                    }
                }
                break
            }

            ; 5. Handle Result and update UI State
            if (result.action == ProcessingState.IDLE) {
                this.SetProcessingState(ProcessingState.IDLE)
            } else if (result.action == ProcessingState.TOOL_PENDING) {
                this.SetProcessingState(ProcessingState.TOOL_PENDING)
            }

            ; 6. UI Cleanup
            if (result.action != "none") {
                this.view.ClearPrompt()

                if (this.recordingService.isRecording) {
                    this.recordingController.OnStopRecording()
                }
            }
        } catch as e {
            this.SetProcessingState(ProcessingState.IDLE)
            if (e.Message != "Request cancelled") {
                this.view.ShowError("Error: " . e.Message)
            }
        } finally {
            ; 6. Refresh UI components
            this.historyViewController.UpdateChatHistoryView()
            this.renderLastMessageCommand.Execute()

            if (this.uncheckContextCommand.Execute()) {
                this.contextViewController.UpdateContextView()
            }
        }
    }

    SaveStateAndConversation() {
        try {
            this.saveStateOnExitCommand.Execute()
            this.saveConversationOnExitCommand.Execute()
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
        this.view.UpdateBatchMode(isEnabled)
    }

    SetProcessingState(state) {
        this.setProcessingStateCommand.Execute(state)

        if (state == ProcessingState.IDLE) {
            this.view.SetAskButtonText("Ask LLM")
            this.view.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.PROCESSING) {
            this.view.SetAskButtonText("Cancel")
            this.view.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.TOOL_PENDING) {
            this.view.SetAskButtonText("Confirm Tool Run")
            this.view.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.TOOL_RUNNING) {
            this.view.SetAskButtonText("Cancel Tool")
            this.view.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.COMPRESSING) {
            this.view.SetAskButtonText("Compressing...")
            this.view.SetAskButtonEnabled(false)
        } else if (state == ProcessingState.EXTRACTING) {
            this.view.SetAskButtonText("Extracting...")
            this.view.SetAskButtonEnabled(false)
        }

        inProgress := (state == ProcessingState.PROCESSING || state == ProcessingState.TOOL_RUNNING)
        this.view.SetClearHistoryButtonEnabled(!inProgress)
        this.view.SetResetAllButtonEnabled(!inProgress)
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
        defaultFilename := FileService.GetTimestampedFilename("mermaid", ".svg")

        ; Use view to show dialog
        selectedFile := this.view.ShowSaveFileDialog(defaultFilename, "Save Mermaid Diagram", "SVG Files (*.svg)")

        ; Execute command to save
        this.saveDiagramCommand.Execute(selectedFile, svgData)
    }

    ; Data Properties for UI
    Models {
        get => this.configManager.models
    }

    ModelDisplayNames {
        get => this.configManager.modelDisplayNames
    }

    CurrentModelIndex {
        get => this.sessionManager.GetCurrentSessionModelIndex()
    }

    SessionNames {
        get => this.sessionManager.sessionNames
    }

    SessionLabels {
        get {
            labels := []
            Loop this.sessionManager.MAX_SESSIONS {
                sess := this.sessionManager.sessions[A_Index]
                names := this.configManager.GetSystemPromptNames(sess.llmType)
                promptIndex := sess.systemPromptIndex
                label := (promptIndex > 0 && promptIndex <= names.Length) ? names[promptIndex] : "Session " . A_Index
                labels.Push(label)
            }
            return labels
        }
    }

    CurrentSessionIndex {
        get => this.sessionManager.currentSessionIndex
    }

    IsRecording {
        get => this.recordingService.isRecording
    }

    GetSystemPrompts(modelIndex) {
        return this.configManager.GetSystemPromptNames(modelIndex)
    }

    CurrentSystemPromptIndex {
        get => this.sessionManager.GetCurrentSessionSystemPrompt()
    }

    IsImageInputEnabled[modelIndex] {
        get => this.configManager.IsImageInputEnabled(modelIndex)
    }


    UpdateSessionUI() {
        currentModelIndex := this.sessionManager.GetCurrentSessionModelIndex()

        ; 1. Update Models Menu (delegated to View)
        this.view.UpdateModelMenu(currentModelIndex, this.configManager.modelDisplayNames)

        ; 2. Update Session Select UI
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
        this.resetAllCommand.Execute()
        this.UpdateSessionUI()
        this.SetProcessingState(ProcessingState.IDLE)
    }


    SaveConversation(*) {
        selectedFile := this.view.ShowSaveFileDialog("conversation.json", "Save Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.saveConversationCommand.Execute(selectedFile)
            } catch as e {
                this.view.ShowError("Failed to save conversation: " . e.Message)
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
                this.view.ShowError("Failed to load conversation: " . e.Message)
            }
        }
    }

}
