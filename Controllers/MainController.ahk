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
    selectModelCommand := ""
    getToolsStateCommand := ""
    getCompressionStateCommand := ""
    toggleToolCommand := ""


    ; Sub-Controllers
    contextViewController := ""
    historyViewController := ""
    notesController := ""

    batchModeEnabled := false
    processingState := "idle" ; idle, processing, tool_pending
    currentModelName := ""
    currentAnswerSize := "Default"


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

    SetCommands(saveConv, loadConv, clearCtx, stopRec, startRec, compress, extract, resetAll, toggleRec, initializeApp, saveDiagram, renderMarkdown, submitPrompt, renderLastMsg, uncheckImages, processClipboard, selectModel, getToolsState, getCompressionState, toggleTool) {

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
        this.selectModelCommand := selectModel
        this.getToolsStateCommand := getToolsState
        this.getCompressionStateCommand := getCompressionState
        this.toggleToolCommand := toggleTool
    }


    SetSubControllers(ctxView, histView, notes) {
        this.contextViewController := ctxView
        this.historyViewController := histView
        this.notesController := notes
    }


    SetView(view) {
        this.view := view
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Update session with new model index
        this.selectModelCommand.Execute(ItemPos)

        ; Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = ItemPos) {
                MyMenu.Check(modelName)
            } else {
                MyMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label
        oldModelName := this.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[ItemPos]
        if (oldModelName != newModelName) {
            try this.view.menuBar.Rename(oldModelName, newModelName)
            this.currentModelName := newModelName
        }

        ; Update system prompts for the new model
        this.view.ClearSystemPrompt()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType())
        this.view.AddSystemPromptItems(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            this.view.SetSystemPromptValue(1)
            this.view.SetSystemPromptEnabled(true)
        } else {
            this.view.SetSystemPromptEnabled(false)
        }

        this.UpdateToolsMenuState()
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

        ; Update state
        this.currentAnswerSize := ItemName
    }

    UpdateCompressionMenuState() {
        if (!this.view || !this.view.historyMenu)
            return

        isEnabled := this.getCompressionStateCommand.Execute()

        if (isEnabled) {
            this.view.historyMenu.Enable("Compress")
        } else {
            this.view.historyMenu.Disable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.view || !this.view.toolsMenu)
            return

        toolStates := this.getToolsStateCommand.Execute()
        
        ; Update PowerShell
        if (toolStates.powerShell) {
            this.view.toolsMenu.Check("PowerShell")
        } else {
            this.view.toolsMenu.Uncheck("PowerShell")
        }

        ; Update File System
        if (toolStates.fileSystem) {
             this.view.toolsMenu.Check("File System")
        } else {
             this.view.toolsMenu.Uncheck("File System")
        }

        ; Update Web Search
        if (toolStates.webSearch) {
            this.view.toolsMenu.Check("Web Search")
        } else {
            this.view.toolsMenu.Uncheck("Web Search")
        }

        ; Update Web Fetch
        if (toolStates.webFetch) {
            this.view.toolsMenu.Check("Web Fetch")
        } else {
            this.view.toolsMenu.Uncheck("Web Fetch")
        }
    }

    ToggleTool(toolName, *) {
        ; Execute toggle command
        this.toggleToolCommand.Execute(toolName)
        
        ; Update UI
        this.UpdateToolsMenuState()
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

    SystemPromptChanged(*) {
        this.sessionManager.SetCurrentSessionSystemPrompt(this.view.GetSystemPromptValue())

        ; Update the system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        inputTemplate := this.configManager.GetInputTemplate(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        if (inputTemplate) {
            this.view.SetPromptValue(inputTemplate)
        }
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
        this.contextViewController.UpdateContextView()
    }
    
    AskToLLM(*) {
        ; 1. Gather UI state
        currentState := this.processingState
        promptText := this.view.GetPromptValue()
        focusedRow := this.view.GetSelectedHistoryIndex()
        isBatchMode := this.batchModeEnabled
        answerSize := this.currentAnswerSize
        
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
                answerSize: answerSize,
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

    SessionChanged(*) {
        oldModelName := this.currentModelName

        ; Switch to new session
        this.sessionManager.SwitchSession(this.view.GetSessionSelectValue())

        this.contextViewController.UpdateContextView()
        this.historyViewController.UpdateChatHistoryView()

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]

        ; Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = currentModelIndex) {
                this.view.modelMenu.Check(modelName)
            } else {
                this.view.modelMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label if model changed
        if (oldModelName != newModelName) {
            try this.view.menuBar.Rename(oldModelName, newModelName)
            this.currentModelName := newModelName
        }

        ; Update system prompts for the selected LLM type
        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
        this.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

        ; Clear response field
        this.RenderMarkdown("")

        this.menuController.UpdateCompressionMenuState()
    }

    ResetAll(*) {
        ; Reset current session
        this.resetAllCommand.Execute()

        ; Update UI
        this.historyViewController.UpdateChatHistoryView()
        this.contextViewController.UpdateContextView()

        ; Clear response and prompt
        this.RenderMarkdown("")
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
                 this.RenderMarkdown(this.sessionManager.GetMessageAsString(compressedMsg))
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
                this.notesController.ShowNotes(extractedNotes)
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

                ; Update LLM Type
                currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
                for index, modelName in this.configManager.llmTypes {
                    if (index = currentModelIndex) {
                        this.view.modelMenu.Check(modelName)
                    } else {
                        this.view.modelMenu.Uncheck(modelName)
                    }
                }

                ; Update model name label
                oldModelName := this.currentModelName
                newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]
                try this.view.menuBar.Rename(oldModelName, newModelName)
                this.currentModelName := newModelName

                ; Update Session UI
                this.view.SetSessionSelectValue(this.sessionManager.currentSessionIndex)
                this.contextViewController.UpdateContextView()

                ; Update System Prompt UI
                this.view.ClearSystemPrompt()
                this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
                this.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

                ; Update System Prompt Content
                systemPrompt := this.configManager.GetSystemPromptValue(
                    this.sessionManager.GetCurrentSessionLLMType(),
                    this.sessionManager.GetCurrentSessionSystemPrompt()
                )
                this.sessionManager.UpdateSystemPromptContent(systemPrompt)

                ; Update History View
                this.historyViewController.UpdateChatHistoryView()
                
                ; Update Tools Menu
                this.menuController.UpdateToolsMenuState()

                ; Clear Response Area
                this.RenderMarkdown("")

            } catch as e {
                MsgBox("Failed to load conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

    ReloadSettings(*) {
        ; Reload settings from disk
        this.configManager.Reload()

        ; Refresh LLM Type dropdown
        ; Refresh Model Menu
        this.view.modelMenu.Delete() ; Delete all items
        for index, modelName in this.configManager.llmTypes {
            this.view.modelMenu.Add(modelName, ObjBindMethod(this, "SelectModel"))
        }

        ; Restore model checkmark
        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.configManager.llmTypes.Length) {
            this.view.modelMenu.Check(this.configManager.llmTypes[currentModelIndex])
        } else {
            ; If former selection no longer exists, default to first
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.view.modelMenu.Check(this.configManager.llmTypes[1])
        }

        ; Update MenuBar label
        oldModelName := this.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.view.menuBar.Rename(oldModelName, newModelName)
        this.currentModelName := newModelName

        ; Refresh System Prompt Combo
        currentSystemPrompt := this.view.GetSystemPromptValue()

        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        ; Try to preserve current selection, otherwise default to first
        try {
            this.view.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.view.SetSystemPromptValue(1)
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }
}
