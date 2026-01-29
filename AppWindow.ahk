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
        
        ; Initialize WebView after showing
        this.controller.WebViewManagerValue.Init(this.gui["ResponseCtr"])
        this.controller.WebViewManagerValue.SetInputCallback(ObjBindMethod(this.controller, "AppendToPrompt"))
        
        this.guiShown := true
        
        ; Update views
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
    }
    
    BuildUI() {
        this.gui := Gui()
        this.gui.Title := "LLM Assistant"
        this.gui.SetFont("s9", "Segoe UI")
        this.gui.Opt("+Resize +MinSize800x610")
        
        this.gui.OnEvent("Size", (gui, minMax, width, height) => UIBuilder.GuiResize(gui, minMax, width, height, this.controller))
        this.gui.OnEvent("Close", ObjBindMethod(this, "GuiClose"))
        
        ; Set GUI for VCs
        this.controller.ContextViewControllerValue.SetGui(this.gui)
        this.controller.HistoryViewControllerValue.SetGui(this.gui)
        
        ; Create Menus
        menus := UIBuilder.CreateMenuBar(this.gui, this.controller, this.controller.configManager, this.controller.SessionManagerValue, this.controller.MenuManagerValue, this.controller.ConversationHandlerValue, this.controller.ChatManagerValue)
        this.menuBar := menus.menuBar
        this.modelMenu := menus.modelMenu
        this.historyMenu := menus.historyMenu
        this.toolsMenu := menus.toolsMenu
        this.modeMenu := menus.modeMenu
        
        ; Initial menu states
        this.controller.MenuManagerValue.UpdateCompressionMenuState()
        this.controller.MenuManagerValue.UpdateToolsMenuState()
        
        ; Create Controls
        UIBuilder.CreateTopControls(this.gui, this.controller.SessionManagerValue, this.controller.TrayManagerValue, this.controller, this.controller.ConversationHandlerValue)
        UIBuilder.CreateContextSection(this.gui, this.controller.ContextViewControllerValue)
        UIBuilder.CreateChatHistorySection(this.gui, this.controller.HistoryViewControllerValue)
        UIBuilder.CreatePromptSection(this.gui, this.controller.SessionManagerValue, this.controller.configManager, this.controller)
        
        this.askButton := UIBuilder.CreateBottomControls(this.gui, this.controller.SessionManagerValue, this.controller.configManager, this.controller)
        
        UIBuilder.CreateResponseArea(this.gui)
    }
    
    GuiClose(*) {
        this.gui.Destroy()
        this.guiShown := false
    }
    
    UpdateRecordButton(isRecording) {
        if (this.guiShown) {
            try {
                if (isRecording) {
                    this.gui["Record"].Text := "Stop"
                } else {
                    this.gui["Stop"].Text := "Record"
                }
            }
        }
    }

    GetPromptValue() {
        return this.gui["PromptEdit"].Value
    }

    SetPromptValue(text) {
        this.gui["PromptEdit"].Value := text
    }
}
