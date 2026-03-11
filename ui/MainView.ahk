#Include MenuView.ahk
#Include TopControlsView.ahk
#Include ContextView.ahk
#Include HistoryView.ahk
#Include PromptView.ahk
#Include ResponseView.ahk

class MainView {
    gui := ""
    controller := ""
    guiShown := false

    ; Component references
    menuView := ""
    topControlsView := ""
    contextView := ""
    historyView := ""
    promptView := ""
    responseView := ""

    ; Sub-Controllers
    contextViewController := ""
    historyViewController := ""
    settingsController := ""
    recordingController := ""

    ; Property proxies for backward compatibility
    modelMenu => this.menuView.modelMenu
    menuBar => this.menuView.menuBar
    toolsMenu => this.menuView.toolsMenu
    historyMenu => this.menuView.historyMenu

    __New(controller) {
        this.controller := controller
        this.menuView := MenuView()
        this.topControlsView := TopControlsView()
        this.contextView := ContextView()
        this.historyView := HistoryView()
        this.promptView := PromptView()
        this.responseView := ResponseView()
    }

    SetSubControllers(contextViewController, historyViewController, settingsController, recordingController) {
        this.contextViewController := contextViewController
        this.historyViewController := historyViewController
        this.settingsController := settingsController
        this.recordingController := recordingController
    }

    Show() {
        if (this.guiShown) {
            this.gui.Show()
            return
        }

        this.BuildUI()
        this.gui.Show("w1230 h610")
        this.guiShown := true
        this.controller.OnViewReady()
    }

    BuildUI() {
        this.gui := Gui()
        this.gui.Title := "LLM Assistant"
        this.gui.SetFont("s9", "Segoe UI")
        this.gui.Opt("+Resize +MinSize800x610")

        this.gui.OnEvent("Size", (gui, minMax, width, height) => this.OnResize(gui, minMax, width, height))

        ; Create Controls via components
        this.menuView.Create(
            this.gui,
            this.controller,
            this.settingsController,
            this.controller.LLMDisplayNames,
            this.controller.CurrentLLMTypeIndex
        )

        this.topControlsView.Create(
            this.gui,
            this.controller.SessionNames,
            this.controller.CurrentSessionIndex,
            this.controller.IsRecording,
            this.controller,
            this.recordingController
        )

        this.contextView.Create(this.gui, this.contextViewController)
        this.historyView.Create(this.gui, this.historyViewController)
        
        this.promptView.Create(
            this.gui, 
            this, 
            this.controller.GetSystemPrompts(this.controller.CurrentLLMTypeIndex),
            this.controller.CurrentSystemPromptIndex,
            this.settingsController,
            this.controller
        )

        this.responseView.Create(this.gui)

        ; Initial menu states
        this.settingsController.UpdateCompressionMenuState()
        this.settingsController.UpdateToolsMenuState()
    }

    OnResize(thisGui, MinMax, Width, Height) {
        if (MinMax = -1)
            return

        this.responseView.Resize(Width, Height, this.controller.webViewManager, this.guiShown)
        this.promptView.Move(Width, Height)
    }

    OnPromptChange(GuiCtrl, Info) {
        this.controller.OnPromptInput()
    }

    ; Proxies for controllers that still expect MainView methods
    DeleteChatHistoryItems() => this.historyView.DeleteItems()
    AddChatHistoryItem(role, text, duration, tokens) => this.historyView.AddItem(role, text, duration, tokens)
    SelectHistoryItem(index) => this.historyView.Modify(index, "Select")
    DeselectHistoryItem(index) => this.historyView.Modify(index, "-Select")
    SetChatMessageActionButtonVisible(visible) => this.historyView.SetActionButtonVisible(visible)
    GetChatHistoryCount() => this.historyView.GetCount()
    ScrollChatHistoryToBottom() => this.historyView.ScrollToBottom()
    GetChatHistoryFocus() => this.historyView.GetNext()
    GetSelectedHistoryIndex() => this.historyView.GetNext()
    GetChatHistorySelectedIndices() => this.historyView.GetSelectedIndices()
    ModifyChatHistory(row, options, text?) => this.historyView.Modify(row, options, text?)
    
    DeleteContextBoxItems() => this.contextView.DeleteItems()
    AddContextBoxItem(label, options) => this.contextView.AddItem(label, options)
    RemoveContextBoxCheckbox(row) => this.contextView.RemoveCheckbox(row)
    ModifyContextBoxCol(col, width) => this.contextView.ModifyCol(col, width)
    ModifyContextBox(row, options) => this.contextView.Modify(row, options)
    GetContextBoxNext(row) => this.contextView.GetNext(row)
    GetContextBoxValue() => this.contextView.GetValue()
    GetContextBoxHwnd() => this.contextView.contextBox.Hwnd
    
    GetPromptValue() => this.promptView.GetValue()
    SetPromptValue(text) => this.promptView.SetValue(text)
    ClearPrompt() => this.promptView.Clear()
    SetAskButtonText(text) => this.promptView.SetAskButtonText(text)
    SetAskButtonEnabled(enabled) => this.promptView.SetAskButtonEnabled(enabled)
    SetSystemPromptValue(value) => this.promptView.SetSystemPromptValue(value)
    GetSystemPromptValue() => this.promptView.GetSystemPromptValue()
    ClearSystemPrompt() => this.promptView.ClearSystemPrompt()
    AddSystemPromptItems(items) => this.promptView.AddSystemPrompts(items)
    SetSystemPromptEnabled(enabled) => this.promptView.SetSystemPromptEnabled(enabled)
    
    SetSessionSelectValue(value) => this.topControlsView.SetValue(value)
    GetSessionSelectValue() => this.topControlsView.GetValue()
    UpdateRecordButton(isRecording) => this.topControlsView.UpdateRecordButton(isRecording)
    
    UpdateBatchMode(enabled) => this.menuView.UpdateBatchMode(enabled)
    UpdateModelMenu(selectedIndex, modelNames) => this.menuView.UpdateModelMenu(selectedIndex, modelNames)
    
    ShowSaveFileDialog(defaultFilename, title, filter) => FileSelect("S16", defaultFilename, title, filter)
    ShowOpenFileDialog(title, filter) => FileSelect("3", , title, filter)
    ShowMessage(text, title := "Information", options := "Iconi") => MsgBox(text, title, options)
    ShowError(text, title := "Error") => MsgBox(text, title, "Iconx")
    
    GetResponseCtrHwnd() => this.responseView.GetHwnd()

    SetClearHistoryButtonEnabled(enabled) => this.historyView.SetClearHistoryButtonEnabled(enabled)
    SetResetAllButtonEnabled(enabled) => this.topControlsView.SetResetButtonEnabled(enabled)
}
