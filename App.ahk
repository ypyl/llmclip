#Requires AutoHotkey 2.0
#Include Services\Configuration\ConfigurationService.ahk
#Include Services\Base64.ahk
#Include Services\FileUtils.ahk
#Include Services\LLM\LLMService.ahk
#Include Services\SessionManager.ahk
#Include Services\ClipboardParser.ahk
#Include Services\WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include Services\RecordingService.ahk
#Include Services\MessagePresentationService.ahk
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
#Include Commands\SendToLLMCommand.ahk
#Include Commands\SendBatchToLLMCommand.ahk
#Include Commands\ConfirmToolCommand.ahk
#Include Commands\RegenerateMessageCommand.ahk
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



class App {
    controller := ""
    trayView := ""
    window := ""

    __New() {
        ; 1. Initialize Services
        cfg := ConfigurationService.GetInstance()
        sess := SessionManager(
            cfg.selectedLLMTypeIndex,
            cfg.GetSystemPromptValue(cfg.selectedLLMTypeIndex, 1)
        )
        cp := ClipboardParser()
        wv := WebViewManager()
        ctx := ContextManager()
        rec := RecordingService()
        llm := LLMService(cfg)
        fs := FileService()
        cls := ClipboardService()
        mps := MessagePresentationService()

        this.controller := MainController(
            cfg, 
            sess, 
            llm, 
            wv, 
            rec, 
            ctx, 
            cp
        )

        ; 2.5 Initialize View
        this.window := AppWindow(this.controller)
        this.controller.SetView(this.window)

        ; 3. Initialize Commands
        saveConv := SaveConversationCommand(sess, fs)
        loadConv := LoadConversationCommand(sess, fs)
        clearCtx := ClearContextCommand(sess)
        sendLLM := SendToLLMCommand(sess, cfg, llm)
        sendBatch := SendBatchToLLMCommand(sess, cfg, llm, ctx)
        confirmTool := ConfirmToolCommand(sess, llm, sendLLM)
        regenerate := RegenerateMessageCommand(sess, cfg)
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


        this.controller.SetCommands(
            saveConv, loadConv, clearCtx, sendLLM, sendBatch, confirmTool, regenerate, stopRec, startRec, compress, extract, resetAll, toggleRec, initializeApp, saveDiagram
        )

        ; 4. Initialize Sub-Controllers
        menuCtrl := MenuController(this.controller, this.window, cfg, sess, selectModel, getToolsState, getCompressionState, toggleTool)
        chatCtrl := ChatController(this.controller, this.window, cfg, sess, llm, ctx, mps, sendLLM, sendBatch, confirmTool, regenerate)
        conversationCtrl := ConversationController(this.controller, this.window, cfg, sess, llm, menuCtrl, saveConv, loadConv, compress, extract, resetAll)
        clipboardCtrl := ClipboardController(this.controller, processClip)

        
        ctxView := ContextViewController(this.controller, this.window, sess, cfg, ctx, wv, clearCtx)
        histView := HistoryViewController(this.controller, this.window, sess, wv, cfg, mps, deleteMsg, clearHist)
        notesContr := NotesController(copyToClip)
        promptCtrl := PromptController(this.window, chatCtrl)

        this.controller.SetSubControllers(menuCtrl, chatCtrl, conversationCtrl, clipboardCtrl, ctxView, histView, notesContr, promptCtrl)


        ; 5. Initialize Views
        this.trayView := TrayView(this.controller)
    }

    Start() {
        this.controller.Start()
        Hotkey("F3", (*) => this.controller.ToggleDisplay())
    }
}
