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

    ; Sub-Controllers
    menuController := ""
    chatController := ""
    conversationController := ""
    clipboardController := ""
    contextViewController := ""
    historyViewController := ""
    notesController := ""


    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager, clipboardParser) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
        this.clipboardParser := clipboardParser
    }

    SetCommands(saveConv, loadConv, clearCtx, sendLLM, sendBatch, confirmTool, regenerate, stopRec, startRec, compress, extract, resetAll, toggleRec) {
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
    }

    SetSubControllers(menu, chat, conv, clip, ctxView, histView, notes) {
        this.menuController := menu
        this.chatController := chat
        this.conversationController := conv
        this.clipboardController := clip
        this.contextViewController := ctxView
        this.historyViewController := histView
        this.notesController := notes
    }


    SetView(view) {
        this.view := view
    }

    Start() {
        TempFileManager.CleanUp()
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

    SystemPromptChanged(*) => this.conversationController.SystemPromptChanged()
    
    HandleToolConfirmation() => this.chatController.HandleToolConfirmation()
    HandleCancellation() => this.chatController.HandleCancellation()
    HandleRegenerationOrEdit(promptText) => this.chatController.HandleRegenerationOrEdit(promptText)
    AskToLLM(*) => this.chatController.AskToLLM()
    SendBatchToLLM(promptText) => this.chatController.SendBatchToLLM(promptText)
    SendToLLM() => this.chatController.SendToLLM()
    
    ExitApplication(*) => ExitApp()
    ClipChanged(DataType) => this.clipboardController.ClipChanged(DataType)

    AppendToPrompt(text) {
        currentText := this.view.GetPromptValue()
        if (currentText != "") {
            currentText .= "`n"
        }
        this.view.SetPromptValue(currentText . "> " . text . "`n")
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
}
