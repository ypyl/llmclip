#Requires AutoHotkey 2.0
#Include DI\ServiceContainer.ahk
#Include UIConfig.ahk
#Include UIBuilder.ahk
#Include LLM\TempFileManager.ahk

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
        container := ServiceContainer.GetInstance()
        
        ; Get core services from container
        this.configManager := container.Get("ConfigurationManager")
        this.SessionManagerValue := container.Get("SessionManager")
        this.ClipboardParserValue := container.Get("ClipboardParser")
        this.WebViewManagerValue := container.Get("WebViewManager")
        this.ContextManagerValue := container.Get("ContextManager")
        this.LLMServiceValue := container.Get("LLMService")
        
        ; Create TrayManager with callbacks
        this.TrayManagerValue := container.Get("TrayManagerFactory",
            ObjBindMethod(this, "DisplayLLMUserInterface"),
            ObjBindMethod(this, "UpdateUiBasesOnRecordingStatus"),
            ObjBindMethod(this, "ExitApplication")
        )
        
        ; Get view controllers
        this.ContextViewControllerValue := container.Get("ContextViewController")
        this.HistoryViewControllerValue := container.Get("HistoryViewController")
        
        ; Create managers that need app reference
        this.MenuManagerValue := container.Get("MenuManagerFactory", this)
        this.ChatManagerValue := container.Get("ChatManagerFactory", this)
        this.ConversationHandlerValue := container.Get("ConversationHandlerFactory", this)
        this.ClipboardManagerValue := container.Get("ClipboardManagerFactory", this)
        
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
