#Requires AutoHotkey 2.0
#Include UIBuilder.ahk

class AppWindow {
    gui := ""
    controller := ""
    guiShown := false
    
    ; Menu references
    menuBar := ""
    modelMenu := ""
    historyMenu := ""
    toolsMenu := ""
    modeMenu := ""
    
    ; Control references
    askButton := ""
    
    __New(controller) {
        this.controller := controller
    }

    Show() {
        if (this.guiShown) {
            this.gui.Show()
            return
        }
        
        this.BuildUI()
        this.gui.Show("w1230 h610")
        
        this.guiShown := true
        
        ; Notify controller that view is ready
        this.controller.OnViewReady()
    }
    
    BuildUI() {
        this.gui := Gui()
        this.gui.Title := "LLM Assistant"
        this.gui.SetFont("s9", "Segoe UI")
        this.gui.Opt("+Resize +MinSize800x610")
        
        this.gui.OnEvent("Size", (gui, minMax, width, height) => UIBuilder.GuiResize(gui, minMax, width, height, this.controller))
        this.gui.OnEvent("Close", ObjBindMethod(this, "GuiClose"))
        
        ; Set GUI for VCs
        this.controller.contextViewController.SetGui(this.gui)
        
        ; Create Menus
        menus := UIBuilder.CreateMenuBar(this.gui, this.controller, this.controller.configManager, this.controller.sessionManager, this.controller.menuController, this.controller.conversationController, this.controller.chatController)
        this.menuBar := menus.menuBar
        this.modelMenu := menus.modelMenu
        this.historyMenu := menus.historyMenu
        this.toolsMenu := menus.toolsMenu
        this.modeMenu := menus.modeMenu
        
        ; Initial menu states
        this.controller.menuController.UpdateCompressionMenuState()
        this.controller.menuController.UpdateToolsMenuState()
        
        ; Create Controls
        UIBuilder.CreateTopControls(this.gui, this.controller.sessionManager, this.controller.recordingService, this.controller, this.controller.conversationController)
        UIBuilder.CreateContextSection(this.gui, this.controller.contextViewController)
        UIBuilder.CreateChatHistorySection(this.gui, this.controller.historyViewController)
        UIBuilder.CreatePromptSection(this.gui, this.controller.sessionManager, this.controller.configManager, this)
        
        this.askButton := UIBuilder.CreateBottomControls(this.gui, this.controller.sessionManager, this.controller.configManager, this.controller)
        
        UIBuilder.CreateResponseArea(this.gui)
    }
    
    GuiClose(*) {
        this.gui.Destroy()
        this.guiShown := false
    }
    
    UpdateRecordButton(isRecording) {
        if (this.guiShown) {
            try {
                this.gui["RecordButton"].Text := isRecording ? "Stop" : "Record"
            }
        }
    }
    
    GetPromptValue() {
        return this.gui["PromptEdit"].Value
    }

    SetPromptValue(text) {
        this.gui["PromptEdit"].Value := text
    }

    OnPromptChange(GuiCtrl, Info) {
        this.controller.OnPromptInput()
    }

    ClearPrompt() {
        this.gui["PromptEdit"].Value := ""
    }

    SetAskButtonText(text) {
        this.gui["AskLLM"].Text := text
    }

    SetAskButtonEnabled(enabled) {
        this.askButton.Enabled := enabled
    }

    GetSelectedHistoryIndex() {
        return this.gui["ChatHistory"].GetNext()
    }

    DeselectHistoryItem(index) {
        this.gui["ChatHistory"].Modify(index, "-Select")
    }

    UpdateBatchModeMenu(enabled) {
        if (enabled) {
            this.modeMenu.Check("Batch Mode")
        } else {
            this.modeMenu.Uncheck("Batch Mode")
        }
    }

    GetAskButtonText() {
        return this.gui["AskLLM"].Text
    }

    SetSystemPromptValue(value) {
        this.gui["SystemPrompt"].Value := value
    }

    GetSystemPromptValue() {
        return this.gui["SystemPrompt"].Value
    }

    SetSessionSelectValue(value) {
        this.gui["SessionSelect"].Value := value
    }

    GetSessionSelectValue() {
        return this.gui["SessionSelect"].Value
    }

    GetContextBoxValue() {
        return this.gui["ContextBox"].Value
    }

    GetContextBoxNext(row) {
        return this.gui["ContextBox"].GetNext(row)
    }

    DeleteContextBoxItems() {
        this.gui["ContextBox"].Delete()
    }

    AddContextBoxItem(label) {
        return this.gui["ContextBox"].Add("Check", label)
    }

    ModifyContextBox(row, options) {
        this.gui["ContextBox"].Modify(row, options)
    }

    GetContextBoxCount() {
        return this.gui["ContextBox"].GetCount()
    }

    ModifyContextBoxCol(column, width) {
        this.gui["ContextBox"].ModifyCol(column, width)
    }

    GetContextBoxHwnd() {
        return this.gui["ContextBox"].Hwnd
    }

    DeleteChatHistoryItems() {
        this.gui["ChatHistory"].Delete()
    }

    AddChatHistoryItem(role, text, duration, tokens) {
        return this.gui["ChatHistory"].Add(, role, text, duration, tokens)
    }

    ModifyChatHistory(row, options, text := "") {
        this.gui["ChatHistory"].Modify(row, options, text)
    }

    GetChatHistoryCount() {
        return this.gui["ChatHistory"].GetCount()
    }

    GetChatHistorySelectedIndices() {
        selectedIndices := []
        row := 0
        while (row := this.gui["ChatHistory"].GetNext(row)) {
            selectedIndices.InsertAt(1, row) ; Reverse order for safe deletion
        }
        return selectedIndices
    }

    GetChatHistoryFocus() {
        return this.gui["ChatHistory"].GetNext()
    }

    ScrollChatHistoryToBottom() {
        this.gui["ChatHistory"].Modify(this.gui["ChatHistory"].GetCount(), "Vis")
    }

    SetChatMessageActionButtonVisible(visible) {
        this.gui["ChatMessageActionButton"].Visible := visible
    }

    ClearSystemPrompt() {
        this.gui["SystemPrompt"].Delete()
    }

    AddSystemPromptItems(items) {
        this.gui["SystemPrompt"].Add(items)
    }

    SetSystemPromptEnabled(enabled) {
        this.gui["SystemPrompt"].Enabled := enabled
    }

    IsContextItemChecked(index) {
        if (!this.guiShown)
            return true ; Default to true if GUI not available

        try {
            Result := SendMessage(0x102C, index-1, 0xF000, this.GetContextBoxHwnd()) ; LVM_GETITEMSTATE
            State := (Result >> 12) - 1
            return State == 1
        } catch {
            return true ; Fallback
        }
    }

    ShowSaveFileDialog(defaultFilename, title, filter) {
        return FileSelect("S16", defaultFilename, title, filter)
    }
}
