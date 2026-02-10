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
    
    ; Sub-Controllers
    contextViewController := ""
    historyViewController := ""
    
    __New(controller) {
        this.controller := controller
    }

    SetSubControllers(contextViewController, historyViewController) {
        this.contextViewController := contextViewController
        this.historyViewController := historyViewController
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
        
        ; Create Menus
        menus := UIBuilder.CreateMenuBar(
            this.gui, 
            this.controller, 
            this.controller.LLMTypes, 
            this.controller.CurrentLLMTypeIndex
        )
        this.menuBar := menus.menuBar
        this.modelMenu := menus.modelMenu
        this.historyMenu := menus.historyMenu
        this.toolsMenu := menus.toolsMenu
        this.modeMenu := menus.modeMenu
        
        ; Initial menu states
        this.controller.UpdateCompressionMenuState()
        this.controller.UpdateToolsMenuState()
        
        ; Create Controls
        UIBuilder.CreateTopControls(
            this.gui, 
            this.controller.SessionNames, 
            this.controller.CurrentSessionIndex, 
            this.controller.IsRecording, 
            this.controller
        )
        UIBuilder.CreateContextSection(this.gui, this.contextViewController)
        UIBuilder.CreateChatHistorySection(this.gui, this.historyViewController)
        UIBuilder.CreatePromptSection(this.gui, this)
        
        this.askButton := UIBuilder.CreateBottomControls(
            this.gui, 
            this.controller.GetSystemPrompts(this.controller.CurrentLLMTypeIndex), 
            this.controller.CurrentSystemPromptIndex, 
            this.controller
        )
        
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

    OnContextItemCheck(GuiCtrl, Item) {
        checked := this.IsContextItemChecked(Item)
        this.contextViewController.ContextBoxItemCheck(Item, checked)
    }

    OnContextBoxNotify(GuiCtrl, lParam) {
        ; LVN_ITEMCHANGED = -101
        ; iItem is at offset 3 * A_PtrSize
        ; uNewState is at offset 3 * A_PtrSize + 8
        ; uOldState is at offset 3 * A_PtrSize + 12
        
        iItem := NumGet(lParam, 3 * A_PtrSize, "Int") + 1
        uNewState := NumGet(lParam, 3 * A_PtrSize + 8, "UInt")
        uOldState := NumGet(lParam, 3 * A_PtrSize + 12, "UInt")
        
        ; LVIS_STATEIMAGEMASK = 0xF000
        if ((uNewState & 0xF000) != (uOldState & 0xF000)) {
            this.OnContextItemCheck(GuiCtrl, iItem)
        }
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

    AddContextBoxItem(label, checkedOption := "Check") {
        return this.gui["ContextBox"].Add(checkedOption, label)
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

    ModifyChatHistory(row, options, text?) {
        if (IsSet(text)) {
            this.gui["ChatHistory"].Modify(row, options, text)
        } else {
            this.gui["ChatHistory"].Modify(row, options)
        }
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

    RemoveContextBoxCheckbox(row) {
        hwnd := this.GetContextBoxHwnd()
        ; Remove state image (checkbox) by setting state image index to 0
        ; LVM_SETITEMSTATE = 0x102B
        LVITEM := Buffer(60, 0)
        NumPut("UInt", 0x8, LVITEM, 0)      ; mask = LVIF_STATE (0x0008)
        NumPut("Int", row - 1, LVITEM, 4)   ; iItem (0-based)
        NumPut("Int", 0, LVITEM, 8)         ; iSubItem
        NumPut("UInt", 0, LVITEM, 12)       ; state (0 = no image)
        NumPut("UInt", 0xF000, LVITEM, 16)  ; stateMask = LVIS_STATEIMAGEMASK (0xF000)

        SendMessage(0x102B, row - 1, LVITEM.Ptr, hwnd)
    }

    ShowSaveFileDialog(defaultFilename, title, filter) {
        return FileSelect("S16", defaultFilename, title, filter)
    }

    ShowMessage(text, title := "Information", options := "Iconi") {
        MsgBox(text, title, options)
    }

    ShowError(text, title := "Error") {
        MsgBox(text, title, "Iconx")
    }

    GetResponseCtrHwnd() {
        return this.gui["ResponseCtr"].Hwnd
    }
}
