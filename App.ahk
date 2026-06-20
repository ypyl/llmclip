#Requires AutoHotkey 2.0
#Include Services\Configuration\ConfigurationService.ahk
#Include Utils\Base64Service.ahk
#Include Services\LLM\LLMService.ahk
#Include Services\LLM\MarkdownNewTool.ahk
#Include Services\LLM\PromptCreatorTool.ahk
#Include Services\SessionManager.ahk
#Include Utils\ClipboardParserService.ahk
#Include Services\WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include Services\RecordingService.ahk
#Include Services\LLM\PowerShellTool.ahk
#Include Services\LLM\FileSystemTool.ahk
#Include Services\LLM\WebSearchTool.ahk
#Include Services\LLM\WebFetchTool.ahk
#Include Services\LLM\LLMClient.ahk
#Include Services\LLM\Providers\OpenAIProvider.ahk
#Include Services\LLM\Providers\OllamaProvider.ahk
#Include Services\LLM\Providers\GoogleProvider.ahk
#Include Services\LLM\Providers\GroqAudioProvider.ahk
#Include Utils\MessagePresentationService.ahk
#Include Services\ContextPresentationService.ahk
#Include ui\TrayView.ahk
#Include ui\UIConfig.ahk
#Include ui\MainView.ahk
#Include Controllers\MainController.ahk
#Include Controllers\ContextViewController.ahk
#Include Controllers\HistoryViewController.ahk
#Include Controllers\SettingsController.ahk
#Include Utils\FileService.ahk
#Include Commands\SaveConversationCommand.ahk
#Include Commands\LoadConversationCommand.ahk
#Include Commands\ClearContextCommand.ahk
#Include Commands\StopRecordingCommand.ahk
#Include Commands\StartRecordingCommand.ahk
#Include Commands\ToggleRecordingCommand.ahk
#Include Commands\DeleteMessageCommand.ahk
#Include Commands\ClearHistoryCommand.ahk
#Include Commands\ResetAllCommand.ahk
#Include Utils\ClipboardService.ahk
#Include Commands\CopyToClipboardCommand.ahk
#Include Commands\SelectModelCommand.ahk
#Include Commands\GetToolsMenuStateCommand.ahk
#Include Commands\ToggleToolCommand.ahk
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
#Include Commands\SetContextItemCheckedCommand.ahk
#Include Commands\ChangeSystemPromptCommand.ahk
#Include Commands\SwitchSessionCommand.ahk
#Include Commands\ReloadSettingsCommand.ahk
#Include Utils\StateService.ahk
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
            1,
            cfg.GetSystemPromptValue(1, 1),
            ctx
        )
        wv := WebViewManager()
        rec := RecordingService()

        ; Initialize Tools
        pst := PowerShellTool()
        fst := FileSystemTool()
        wst := WebSearchTool()
        wft := WebFetchTool()
        mnt := MarkdownNewTool()
        pct := PromptCreatorTool()

        toolsMap := Map(
            PowerShellTool.TOOL_NAME, pst,
            FileSystemTool.TOOL_NAME, fst,
            WebSearchTool.TOOL_NAME, wst,
            WebFetchTool.TOOL_NAME, wft,
            MarkdownNewTool.TOOL_NAME, mnt,
            PromptCreatorTool.TOOL_NAME, pct
        )

        ; Initialize LLM Client and Providers
        llmProviders := Map(
            "openai", OpenAIProvider(),
            "ollama", OllamaProvider(),
            "google", GoogleProvider(),
            "audio", GroqAudioProvider()
        )
        clientInstance := LLMClient(llmProviders)

        llm := LLMService(cfg, toolsMap, clientInstance)

        cps := ContextPresentationService(ctx)

        this.controller := MainController(
            cfg,
            sess,
            llm,
            wv,
            rec,
            ctx
        )

        ; 2. Initialize Commands
        saveConv := SaveConversationCommand(sess)
        loadConv := LoadConversationCommand(sess, cfg)
        clearCtx := ClearContextCommand(sess)
        stopRec := StopRecordingCommand(rec)
        startRec := StartRecordingCommand(rec)
        toggleRec := ToggleRecordingCommand(rec)
        resetAll := ResetAllCommand(sess)
        deleteMsg := DeleteMessageCommand(sess)
        clearHist := ClearHistoryCommand(sess, cfg)
        copyToClip := CopyToClipboardCommand()
        selectModel := SelectModelCommand(sess)
        getToolsState := GetToolsMenuStateCommand(cfg, sess)
        toggleTool := ToggleToolCommand(cfg, sess)
        processClip := ProcessClipboardCommand(rec, sess)
        saveDiagram := SaveDiagramCommand()
        mdn := mnt
        replaceLink := ReplaceLinkWithContentCommand(mdn, sess, ctx)
        renderMarkdown := RenderMarkdownCommand(wv)
        saveEditedMsg := SaveEditedMessageCommand(sess, cfg)
        renderLastMsg := RenderLastMessageCommand(sess, wv)
        deleteCtxItems := DeleteContextItemsCommand(sess)
        prepareContext := PrepareContextCommand(sess, cfg)
        getHistoryItems := GetHistoryListItemsCommand(sess)
        getMessagePresentation := GetMessagePresentationCommand(sess)
        uncheckContext := UncheckContextCommand(sess)
        setContextItemChecked := SetContextItemCheckedCommand(sess)

        cancelRequest := CancelRequestCommand(llm)
        executeToolCalls := ExecuteToolCallsCommand(sess, llm, cfg.systemPromptsManager)
        regenerateMessage := RegenerateMessageCommand(sess)
        navigateHistoryPrevious := NavigateHistoryCommand(sess, "previous")
        navigateHistoryNext := NavigateHistoryCommand(sess, "next")
        getHistoryInfo := GetHistoryInfoCommand(sess)
        sendToLLM := SendToLLMCommand(sess, cfg, llm, ctx)
        changeSystemPrompt := ChangeSystemPromptCommand(sess, cfg)
        switchSession := SwitchSessionCommand(sess)
        reloadSettings := ReloadSettingsCommand(cfg)

        ; State persistence commands
        saveStateOnExit := SaveStateOnExitCommand(sess, cfg)
        saveConvOnExit := SaveConversationOnExitCommand(sess)
        loadStateOnStart := LoadStateOnStartCommand(sess, cfg)
        loadConvOnStart := LoadConversationOnStartCommand(sess, cfg)
        setProcessingState := SetProcessingStateCommand(sess)

        ; 3. Initialize View
        this.view := MainView(this.controller)
        this.controller.SetView(this.view, this.view.promptView, this.view.contextView, this.view.historyView, this.view.menuView, this.view.topControlsView, this.view.responseView)

        this.controller.SetCommands(
            saveConv, loadConv, clearCtx, resetAll, saveDiagram, renderMarkdown, cancelRequest, executeToolCalls, sendToLLM, renderLastMsg, uncheckContext, processClip, switchSession, saveStateOnExit, saveConvOnExit, loadStateOnStart, loadConvOnStart, setProcessingState, startRec, stopRec, toggleRec
        )

        ; 4. Initialize Sub-Controllers
        ctxView := ContextViewController(this.view.contextView, this.view, sess, ctx, wv, cps, clearCtx, replaceLink, renderMarkdown, deleteCtxItems, prepareContext, setContextItemChecked)
        histView := HistoryViewController(this.view.historyView, this.view, getHistoryItems, getMessagePresentation, deleteMsg, clearHist, renderMarkdown, copyToClip, regenerateMessage, navigateHistoryPrevious, navigateHistoryNext, getHistoryInfo, setProcessingState, wv, saveEditedMsg)

        settingsContr := SettingsController(cfg, sess, selectModel, toggleTool, getToolsState, changeSystemPrompt, reloadSettings, switchSession)

        this.controller.SetSubControllers(ctxView, histView, settingsContr)
        this.view.SetSubControllers(ctxView, histView, settingsContr)

        settingsContr.SetViews(this.view.menuView, this.view.promptView)
        settingsContr.SetOnSessionChanged((*) => this.controller.UpdateSessionUI())
        settingsContr.SetOnSystemPromptChanged((*) => this.controller.RefreshOnSystemPromptChanged())

        ; 5. Initialize Tray
        this.trayView := TrayView(this.controller)
        this.controller.SetTrayView(this.trayView)
    }

    Start() {
        this.controller.Start()
        OnExit((*) => this.controller.SaveStateAndConversation())
        Hotkey("F6", (*) => this.controller.ToggleDisplay())
        Hotkey("F5", (*) => this.controller.ResetAll())
        Hotkey("F7", (*) => this.controller.AskToLLM())
    }
}
