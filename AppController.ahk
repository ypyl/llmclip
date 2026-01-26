#Requires AutoHotkey 2.0
#Include Settings\ConfigurationManager.ahk
#Include LLM\LLMService.ahk
#Include ClipboardParser.ahk
#Include WebViewManager.ahk
#Include ContextManager.ahk
#Include TrayManager.ahk
#Include UIConfig.ahk
#Include UIBuilder.ahk
#Include LLM\Types.ahk
#Include ContextViewController.ahk
#Include HistoryViewController.ahk
#Include PdfProcessor.ahk
#Include LLM\TempFileManager.ahk
#Include Controllers\MenuManager.ahk
#Include Controllers\ChatManager.ahk
#Include Controllers\ConversationHandler.ahk
#Include Controllers\ClipboardManager.ahk

class AppController {
    askButton := ""
    MyGui := ""
    guiShown := false
    ModelMenu := ""  ; Store reference to Model menu
    HistoryMenu := ""  ; Store reference to History menu
    ToolsMenu := "" ; Store reference to Tools menu
    ModeMenu := "" ; Store reference to Mode menu
    MyMenuBar := ""  ; Store reference to MenuBar
    currentAnswerSize := "Default"  ; Track current answer size (Small, Default, Long)
    currentModelName := ""  ; Track current model name for MenuBar updates

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
        this.TrayManagerValue := TrayManager(ObjBindMethod(this, "DisplayLLMUserInterface"), ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"), ObjBindMethod(this,
            "ExitApplication"), this.ContextManagerValue)

        this.ContextViewControllerValue := ContextViewController(this.SessionManagerValue, this.configManager, this.ContextManagerValue, this.WebViewManagerValue)
        this.HistoryViewControllerValue := HistoryViewController(this.SessionManagerValue, this.WebViewManagerValue, this.configManager)

        this.LLMServiceValue := LLMService(this.configManager)
        
        ; Create specialized managers
        this.MenuManagerValue := MenuManager(this, this.configManager, this.SessionManagerValue)
        this.ChatManagerValue := ChatManager(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.ContextManagerValue)
        this.ConversationHandlerValue := ConversationHandler(this, this.configManager, this.SessionManagerValue, this.LLMServiceValue, this.MenuManagerValue)
        this.ClipboardManagerValue := ClipboardManager(this, this.SessionManagerValue, this.ContextManagerValue)

        this.batchModeEnabled := false
    }

    Start() {
        TempFileManager.CleanUp()
        this.DisplayLLMUserInterface()
        OnClipboardChange ObjBindMethod(this, "ClipChanged")
    }

    ToggleDisplay() {
        if (!this.TrayManagerValue.isRecording) {
            this.TrayManagerValue.StartRecording()
        } else if (!this.guiShown) {
            this.DisplayLLMUserInterface()
        } else {
            this.TrayManagerValue.StopRecording(this.SessionManagerValue)
        }
    }

    RenderMarkdown(content) {
        this.WebViewManagerValue.RenderMarkdown(content)
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.guiShown) {
            if (this.TrayManagerValue.isRecording) {
                this.MyGui["Record"].Text := "Stop"
            } else {
                this.MyGui["Stop"].Text := "Record"
            }
        }
    }

    DisplayLLMUserInterface(*) {
        if (this.guiShown) {
            this.MyGui.Show()
            return
        }
        this.MyGui := Gui()
        this.MyGui.Title := "LLM Assistant"
        this.MyGui.SetFont("s9", "Segoe UI")
        this.MyGui.Opt("+Resize +MinSize800x610")  ; Only main window gets resize option

        this.MyGui.OnEvent("Size", (gui, minMax, width, height) => UIBuilder.GuiResize(gui, minMax, width, height, this))
        this.MyGui.OnEvent("Close", ObjBindMethod(this, "GuiClose"))

        this.ContextViewControllerValue.SetGui(this.MyGui)
        this.HistoryViewControllerValue.SetGui(this.MyGui)

        menus := UIBuilder.CreateMenuBar(this.MyGui, this, this.configManager, this.SessionManagerValue)
        this.MyMenuBar := menus.menuBar
        this.ModelMenu := menus.modelMenu
        this.HistoryMenu := menus.historyMenu
        this.ToolsMenu := menus.toolsMenu
        this.ModeMenu := menus.modeMenu

        this.UpdateCompressionMenuState()
        this.UpdateToolsMenuState()

        this.UpdateCompressionMenuState()

        ; Initialize current model name
        currentModelIndex := this.SessionManagerValue.GetCurrentSessionLLMType()
        this.currentModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]

        UIBuilder.CreateTopControls(this.MyGui, this.SessionManagerValue, this.TrayManagerValue, this)

        UIBuilder.CreateContextSection(this.MyGui, this.ContextViewControllerValue)

        UIBuilder.CreateChatHistorySection(this.MyGui, this.HistoryViewControllerValue)

        UIBuilder.CreatePromptSection(this.MyGui, this.SessionManagerValue, this.configManager, this)

        this.askButton := UIBuilder.CreateBottomControls(this.MyGui, this.SessionManagerValue, this.configManager, this)

        responseCtr := UIBuilder.CreateResponseArea(this.MyGui)

        this.MyGui.Show("w1230 h610")

        this.WebViewManagerValue.Init(responseCtr)
        this.WebViewManagerValue.SetInputCallback(ObjBindMethod(this, "AppendToPrompt"))

        this.guiShown := true

        this.HistoryViewControllerValue.UpdateChatHistoryView()
    }

    SystemPromptChanged(*) => this.ConversationHandlerValue.SystemPromptChanged()
    SelectModel(ItemName, ItemPos, MyMenu) => this.MenuManagerValue.SelectModel(ItemName, ItemPos, MyMenu)
    SelectAnswerSize(ItemName, ItemPos, MyMenu) => this.MenuManagerValue.SelectAnswerSize(ItemName, ItemPos, MyMenu)
    ToggleBatchMode(*) => this.ChatManagerValue.ToggleBatchMode()
    SessionChanged(*) => this.ConversationHandlerValue.SessionChanged()
    HandleToolConfirmation() => this.ChatManagerValue.HandleToolConfirmation()
    HandleCancellation() => this.ChatManagerValue.HandleCancellation()
    HandleRegenerationOrEdit(promptText) => this.ChatManagerValue.HandleRegenerationOrEdit(promptText)
    AskToLLM(*) => this.ChatManagerValue.AskToLLM()
    SendBatchToLLM(promptText) => this.ChatManagerValue.SendBatchToLLM(promptText)
    SendToLLM() => this.ChatManagerValue.SendToLLM()
    ResetAll(*) => this.ConversationHandlerValue.ResetAll()
    CompressHistory(*) => this.ConversationHandlerValue.CompressHistory()
    ExtractLearnings(*) => this.ConversationHandlerValue.ExtractLearnings()
    ExitApplication(*) => ExitApp()
    ClipChanged(DataType) => this.ClipboardManagerValue.ClipChanged(DataType)
    SaveConversation(*) => this.ConversationHandlerValue.SaveConversation()
    LoadConversation(*) => this.ConversationHandlerValue.LoadConversation()
    ReloadSettings(*) => this.ConversationHandlerValue.ReloadSettings()
    UpdateCompressionMenuState() => this.MenuManagerValue.UpdateCompressionMenuState()
    UpdateToolsMenuState() => this.MenuManagerValue.UpdateToolsMenuState()
    ToggleTool(toolName, *) => this.MenuManagerValue.ToggleTool(toolName)

    GuiClose(*) {
        this.MyGui.Destroy()
        this.guiShown := false
    }

    AppendToPrompt(text) {
        currentText := this.MyGui["PromptEdit"].Value
        if (currentText != "") {
            currentText .= "`n"
        }
        this.MyGui["PromptEdit"].Value := currentText . "> " . text . "`n"
    }

    PromptChange(GuiCtrl, Info) {
        if (GetKeyState("Enter") && !GetKeyState("Shift")) {
            ; Get the last character
            text := GuiCtrl.Value
            if (SubStr(text, -1) == "`n") {
                ; Remove the trailing newline
                GuiCtrl.Value := SubStr(text, 1, -1)
                ; Send the prompt
                this.AskToLLM()
                return true
            }
        }
    }
    
    ToggleRecording(*) {
        this.ToggleDisplay()
    }

    ClearAllContext(*) {
        this.SessionManagerValue.SetCurrentSessionContext([])
        this.ContextViewControllerValue.UpdateContextView()
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }

    CheckContentInMessages(messages, newContent) {
        for msg in messages {
            if (InStr(msg.GetText(), newContent))
                return true
        }
        return false
    }

    HasContent(haystack, newContent) {
        if (newContent = "")
            return true

        ; First check exact matches
        if (this.HasVal(haystack, newContent))
            return true

        ; Also check in chat history
        if (this.CheckContentInMessages(this.SessionManagerValue.GetCurrentSessionMessages(), newContent))
            return true

        return false
    }
}
