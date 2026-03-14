#Requires AutoHotkey 2.0
#Include Services\Configuration\ConfigurationService.ahk
#Include Services\Base64Service.ahk
#Include Services\LLM\LLMService.ahk
#Include Services\LLM\MarkdownNewTool.ahk
#Include Services\SessionManager.ahk
#Include Services\ClipboardParserService.ahk
#Include Services\WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include Services\RecordingService.ahk
#Include Services\MessagePresentationService.ahk
#Include Services\ContextPresentationService.ahk
#Include ui\TrayView.ahk
#Include ui\UIConfig.ahk
#Include ui\MainView.ahk
#Include Controllers\MainController.ahk
#Include Controllers\ContextViewController.ahk
#Include Controllers\HistoryViewController.ahk
#Include Controllers\NotesController.ahk
#Include Controllers\SettingsController.ahk
#Include Controllers\RecordingController.ahk
#Include Services\FileService.ahk
#Include Commands\SaveConversationCommand.ahk
#Include Commands\LoadConversationCommand.ahk
#Include Commands\ClearContextCommand.ahk
#Include Commands\StopRecordingCommand.ahk
#Include Commands\StartRecordingCommand.ahk
#Include Commands\ToggleRecordingCommand.ahk
#Include Commands\DeleteMessageCommand.ahk
#Include Commands\ClearHistoryCommand.ahk
#Include Commands\CompressHistoryCommand.ahk
#Include Commands\ExtractLearningsCommand.ahk
#Include Commands\ResetAllCommand.ahk
#Include ui\NotesView.ahk
#Include Services\ClipboardService.ahk
#Include Commands\CopyToClipboardCommand.ahk
#Include Commands\SelectModelCommand.ahk
#Include Commands\GetToolsMenuStateCommand.ahk
#Include Commands\GetCompressionMenuStateCommand.ahk
#Include Commands\ToggleToolCommand.ahk
#Include Commands\InitializeAppCommand.ahk
#Include Commands\ProcessClipboardCommand.ahk
#Include Commands\SaveDiagramCommand.ahk
#Include Commands\SaveEditedMessageCommand.ahk
#Include Commands\ReplaceLinkWithContentCommand.ahk
#Include Commands\RenderMarkdownCommand.ahk
#Include Commands\RenderLastMessageCommand.ahk
#Include Commands\DeleteContextItemsCommand.ahk
#Include Commands\PrepareContextCommand.ahk
#Include Commands\GetHistoryListItemsCommand.ahk
#Include Commands\GetMessagePresentationCommand.ahk
#Include Commands\UncheckContextCommand.ahk
#Include Commands\CancelRequestCommand.ahk
#Include Commands\ExecuteToolCallsCommand.ahk
#Include Commands\RegenerateMessageCommand.ahk
#Include Commands\NavigateHistoryCommand.ahk
#Include Commands\GetHistoryInfoCommand.ahk
#Include Commands\SendToLLMCommand.ahk
#Include Commands\SendBatchToLLMCommand.ahk
#Include Commands\SetContextItemCheckedCommand.ahk
#Include Commands\ChangeSystemPromptCommand.ahk
#Include Commands\SwitchSessionCommand.ahk
#Include Commands\ReloadSettingsCommand.ahk
#Include Commands\ChangeAnswerSizeCommand.ahk
#Include Commands\ToggleBatchModeCommand.ahk
#Include Services\StateService.ahk
#Include Commands\SaveStateOnExitCommand.ahk
#Include Commands\SaveConversationOnExitCommand.ahk
#Include Commands\LoadStateOnStartCommand.ahk
#Include Commands\LoadConversationOnStartCommand.ahk
#Include Commands\SetProcessingStateCommand.ahk

class App {
    controller := ""
    trayView := ""
    view := ""

    __New() {
        ; 1. Initialize Services
        cfg := ConfigurationService.GetInstance()
        ctx := ContextManager()
        sess := SessionManager(
            cfg.selectedLLMTypeIndex,
            cfg.GetSystemPromptValue(cfg.selectedLLMTypeIndex, 1),
            ctx
        )
        cp := ClipboardParserService()
        wv := WebViewManager()
        rec := RecordingService()
        wv := WebViewManager()
        rec := RecordingService()
        llm := LLMService(cfg)
        
        mps := MessagePresentationService()
        cps := ContextPresentationService(ctx)

        this.controller := MainController(
            cfg, 
            sess, 
            llm, 
            wv, 
            rec, 
            ctx, 
            cp,
            mps
        )

        ; 2. Initialize Commands
        saveConv := SaveConversationCommand(sess)
        loadConv := LoadConversationCommand(sess, cfg)
        clearCtx := ClearContextCommand(sess)
        stopRec := StopRecordingCommand(rec, sess, ctx)
        startRec := StartRecordingCommand(rec)
        toggleRec := ToggleRecordingCommand(rec, sess, ctx)
        compress := CompressHistoryCommand(sess, cfg, llm)
        extract := ExtractLearningsCommand(sess, cfg, llm)
        resetAll := ResetAllCommand(sess)
        deleteMsg := DeleteMessageCommand(sess)
        clearHist := ClearHistoryCommand(sess, cfg)
        copyToClip := CopyToClipboardCommand()
        selectModel := SelectModelCommand(sess)
        getToolsState := GetToolsMenuStateCommand(cfg, sess)
        getCompressionState := GetCompressionMenuStateCommand(cfg, sess)
        toggleTool := ToggleToolCommand(cfg, sess)
        initializeApp := InitializeAppCommand()
        processClip := ProcessClipboardCommand(rec, cp, sess)
        saveDiagram := SaveDiagramCommand()
        mdn := MarkdownNewTool()
        replaceLink := ReplaceLinkWithContentCommand(mdn, sess, ctx)
        renderMarkdown := RenderMarkdownCommand(wv)
        saveEditedMsg := SaveEditedMessageCommand(sess, cfg)
        renderLastMsg := RenderLastMessageCommand(sess, mps, wv)
        deleteCtxItems := DeleteContextItemsCommand(sess)
        prepareContext := PrepareContextCommand(sess, cfg)
        getHistoryItems := GetHistoryListItemsCommand(sess, mps)
        getMessagePresentation := GetMessagePresentationCommand(sess, mps)
        uncheckContext := UncheckContextCommand(sess)
        setContextItemChecked := SetContextItemCheckedCommand(sess)

        cancelRequest := CancelRequestCommand(llm)
        executeToolCalls := ExecuteToolCallsCommand(sess, llm, cfg.systemPromptsManager)
        regenerateMessage := RegenerateMessageCommand(sess)
        navigateHistoryPrevious := NavigateHistoryCommand(sess, "previous")
        navigateHistoryNext := NavigateHistoryCommand(sess, "next")
        getHistoryInfo := GetHistoryInfoCommand(sess)
        sendToLLM := SendToLLMCommand(sess, cfg, llm, ctx, executeToolCalls)
        sendBatchToLLM := SendBatchToLLMCommand(sess, cfg, llm, ctx)
        changeSystemPrompt := ChangeSystemPromptCommand(sess, cfg)
        switchSession := SwitchSessionCommand(sess)
        reloadSettings := ReloadSettingsCommand(cfg)
        changeAnswerSize := ChangeAnswerSizeCommand(sess)
        toggleBatchMode := ToggleBatchModeCommand(sess)

        ; State persistence commands
        ; State persistence commands
        saveStateOnExit := SaveStateOnExitCommand(sess)
        saveConvOnExit := SaveConversationOnExitCommand(sess)
        loadStateOnStart := LoadStateOnStartCommand(sess, cfg)
        loadConvOnStart := LoadConversationOnStartCommand(sess, cfg)
        setProcessingState := SetProcessingStateCommand(sess)

        ; 3. Initialize View
        this.view := MainView(this.controller)
        this.controller.SetView(this.view)

        this.controller.SetCommands(
            saveConv, loadConv, clearCtx, compress, extract, resetAll, initializeApp, saveDiagram, renderMarkdown, cancelRequest, executeToolCalls, sendToLLM, sendBatchToLLM, renderLastMsg, uncheckContext, processClip, switchSession, toggleBatchMode, saveStateOnExit, saveConvOnExit, loadStateOnStart, loadConvOnStart, setProcessingState
        )

        ; 4. Initialize Sub-Controllers
        ctxView := ContextViewController(this.view.contextView, this.view, sess, ctx, wv, cps, clearCtx, replaceLink, renderMarkdown, deleteCtxItems, prepareContext, setContextItemChecked)
        histView := HistoryViewController(this.view.historyView, this.view, getHistoryItems, getMessagePresentation, deleteMsg, clearHist, renderMarkdown, copyToClip, regenerateMessage, navigateHistoryPrevious, navigateHistoryNext, getHistoryInfo, setProcessingState, wv, saveEditedMsg)
        notesContr := NotesController(copyToClip)
        
        settingsContr := SettingsController(cfg, sess, selectModel, changeAnswerSize, toggleTool, getToolsState, getCompressionState, changeSystemPrompt, reloadSettings)
        recordingContr := RecordingController(rec, startRec, stopRec, toggleRec)

        this.controller.SetSubControllers(ctxView, histView, notesContr, settingsContr, recordingContr)
        this.view.SetSubControllers(ctxView, histView, settingsContr, recordingContr)
        
        settingsContr.SetViews(this.view.menuView, this.view.promptView, this.view)
        recordingContr.SetViews(this.view.topControlsView, this.view)

        ; 5. Initialize Tray
        this.trayView := TrayView(this.controller)
        this.controller.SetTrayView(this.trayView)
    }

    Start() {
        this.controller.Start()
        Hotkey("F3", (*) => this.controller.ToggleDisplay())
        Hotkey("F2", (*) => this.controller.ResetAll())
        Hotkey("F4", (*) => this.controller.AskToLLM())
    }
}
