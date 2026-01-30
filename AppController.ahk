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

class AppController {
    view := ""
    currentAnswerSize := "Default"
    currentModelName := ""
    
    configManager := ""
    SessionManagerValue := ""
    ClipboardParserValue := ""
    WebViewManagerValue := ""
    ContextManagerValue := ""
    RecordingServiceValue := ""
    TrayViewValue := ""
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
    ClearContextCommandValue := ""
    SendToLLMCommandValue := ""
    SendBatchToLLMCommandValue := ""
    ConfirmToolCommandValue := ""
    RegenerateMessageCommandValue := ""
    StopRecordingCommandValue := ""
    
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

        this.WebViewManagerValue := WebViewManager()
        this.ContextManagerValue := ContextManager()
        this.RecordingServiceValue := RecordingService()

        ; Create TrayView instance
        this.TrayViewValue := TrayView(this)

        this.LLMServiceValue := LLMService(this.configManager)
        
        ; Create specialized managers
        ; Create specialized managers
        this.MenuManagerValue := MenuManager(this, this.configManager, this.SessionManagerValue)
        
        ; Initialize Services and Commands
        this.FileServiceValue := FileService()
        this.SaveConversationCommandValue := SaveConversationCommand(this.SessionManagerValue, this.FileServiceValue)
        this.LoadConversationCommandValue := LoadConversationCommand(this.SessionManagerValue, this.FileServiceValue)
        this.ClearContextCommandValue := ClearContextCommand(this.SessionManagerValue)
        
        this.SendToLLMCommandValue := SendToLLMCommand(this.SessionManagerValue, this.configManager, this.LLMServiceValue, this.currentAnswerSize)
        this.SendBatchToLLMCommandValue := SendBatchToLLMCommand(this.SessionManagerValue, this.configManager, this.LLMServiceValue, this.ContextManagerValue, this.currentAnswerSize)
        this.ConfirmToolCommandValue := ConfirmToolCommand(this.SessionManagerValue, this.LLMServiceValue, this.SendToLLMCommandValue)
        this.RegenerateMessageCommandValue := RegenerateMessageCommand(this.SessionManagerValue, this.configManager)
        this.StopRecordingCommandValue := StopRecordingCommand(this.RecordingServiceValue, this.SessionManagerValue, this.ContextManagerValue)

        this.ChatManagerValue := ChatManager(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.ContextManagerValue, this.SendToLLMCommandValue, this.SendBatchToLLMCommandValue, this.ConfirmToolCommandValue, this.RegenerateMessageCommandValue)

        this.ConversationHandlerValue := ConversationHandler(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.MenuManagerValue, this.SaveConversationCommandValue, this.LoadConversationCommandValue)
        this.ClipboardManagerValue := ClipboardManager(this, this.SessionManagerValue, this.ContextManagerValue)

        this.ContextViewControllerValue := ContextViewController(this.SessionManagerValue, this.configManager, this.ContextManagerValue, this.WebViewManagerValue, this.ClearContextCommandValue)
        this.HistoryViewControllerValue := HistoryViewController(this.SessionManagerValue, this.WebViewManagerValue, this.configManager)

        this.batchModeEnabled := false

        ; Initialize View
        this.view := AppWindow(this)
    }

    Start() {
        TempFileManager.CleanUp()
        this.Show()
        this.UpdateUiBasesOnRecordingStatus()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.RecordingServiceValue.isRecording) {
            this.RecordingServiceValue.StartRecording()
            this.UpdateUiBasesOnRecordingStatus()
        } else if (!this.view.guiShown) {
            this.Show()
        } else {
            this.StopRecordingCommandValue.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        }
    }

    RenderMarkdown(content) {
        this.WebViewManagerValue.RenderMarkdown(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        this.TrayViewValue.UpdateStatus(this.RecordingServiceValue.isRecording)
        if (this.view.guiShown) {
             this.view.UpdateRecordButton(this.RecordingServiceValue.isRecording)
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

    ; Tray Event Handlers
    OnStartRecording() {
        this.RecordingServiceValue.StartRecording()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnStopRecording() {
        this.StopRecordingCommandValue.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnToggleRecording() {
        this.RecordingServiceValue.ToggleRecording(this.SessionManagerValue, this.ContextManagerValue)
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnDisplayLLM() => this.Show()
    OnExit() => this.ExitApplication()

    ClearAllContext(*) {
        this.ClearContextCommandValue.Execute()
        this.ContextViewControllerValue.UpdateContextView()
    }
}
