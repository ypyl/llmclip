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
            this.controller.ModelDisplayNames,
            this.controller.CurrentModelIndex,
            this.controller.SessionLabels,
            this.controller.CurrentSessionIndex
        )

        this.topControlsView.Create(
            this.gui,
            this.controller.IsRecording,
            this.recordingController,
            this.controller,
            this.contextViewController
        )

        this.contextView.Create(this.gui, this.contextViewController)
        this.historyView.Create(this.gui, this.historyViewController)
        
        this.promptView.Create(
            this.gui, 
            this,
            this.controller.GetSystemPrompts(this.controller.CurrentModelIndex),
            this.controller.CurrentSystemPromptIndex,
            this.settingsController,
            this.controller
        )

        this.responseView.Create(this.gui)

        ; Initial menu states
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

}
