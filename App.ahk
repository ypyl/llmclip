#Requires AutoHotkey 2.0
#Include Settings\ConfigurationManager.ahk
#Include Services\Base64.ahk
#Include Services\FileUtils.ahk
#Include LLM\LLMService.ahk
#Include Services\SessionManager.ahk
#Include Services\ClipboardParser.ahk
#Include Services\WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include Services\RecordingService.ahk
#Include ui\TrayView.ahk
#Include ui\UIConfig.ahk
#Include ui\UIBuilder.ahk
#Include ui\AppWindow.ahk
#Include Controllers\MainController.ahk
#Include Controllers\ContextViewController.ahk
#Include Controllers\HistoryViewController.ahk
#Include Controllers\MenuManager.ahk
#Include Controllers\ChatManager.ahk
#Include Controllers\ConversationHandler.ahk
#Include Controllers\ClipboardManager.ahk
#Include Services\FileService.ahk
#Include Commands\SaveConversationCommand.ahk
#Include Commands\LoadConversationCommand.ahk
#Include Commands\ClearContextCommand.ahk
#Include Commands\SendToLLMCommand.ahk
#Include Commands\SendBatchToLLMCommand.ahk
#Include Commands\ConfirmToolCommand.ahk
#Include Commands\RegenerateMessageCommand.ahk
#Include Commands\StopRecordingCommand.ahk
#Include Commands\DeleteMessageCommand.ahk
#Include Commands\ClearHistoryCommand.ahk
#Include Commands\CompressHistoryCommand.ahk
#Include Commands\ExtractLearningsCommand.ahk
#Include Commands\ResetAllCommand.ahk

class App {
    controller := ""
    trayView := ""
    window := ""

    __New() {
        ; 1. Initialize Services
        cfg := ConfigurationManager.GetInstance()
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

        ; 2. Initialize Main Controller
        this.controller := MainController(
            cfg, 
            sess, 
            llm, 
            wv, 
            rec, 
            ctx, 
            cp
        )

        ; 3. Initialize Commands
        saveConv := SaveConversationCommand(sess, fs)
        loadConv := LoadConversationCommand(sess, fs)
        clearCtx := ClearContextCommand(sess)
        sendLLM := SendToLLMCommand(sess, cfg, llm)
        sendBatch := SendBatchToLLMCommand(sess, cfg, llm, ctx)
        confirmTool := ConfirmToolCommand(sess, llm, sendLLM)
        regenerate := RegenerateMessageCommand(sess, cfg)
        stopRec := StopRecordingCommand(rec, sess, ctx)
        compress := CompressHistoryCommand(sess, cfg, llm)
        extract := ExtractLearningsCommand(sess, cfg, llm)
        resetAll := ResetAllCommand(sess)
        deleteMsg := DeleteMessageCommand(sess)
        clearHist := ClearHistoryCommand(sess, cfg)

        this.controller.SetCommands(
            saveConv, loadConv, clearCtx, sendLLM, sendBatch, confirmTool, regenerate, stopRec, compress, extract, resetAll
        )

        ; 4. Initialize Sub-Controllers
        menuMan := MenuManager(this.controller, cfg, sess)
        chatMan := ChatManager(this.controller, cfg, sess, llm, ctx, sendLLM, sendBatch, confirmTool, regenerate)
        convHandler := ConversationHandler(this.controller, cfg, sess, llm, menuMan, saveConv, loadConv, compress, extract, resetAll)
        clipMan := ClipboardManager(this.controller, sess, ctx)
        
        ctxView := ContextViewController(this.controller, sess, cfg, ctx, wv, clearCtx)
        histView := HistoryViewController(this.controller, sess, wv, cfg, deleteMsg, clearHist)

        this.controller.SetSubControllers(menuMan, chatMan, convHandler, clipMan, ctxView, histView)

        ; 5. Initialize Views
        this.trayView := TrayView(this.controller)
        this.window := AppWindow(this.controller)
        this.controller.SetView(this.window)
    }

    Start() {
        this.controller.Start()
    }

    ToggleDisplay() {
        this.controller.ToggleDisplay()
    }
}
