#Requires AutoHotkey 2.0

class MainController {
    view := ""
    currentAnswerSize := "Default"
    currentModelName := ""

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
    stopRecordingCommand := ""
    startRecordingCommand := ""
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    resetAllCommand := ""
    toggleRecordingCommand := ""
    initializeAppCommand := ""
    saveDiagramCommand := ""
    renderMarkdownCommand := ""
    submitPromptCommand := ""
    renderLastMessageCommand := ""
    processClipboardCommand := ""
    uncheckImagesCommand := ""


    ; Sub-Controllers
    menuController := ""
    conversationController := ""
    contextViewController := ""
    historyViewController := ""
    notesController := ""

    batchModeEnabled := false
    processingState := "idle" ; idle, processing, tool_pending


    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager, clipboardParser, fileService) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
        this.clipboardParser := clipboardParser
        this.fileService := fileService
    }

    SetCommands(saveConv, loadConv, clearCtx, stopRec, startRec, compress, extract, resetAll, toggleRec, initializeApp, saveDiagram, renderMarkdown, submitPrompt, renderLastMsg, uncheckImages, processClipboard) {

        this.saveConversationCommand := saveConv
        this.loadConversationCommand := loadConv
        this.clearContextCommand := clearCtx
        this.stopRecordingCommand := stopRec
        this.startRecordingCommand := startRec
        this.compressHistoryCommand := compress
        this.extractLearningsCommand := extract
        this.resetAllCommand := resetAll
        this.toggleRecordingCommand := toggleRec
        this.initializeAppCommand := initializeApp
        this.saveDiagramCommand := saveDiagram
        this.renderMarkdownCommand := renderMarkdown
        this.submitPromptCommand := submitPrompt
        this.renderLastMessageCommand := renderLastMsg
        this.uncheckImagesCommand := uncheckImages
        this.processClipboardCommand := processClipboard
    }


    SetSubControllers(menu, conv, ctxView, histView, notes) {
        this.menuController := menu
        this.conversationController := conv
        this.contextViewController := ctxView
        this.historyViewController := histView
        this.notesController := notes
    }


    SetView(view) {
        this.view := view
    }

    Start() {
        this.initializeAppCommand.Execute()
        this.Show()
        this.UpdateUiBasesOnRecordingStatus()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.recordingService.isRecording) {
            this.startRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        } else if (!this.view.guiShown) {
            this.view.Show()
        } else {
            this.stopRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        }
    }


    RenderMarkdown(content) {
        this.renderMarkdownCommand.Execute(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.view.guiShown) {
             this.view.UpdateRecordButton(this.recordingService.isRecording)
        }
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

    SystemPromptChanged(*) => this.conversationController.SystemPromptChanged()
    
    AskToLLM(*) {
        ; 1. Gather UI state
        currentState := this.processingState
        promptText := this.view.GetPromptValue()
        focusedRow := this.view.GetSelectedHistoryIndex()
        isBatchMode := this.batchModeEnabled
        
        isImageEnabled := this.IsImageInputEnabled[this.CurrentLLMTypeIndex]
        images := isImageEnabled ? this.sessionManager.GetCheckedImages() : []

        selectedIndices := []
        if (selectedIndex := this.view.GetContextBoxValue()) {
            selectedIndices.Push(selectedIndex)
        }

        batchItems := isBatchMode ? this.sessionManager.GetCheckedContextItems() : []
        
        if (isBatchMode && batchItems.Length == 0) {
            this.view.ShowMessage("Please check at least one item in the context list for batch mode.", "No Items Selected")
            return
        }

        ; 2. Update UI state before execution
        if (this.view.guiShown && this.processingState == "idle") {
            this.SetProcessingState("processing")
        }

        try {
            ; 3. Execute Command with collected UI data
            result := this.submitPromptCommand.Execute({
                promptText: promptText,
                processingState: currentState,
                focusedRow: focusedRow,
                selectedContextIndices: selectedIndices,
                images: images,
                isBatchMode: isBatchMode,
                batchItems: batchItems,
                batchUpdateCallback: (label, messages) => this.historyViewController.UpdateChatHistoryView(),
                isCancelledCallback: () => (this.processingState == "processing")
            })

            ; 4. Handle Result and update UI State
            if (result.action == "load_to_prompt") {
                this.view.SetPromptValue(result.text)
                this.SetProcessingState("idle")
                return
            }

            if (result.action == "idle") {
                this.SetProcessingState("idle")
            } else if (result.action == "tool_pending") {
                this.SetProcessingState("tool_pending")
            }

            ; 5. UI Cleanup
            if (result.action != "none") {
                this.view.ClearPrompt()
                if (focusedRow > 0) {
                    this.view.DeselectHistoryItem(focusedRow)
                }
                
                if (this.recordingService.isRecording) {
                    this.stopRecordingCommand.Execute()
                    this.UpdateUiBasesOnRecordingStatus()
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
        ; Toggle batch mode state
        this.batchModeEnabled := !this.batchModeEnabled
        
        ; Update menu checkmark
        this.view.UpdateBatchModeMenu(this.batchModeEnabled)
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
        }
    }

    ToggleRecording(*) {
        this.ToggleDisplay()
    }

    ; Event Handlers from UI/Tray
    OnStartRecording() {
        this.startRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
        ; Update tray status if needed - this should be handled by a listener or direct call
    }

    OnStopRecording() {
        this.stopRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnToggleRecording() {
        this.toggleRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

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
}
