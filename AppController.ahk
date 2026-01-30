#Requires AutoHotkey 2.0
#Include Settings\ConfigurationManager.ahk
#Include LLM\LLMService.ahk
#Include ClipboardParser.ahk
#Include WebViewManager.ahk
#Include Services\ContextManager.ahk
#Include TrayManager.ahk
#Include ui\UIConfig.ahk
#Include ui\UIBuilder.ahk
#Include ui\AppWindow.ahk
#Include ContextViewController.ahk
#Include HistoryViewController.ahk
#Include Controllers\MenuManager.ahk
#Include Controllers\ChatManager.ahk
#Include Controllers\ConversationHandler.ahk
#Include Controllers\ClipboardManager.ahk
#Include Services\FileService.ahk
#Include Commands\SaveConversationCommand.ahk
#Include Commands\LoadConversationCommand.ahk

class AppController {
    view := ""
    currentAnswerSize := "Default"
    currentModelName := ""
    
    configManager := ""
    SessionManagerValue := ""
    ClipboardParserValue := ""
    WebViewManagerValue := ""
    ContextManagerValue := ""
    TrayManagerValue := ""
    LLMServiceValue := ""

    ContextViewControllerValue := ""
    HistoryViewControllerValue := ""
    
    MenuManagerValue := ""
    ChatManagerValue := ""
    ConversationHandlerValue := ""
    ClipboardManagerValue := ""

    FileServiceValue := ""
    SaveConversationCommandValue := ""
    LoadConversationCommandValue := ""
    
    batchModeEnabled := false  ; Track batch mode state

    __New() {
        ; Create configuration manager instance
        this.configManager := ConfigurationManager.GetInstance()

        ; Create session manager instance with default values from ConfigurationManager
        this.SessionManagerValue := SessionManager(
            this.configManager.selectedLLMTypeIndex,
            this.configManager.GetSystemPromptValue(this.configManager.selectedLLMTypeIndex, 1)
        )

        ; Create clipboard parser instance
        this.ClipboardParserValue := ClipboardParser()

        ; Create WebView manager instance
        this.WebViewManagerValue := WebViewManager()

        this.ContextManagerValue := ContextManager()

        ; Create TrayManager instance
        this.TrayManagerValue := TrayManager(ObjBindMethod(this, "Show"), ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"), ObjBindMethod(this,
            "ExitApplication"), this.ContextManagerValue)

        this.ContextViewControllerValue := ContextViewController(this.SessionManagerValue, this.configManager, this.ContextManagerValue, this.WebViewManagerValue)
        this.HistoryViewControllerValue := HistoryViewController(this.SessionManagerValue, this.WebViewManagerValue, this.configManager)

        this.LLMServiceValue := LLMService(this.configManager)
        
        ; Create specialized managers
        this.MenuManagerValue := MenuManager(this, this.configManager, this.SessionManagerValue)
        this.ChatManagerValue := ChatManager(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.ContextManagerValue)
        
        ; Initialize Services and Commands
        this.FileServiceValue := FileService()
        this.SaveConversationCommandValue := SaveConversationCommand(this.SessionManagerValue, this.FileServiceValue)
        this.LoadConversationCommandValue := LoadConversationCommand(this.SessionManagerValue, this.FileServiceValue)

        this.ConversationHandlerValue := ConversationHandler(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.MenuManagerValue, this.SaveConversationCommandValue, this.LoadConversationCommandValue)
        this.ClipboardManagerValue := ClipboardManager(this, this.SessionManagerValue, this.ContextManagerValue)

        this.batchModeEnabled := false

        ; Initialize View
        this.view := AppWindow(this)
    }

    Start() {
        TempFileManager.CleanUp()
        this.Show()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.TrayManagerValue.isRecording) {
            this.TrayManagerValue.StartRecording()
        } else if (!this.view.guiShown) {
            this.Show()
        } else {
            this.TrayManagerValue.StopRecording(this.SessionManagerValue)
        }
    }

    RenderMarkdown(content) {
        this.WebViewManagerValue.RenderMarkdown(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.view.guiShown) {
             this.view.UpdateRecordButton(this.TrayManagerValue.isRecording)
        }
    }

    Show(*) {
        this.view.Show()
    }

    SystemPromptChanged(*) => this.ConversationHandlerValue.SystemPromptChanged()
    
    HandleToolConfirmation() => this.ChatManagerValue.HandleToolConfirmation()
    HandleCancellation() => this.ChatManagerValue.HandleCancellation()
    HandleRegenerationOrEdit(promptText) => this.ChatManagerValue.HandleRegenerationOrEdit(promptText)
    AskToLLM(*) => this.ChatManagerValue.AskToLLM()
    SendBatchToLLM(promptText) => this.ChatManagerValue.SendBatchToLLM(promptText)
    SendToLLM() => this.ChatManagerValue.SendToLLM()
    
    ExitApplication(*) => ExitApp()
    ClipChanged(DataType) => this.ClipboardManagerValue.ClipChanged(DataType)

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

    ClearAllContext(*) {
        this.SessionManagerValue.SetCurrentSessionContext([])
        this.ContextViewControllerValue.UpdateContextView()
    }
}
