#Requires AutoHotkey 2.0
#Include ..\Services\ProcessingState.ahk

class MainController {
    view := ""
    mainView := ""

    ; Sub-view references
    promptView := ""
    contextView := ""
    historyView := ""
    menuView := ""
    topControlsView := ""
    responseView := ""

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

    SetView(mainView, promptView, contextView, historyView, menuView, topControlsView, responseView) {
        this.mainView := mainView
        this.view := mainView  ; backward compat during migration
        this.promptView := promptView
        this.contextView := contextView
        this.historyView := historyView
        this.menuView := menuView
        this.topControlsView := topControlsView
        this.responseView := responseView
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
            MsgBox("Compression failed: " . e.Message, "Error", "Iconx")
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
            MsgBox("Extraction failed: " . e.Message, "Error", "Iconx")
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
        } else if (!this.mainView.guiShown) {
            this.mainView.Show()
        } else {
            this.recordingController.OnStopRecording()
        }
    }

    RenderMarkdown(content) {
        this.renderMarkdownCommand.Execute(content)
    }

    Show(*) {
        this.mainView.Show()
    }

    OnViewReady() {
        ; Initialize WebView after window is shown
        this.webViewManager.Init(this.responseView.GetHwnd())
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
        promptText := this.promptView.GetValue()

        isImageEnabled := this.IsImageInputEnabled[this.CurrentModelIndex]
        images := isImageEnabled ? this.sessionManager.GetCheckedImages() : []

        selectedIndices := []
        if (selectedIndex := this.contextView.GetValue()) {
            selectedIndices.Push(selectedIndex)
        }

        batchItems := this.sessionManager.batchModeEnabled ? this.sessionManager.GetCheckedContextItems() : []

        if (this.sessionManager.batchModeEnabled && batchItems.Length == 0) {
            MsgBox("Please check at least one item in the context list for batch mode.", "No Items Selected", "Iconi")
            return
        }

        ; 2. Update UI state before execution
        if (this.mainView.guiShown && this.sessionManager.GetCurrentProcessingState() == ProcessingState.IDLE) {
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
                this.promptView.Clear()

                if (this.recordingService.isRecording) {
                    this.recordingController.OnStopRecording()
                }
            }
        } catch as e {
            this.SetProcessingState(ProcessingState.IDLE)
            if (e.Message != "Request cancelled") {
                MsgBox("Error: " . e.Message, "Error", "Iconx")
            }
        } finally {
            ; 6. Refresh UI components
            this.historyViewController.UpdateChatHistoryView()
            this.renderLastMessageCommand.Execute()

            ; Refresh prompt dropdown (new prompts may have been created by tools)
            this.RefreshSystemPromptDropdown()

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
            if (this.mainView.guiShown) {
                this.contextViewController.UpdateContextView()
            }
        }
    }

    OnPromptInput() {
        if (GetKeyState("Enter") && !GetKeyState("Shift")) {
            ; Get the current text
            text := this.promptView.GetValue()
            if (SubStr(text, -1) == "`n") {
                ; Remove the trailing newline
                this.promptView.SetValue(SubStr(text, 1, -1))
                ; Send the prompt
                this.AskToLLM()
            }
        }
    }

    AppendToPrompt(text) {
        currentText := this.promptView.GetValue()
        if (currentText != "") {
            currentText .= "`n"
        }
        this.promptView.SetValue(currentText . "> " . text . "`n")
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state via command
        isEnabled := this.toggleBatchModeCommand.Execute()

        ; Update menu checkmark
        this.menuView.UpdateBatchMode(isEnabled)
    }

    SetProcessingState(state) {
        this.setProcessingStateCommand.Execute(state)

        if (state == ProcessingState.IDLE) {
            this.promptView.SetAskButtonText("Ask LLM")
            this.promptView.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.PROCESSING) {
            this.promptView.SetAskButtonText("Cancel")
            this.promptView.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.TOOL_PENDING) {
            this.promptView.SetAskButtonText("Confirm Tool Run")
            this.promptView.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.TOOL_RUNNING) {
            this.promptView.SetAskButtonText("Cancel Tool")
            this.promptView.SetAskButtonEnabled(true)
        } else if (state == ProcessingState.COMPRESSING) {
            this.promptView.SetAskButtonText("Compressing...")
            this.promptView.SetAskButtonEnabled(false)
        } else if (state == ProcessingState.EXTRACTING) {
            this.promptView.SetAskButtonText("Extracting...")
            this.promptView.SetAskButtonEnabled(false)
        }

        inProgress := (state == ProcessingState.PROCESSING || state == ProcessingState.TOOL_RUNNING)
        this.historyView.SetClearHistoryButtonEnabled(!inProgress)
        this.topControlsView.SetResetButtonEnabled(!inProgress)
    }

    ; Event Handlers from UI/Tray
    OnDisplayLLM() => this.Show()
    OnExit() => this.ExitApplication()

    ClearAllContext(*) {
        this.clearContextCommand.Execute()
        this.contextViewController.UpdateContextView()
    }

    OnWebViewError(message) {
        MsgBox(message, "Error", "Iconx")
    }

    OnSaveWebViewDiagram(svgData) {
        ; Use service to generate filename
        defaultFilename := FileService.GetTimestampedFilename("mermaid", ".svg")

        ; Use view to show dialog
        selectedFile := FileSelect("S16", defaultFilename, "Save Mermaid Diagram", "SVG Files (*.svg)")

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
        this.menuView.UpdateModelMenu(currentModelIndex, this.configManager.modelDisplayNames)

        ; 2. Update Session Select UI
        this.menuView.UpdateSessionMenu(this.sessionManager.currentSessionIndex, this.SessionLabels)

        ; 4. Update System Prompt UI
        this.promptView.ClearSystemPrompt()
        this.promptView.AddSystemPrompts(this.configManager.GetSystemPromptNames(currentModelIndex))
        this.promptView.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

        ; 5. Update Tools Menu
        if (this.settingsController)
            this.settingsController.UpdateToolsMenuState()

        ; 6. Refresh sub-views
        this.contextViewController.UpdateContextView()
        this.historyViewController.UpdateChatHistoryView()

        ; 7. Clear response area
        this.RenderMarkdown("")
    }

    RefreshSystemPromptDropdown() {
        currentModelIndex := this.sessionManager.GetCurrentSessionModelIndex()
        currentSelection := this.promptView.GetSystemPromptValue()

        promptNames := this.configManager.GetSystemPromptNames(currentModelIndex)
        this.promptView.ClearSystemPrompt()
        this.promptView.AddSystemPrompts(promptNames)

        ; Restore previous selection if it still exists, otherwise keep current index
        try {
            this.promptView.SetSystemPromptValue(currentSelection)
        } catch {
            ; Selection index out of range — fall back to current session index
            this.promptView.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())
        }
    }

    ResetAll(*) {
        this.resetAllCommand.Execute()
        this.UpdateSessionUI()
        modelIndex := this.sessionManager.GetCurrentSessionModelIndex()
        promptIndex := this.sessionManager.GetCurrentSessionSystemPrompt()
        if (inputTemplate := this.configManager.GetInputTemplate(modelIndex, promptIndex)) {
            this.promptView.SetValue(inputTemplate)
        }
        this.SetProcessingState(ProcessingState.IDLE)
    }


    SaveConversation(*) {
        selectedFile := FileSelect("S16", "conversation.json", "Save Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.saveConversationCommand.Execute(selectedFile)
            } catch as e {
                MsgBox("Failed to save conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

    LoadConversation(*) {
        selectedFile := FileSelect("3", , "Load Conversation", "JSON Files (*.json)")
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
