#Requires AutoHotkey 2.0

class MainController {
    view := ""
    currentAnswerSize := "Default"
    currentModelName := ""
    batchModeEnabled := false

    ; Dependencies
    configManager := ""
    sessionManager := ""
    llmService := ""
    webViewManager := ""
    recordingService := ""
    contextManager := ""
    clipboardParser := ""
    
    ; Commands
    saveConversationCommand := ""
    loadConversationCommand := ""
    clearContextCommand := ""
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    confirmToolCommand := ""
    regenerateMessageCommand := ""
    stopRecordingCommand := ""
    startRecordingCommand := ""
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    resetAllCommand := ""
    toggleRecordingCommand := ""
    initializeAppCommand := ""

    ; Sub-Controllers
    menuController := ""
    chatController := ""
    conversationController := ""
    clipboardController := ""
    contextViewController := ""
    historyViewController := ""
    notesController := ""
    promptController := ""


    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager, clipboardParser) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
        this.clipboardParser := clipboardParser
    }

    SetCommands(saveConv, loadConv, clearCtx, sendLLM, sendBatch, confirmTool, regenerate, stopRec, startRec, compress, extract, resetAll, toggleRec, initializeApp) {
        this.saveConversationCommand := saveConv
        this.loadConversationCommand := loadConv
        this.clearContextCommand := clearCtx
        this.sendToLLMCommand := sendLLM
        this.sendBatchToLLMCommand := sendBatch
        this.confirmToolCommand := confirmTool
        this.regenerateMessageCommand := regenerate
        this.stopRecordingCommand := stopRec
        this.startRecordingCommand := startRec
        this.compressHistoryCommand := compress
        this.extractLearningsCommand := extract
        this.resetAllCommand := resetAll
        this.toggleRecordingCommand := toggleRec
        this.initializeAppCommand := initializeApp
    }

    SetSubControllers(menu, chat, conv, clip, ctxView, histView, notes, prompt) {
        this.menuController := menu
        this.chatController := chat
        this.conversationController := conv
        this.clipboardController := clip
        this.contextViewController := ctxView
        this.historyViewController := histView
        this.notesController := notes
        this.promptController := prompt
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
            this.Show()
        } else {
            this.stopRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        }
    }

    RenderMarkdown(content) {
        this.webViewManager.RenderMarkdown(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        ; This needs to be coordinated via TrayView as well if we had one here
        ; But AppController had TrayViewValue.
        ; For now, I'll keep the logic here and App will wire TrayView to call MainController.
        if (this.view.guiShown) {
             this.view.UpdateRecordButton(this.recordingService.isRecording)
        }
    }

    Show(*) {
        this.view.Show()
    }

    OnViewReady() {
        ; Initialize WebView after window is shown
        this.webViewManager.Init(this.view.gui["ResponseCtr"])
        this.webViewManager.SetInputCallback(ObjBindMethod(this.promptController, "AppendToPrompt"))
        this.webViewManager.SetErrorCallback(ObjBindMethod(this, "OnWebViewError"))
        this.webViewManager.SetSaveDiagramCallback(ObjBindMethod(this, "OnSaveWebViewDiagram"))
        
        ; Update views
        this.historyViewController.UpdateChatHistoryView()
    }

    SystemPromptChanged(*) => this.conversationController.SystemPromptChanged()
    
    HandleToolConfirmation() => this.chatController.HandleToolConfirmation()
    HandleCancellation() => this.chatController.HandleCancellation()
    HandleRegenerationOrEdit(promptText) => this.chatController.HandleRegenerationOrEdit(promptText)
    AskToLLM(*) => this.chatController.AskToLLM()
    SendBatchToLLM(promptText) => this.chatController.SendBatchToLLM(promptText)
    SendToLLM() => this.chatController.SendToLLM()
    
    ExitApplication(*) => ExitApp()
    ClipChanged(DataType) => this.clipboardController.ClipChanged(DataType)

    OnPromptInput() => this.promptController.OnPromptInput()
    AppendToPrompt(text) => this.promptController.AppendToPrompt(text)

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
        MsgBox(message)
    }

    OnSaveWebViewDiagram(svgData) {
        ; Generate a default filename with timestamp
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        defaultFilename := "mermaid_" . timestamp . ".svg"

        ; Show save dialog
        selectedFile := FileSelect("S16", defaultFilename, "Save Mermaid Diagram", "SVG Files (*.svg)")

        ; Check if user cancelled
        if (selectedFile = "") {
            return
        }

        ; Ensure .svg extension
        if (!RegExMatch(selectedFile, "i)\.svg$")) {
            selectedFile .= ".svg"
        }

        ; Save SVG to selected file
        try FileDelete(selectedFile)
        FileAppend(svgData, selectedFile, "UTF-8")
    }
}
