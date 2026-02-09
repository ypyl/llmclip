#Requires AutoHotkey 2.0
#Include Services\Configuration\ConfigurationService.ahk
#Include Services\Base64Service.ahk
#Include Services\LLM\LLMService.ahk
#Include Services\SessionManager.ahk
#Include Services\ClipboardParserService.ahk
#Include Services\WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include Services\RecordingService.ahk
#Include Services\MessagePresentationService.ahk
#Include Services\ContextPresentationService.ahk
#Include ui\TrayView.ahk
#Include ui\UIConfig.ahk
#Include ui\UIBuilder.ahk
#Include ui\AppWindow.ahk
#Include Controllers\MainController.ahk
#Include Controllers\ContextViewController.ahk
#Include Controllers\HistoryViewController.ahk
#Include Controllers\MenuController.ahk
#Include Controllers\ChatController.ahk
#Include Controllers\ConversationController.ahk
#Include Controllers\ClipboardController.ahk
#Include Controllers\PromptController.ahk
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
#Include Controllers\NotesController.ahk
#Include Commands\SelectModelCommand.ahk
#Include Commands\GetToolsMenuStateCommand.ahk
#Include Commands\GetCompressionMenuStateCommand.ahk
#Include Commands\ToggleToolCommand.ahk
#Include Commands\InitializeAppCommand.ahk
#Include Commands\ProcessClipboardCommand.ahk
#Include Commands\SaveDiagramCommand.ahk
#Include Commands\ReplaceLinkWithContentCommand.ahk
#Include Commands\RenderMarkdownCommand.ahk
#Include Commands\RenderLastMessageCommand.ahk
#Include Commands\DeleteContextItemsCommand.ahk
#Include Commands\PrepareContextCommand.ahk
#Include Commands\GetHistoryListItemsCommand.ahk
#Include Commands\GetHistoryListItemsCommand.ahk
#Include Commands\GetMessagePresentationCommand.ahk
#Include Commands\UncheckImagesCommand.ahk
#Include Commands\SubmitPromptCommand.ahk


class App {
    controller := ""
    trayView := ""
    window := ""

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
        llm := LLMService(cfg)
        fs := FileService()
        cls := ClipboardService()
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
            fs
        )

        ; 2.5 Initialize View
        this.window := AppWindow(this.controller)
        this.controller.SetView(this.window)

        ; 3. Initialize Commands
        saveConv := SaveConversationCommand(sess, fs)
        loadConv := LoadConversationCommand(sess, fs)
        clearCtx := ClearContextCommand(sess)
        stopRec := StopRecordingCommand(rec, sess, ctx)
        startRec := StartRecordingCommand(rec)
        toggleRec := ToggleRecordingCommand(rec, sess, ctx)
        compress := CompressHistoryCommand(sess, cfg, llm)
        extract := ExtractLearningsCommand(sess, cfg, llm)
        resetAll := ResetAllCommand(sess)
        deleteMsg := DeleteMessageCommand(sess)
        clearHist := ClearHistoryCommand(sess, cfg)
        copyToClip := CopyToClipboardCommand(cls)
        selectModel := SelectModelCommand(sess)
        getToolsState := GetToolsMenuStateCommand(cfg, sess)
        getCompressionState := GetCompressionMenuStateCommand(cfg, sess)
        toggleTool := ToggleToolCommand(cfg, sess)
        initializeApp := InitializeAppCommand()
        processClip := ProcessClipboardCommand(rec, cp, sess)
        saveDiagram := SaveDiagramCommand(fs)
        replaceLink := ReplaceLinkWithContentCommand(wv, sess, ctx)
        renderMarkdown := RenderMarkdownCommand(wv)
        renderLastMsg := RenderLastMessageCommand(sess, mps, wv)
        deleteCtxItems := DeleteContextItemsCommand(sess)
        prepareContext := PrepareContextCommand(sess, cfg)
        getHistoryItems := GetHistoryListItemsCommand(sess, mps)
        getMessagePresentation := GetMessagePresentationCommand(sess, mps)
        uncheckImages := UncheckImagesCommand(sess)


        submitPrompt := SubmitPromptCommand(sess, cfg, llm, ctx, rec)

        this.controller.SetCommands(
            saveConv, loadConv, clearCtx, stopRec, startRec, compress, extract, resetAll, toggleRec, initializeApp, saveDiagram, renderMarkdown
        )

        ; 4. Initialize Sub-Controllers
        menuCtrl := MenuController(this.controller, this.window, cfg, sess, selectModel, getToolsState, getCompressionState, toggleTool)
        chatCtrl := ChatController(this.controller, this.window, submitPrompt, renderMarkdown, renderLastMsg, uncheckImages)
        conversationCtrl := ConversationController(this.controller, this.window, cfg, sess, llm, menuCtrl, saveConv, loadConv, compress, extract, resetAll)
        clipboardCtrl := ClipboardController(this.controller, processClip)

        ctxView := ContextViewController(this.controller, this.window, sess, ctx, wv, cps, clearCtx, replaceLink, renderMarkdown, deleteCtxItems, prepareContext)
        histView := HistoryViewController(this.controller, this.window, getHistoryItems, getMessagePresentation, deleteMsg, clearHist, renderMarkdown, copyToClip)
        notesContr := NotesController(copyToClip)
        promptCtrl := PromptController(this.window, chatCtrl)

        this.controller.SetSubControllers(menuCtrl, chatCtrl, conversationCtrl, clipboardCtrl, ctxView, histView, notesContr, promptCtrl)
        this.window.SetSubControllers(ctxView, histView, menuCtrl, conversationCtrl, chatCtrl)


        ; 5. Initialize Views
        this.trayView := TrayView(this.controller)
    }

    Start() {
        this.controller.Start()
        Hotkey("F3", (*) => this.controller.ToggleDisplay())
    }
}
