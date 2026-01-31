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
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    resetAllCommand := ""

    ; Sub-Controllers
    menuManager := ""
    chatManager := ""
    conversationHandler := ""
    clipboardManager := ""
    contextViewController := ""
    historyViewController := ""

    __New(configManager, sessionManager, llmService, webViewManager, recordingService, contextManager, clipboardParser) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.webViewManager := webViewManager
        this.recordingService := recordingService
        this.contextManager := contextManager
        this.clipboardParser := clipboardParser
    }

    SetCommands(saveConv, loadConv, clearCtx, sendLLM, sendBatch, confirmTool, regenerate, stopRec, compress, extract, resetAll) {
        this.saveConversationCommand := saveConv
        this.loadConversationCommand := loadConv
        this.clearContextCommand := clearCtx
        this.sendToLLMCommand := sendLLM
        this.sendBatchToLLMCommand := sendBatch
        this.confirmToolCommand := confirmTool
        this.regenerateMessageCommand := regenerate
        this.stopRecordingCommand := stopRec
        this.compressHistoryCommand := compress
        this.extractLearningsCommand := extract
        this.resetAllCommand := resetAll
    }

    SetSubControllers(menu, chat, conv, clip, ctxView, histView) {
        this.menuManager := menu
        this.chatManager := chat
        this.conversationHandler := conv
        this.clipboardManager := clip
        this.contextViewController := ctxView
        this.historyViewController := histView
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
            this.recordingService.StartRecording()
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

    SystemPromptChanged(*) => this.conversationHandler.SystemPromptChanged()
    
    HandleToolConfirmation() => this.chatManager.HandleToolConfirmation()
    HandleCancellation() => this.chatManager.HandleCancellation()
    HandleRegenerationOrEdit(promptText) => this.chatManager.HandleRegenerationOrEdit(promptText)
    AskToLLM(*) => this.chatManager.AskToLLM()
    SendBatchToLLM(promptText) => this.chatManager.SendBatchToLLM(promptText)
    SendToLLM() => this.chatManager.SendToLLM()
    
    ExitApplication(*) => ExitApp()
    ClipChanged(DataType) => this.clipboardManager.ClipChanged(DataType)

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
        this.recordingService.StartRecording()
        this.UpdateUiBasesOnRecordingStatus()
        ; Update tray status if needed - this should be handled by a listener or direct call
    }

    OnStopRecording() {
        this.stopRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnToggleRecording() {
        this.recordingService.ToggleRecording(this.sessionManager, this.contextManager)
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnDisplayLLM() => this.Show()
    OnExit() => this.ExitApplication()

    ClearAllContext(*) {
        this.clearContextCommand.Execute()
        this.contextViewController.UpdateContextView()
    }
}
