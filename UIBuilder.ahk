; UI Builder - Helper functions for creating UI sections
#Include UIConfig.ahk

class UIBuilder {
    static CreateMenuBar(gui, controller, appSettingsValue, sessionManagerValue) {
        FileMenu := Menu()
        FileMenu.Add("Save Conversation", ObjBindMethod(controller, "SaveConversation"))
        FileMenu.Add("Load Conversation", ObjBindMethod(controller, "LoadConversation"))
        FileMenu.Add()  ; Separator
        FileMenu.Add("Reload Settings", ObjBindMethod(controller, "ReloadSettings"))
        FileMenu.Add()  ; Separator
        FileMenu.Add("Exit", ObjBindMethod(controller, "ExitApplication"))

        ModelMenu := Menu()
        for index, modelName in appSettingsValue.llmTypes {
            ModelMenu.Add(modelName, ObjBindMethod(controller, "SelectModel"))
        }

        ; Get current model name for menu label
        currentModelIndex := sessionManagerValue.GetCurrentSessionLLMType()
        currentModelName := "Model: " . appSettingsValue.llmTypes[currentModelIndex]

        ; Set initial checkmark in Model menu
        for index, modelName in appSettingsValue.llmTypes {
            if (index = currentModelIndex) {
                ModelMenu.Check(modelName)
            }
        }

        ; Create Answer Size menu
        AnswerSizeMenu := Menu()
        AnswerSizeMenu.Add("Small", ObjBindMethod(controller, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Default", ObjBindMethod(controller, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Long", ObjBindMethod(controller, "SelectAnswerSize"))
        
        ; Set initial checkmark (Default = index 2)
        AnswerSizeMenu.Check("Default")

        ; Create History menu
        HistoryMenu := Menu()
        HistoryMenu.Add("Compress", ObjBindMethod(controller, "CompressHistory"))
        HistoryMenu.Add("Extract Notes", ObjBindMethod(controller, "ExtractLearnings"))

        MyMenuBar := MenuBar()
        MyMenuBar.Add("&File", FileMenu)
        MyMenuBar.Add("History", HistoryMenu)
        MyMenuBar.Add("Answer Size", AnswerSizeMenu)
        MyMenuBar.Add(currentModelName, ModelMenu)  ; Use model name instead of "&Model"
        gui.MenuBar := MyMenuBar
        
        return {menuBar: MyMenuBar, modelMenu: ModelMenu, historyMenu: HistoryMenu}  ; Return menuBar, modelMenu and historyMenu
    }

    static CreateTopControls(gui, sessionManagerValue, trayManagerValue, controller) {
        ; Add session selector
        sessionCombo := gui.Add("DropDownList", "x10 y12 w70 vSessionSelect", sessionManagerValue.sessionNames)
        sessionCombo.Value := sessionManagerValue.currentSessionIndex
        sessionCombo.OnEvent("Change", ObjBindMethod(controller, "SessionChanged"))

        ; Add record button
        recordButtonTitle := trayManagerValue.isRecording ? "Stop" : "Record"
        recordButton := gui.Add("Button", "x90 y10 w90", recordButtonTitle)
        recordButton.OnEvent("Click", ObjBindMethod(controller, "ToggleRecording"))

        ; Add reset button
        resetButton := gui.Add("Button", "x300 y10 w90", "Reset All")
        resetButton.OnEvent("Click", ObjBindMethod(controller, "ResetAll"))
    }

    static CreateContextSection(gui, contextViewController) {
        ; Add context list with reduced height - ListView with Checkboxes
        contextBox := gui.Add("ListView", "vContextBox x10 y40 w380 h150 Checked -Hdr", ["Item"]) ; -Hdr to hide header
        contextBox.OnEvent("ItemSelect", ObjBindMethod(contextViewController, "ContextBoxSelect"))
        ; We will populate it in ContextViewController.UpdateContextView

        ; Context buttons
        deleteButton := gui.Add("Button", "x10 y190 w120", "Delete Selected")
        deleteButton.OnEvent("Click", ObjBindMethod(contextViewController, "DeleteSelected"))

        clearSelectionButton := gui.Add("Button", "x140 y190 w120", "Reset Selection")
        clearSelectionButton.OnEvent("Click", ObjBindMethod(contextViewController, "ResetSelection"))

        clearAllButton := gui.Add("Button", "x270 y190 w120", "Clear Context")
        clearAllButton.OnEvent("Click", ObjBindMethod(contextViewController, "ClearAllContext"))
    }

    static CreateChatHistorySection(gui, historyViewController) {
        ; Add ListView for chat history
        chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        chatHistory.ModifyCol(1, 30)  ; Role column width
        chatHistory.ModifyCol(2, 250) ; Text column width
        chatHistory.ModifyCol(3, 50)  ; Time column width
        chatHistory.ModifyCol(4, 50)  ; Tokens column width
        chatHistory.OnEvent("ItemSelect", ObjBindMethod(historyViewController, "ChatHistorySelect"))

        ; Chat history buttons
        deleteMessageButton := gui.Add("Button", "x10 y375 w120", "Delete Selected")
        deleteMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "DeleteSelectedMessage"))

        chatMessageButton := gui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Copy")
        chatMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "CopySelectedMessage"))

        clearHistoryButton := gui.Add("Button", "x270 y375 w120", "Clear History")
        clearHistoryButton.OnEvent("Click", ObjBindMethod(historyViewController, "ClearChatHistory"))
    }


    static CreatePromptSection(gui, sessionManagerValue, appSettingsValue, controller) {
        ; Prompt edit control
        promptEdit := gui.Add("Edit", "vPromptEdit x" UIConfig.promptEditX " y" UIConfig.promptEditY " w" UIConfig.promptEditWidth " h" UIConfig.promptEditHeight " Multi WantReturn", "")
        promptEdit.OnEvent("Change", ObjBindMethod(controller, "PromptChange"))
    }

    static CreateBottomControls(gui, sessionManagerValue, appSettingsValue, controller) {
        ; PowerShell tool checkbox and icon
        powerShellEnabled := appSettingsValue.IsToolEnabled(sessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")

        powerShellToolBox := gui.Add("CheckBox", "x" (UIConfig.llmTypeX + 20) " y" UIConfig.llmTypeY " w40 vPowerShellToolBox", "ps1")
        powerShellIcon := gui.Add("Picture", "x" (UIConfig.llmTypeX) " y" UIConfig.llmTypeY " w16 h16 Icon1 vPowerShellIcon", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
        powerShellToolBox.Value := powerShellEnabled ? 1 : 0

        ; Add system prompt selector
        systemPromptCombo := gui.Add("DropDownList", "x" UIConfig.systemPromptX " y" (UIConfig.systemPromptY + 2) " w" UIConfig.systemPromptWidth " vSystemPrompt", appSettingsValue.GetSystemPromptNames(sessionManagerValue.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := sessionManagerValue.GetCurrentSessionSystemPrompt()
        systemPromptCombo.OnEvent("Change", ObjBindMethod(controller, "SystemPromptChanged"))

        ; Add Ask LLM button
        askButton2 := gui.Add("Button", "x" UIConfig.askLLMX " y" UIConfig.askLLMY " w" UIConfig.askLLMWidth " vAskLLM", "Ask LLM")
        askButton2.OnEvent("Click", ObjBindMethod(controller, "AskToLLM"))

        return askButton2
    }

    static CreateResponseArea(gui) {
        responseCtr := gui.Add("Edit", "vResponseCtr x" UIConfig.responseCtrX " y" UIConfig.responseCtrY " w" UIConfig.responseCtrWidth " h" UIConfig.responseCtrHeight " -VScroll", "")
        return responseCtr
    }

    static GuiResize(thisGui, MinMax, Width, Height, controller) {
        if (MinMax = -1)  ; If window is minimized
            return

        ; Resize the ResponseCtr control
        thisGui["ResponseCtr"].Move(UIConfig.responseCtrX, UIConfig.responseCtrY, Width - 410, Height - 20)

        ; Resize the WebView2 control to match ResponseCtr
        hCtrl := thisGui["ResponseCtr"].Hwnd
        rect := Buffer(16, 0)  ; RECT: left, top, right, bottom
        DllCall("GetClientRect", "ptr", hCtrl, "ptr", rect)

        widthResponseCtr := NumGet(rect, 8, "Int")   ; right
        heightResponseCtr := NumGet(rect, 12, "Int") ; bottom
        ; Set bounds relative to the ResponseCtr — top-left is (0,0)
        wvRect := Buffer(16, 0)
        NumPut("Int", 0, wvRect, 0)                          ; left
        NumPut("Int", 0, wvRect, 4)                          ; top
        NumPut("Int", widthResponseCtr, wvRect, 8)           ; right
        NumPut("Int", heightResponseCtr, wvRect, 12)         ; bottom
        if controller.guiShown {
            controller.WebViewManagerValue.Resize(wvRect)
        }

        ; Resize the prompt edit control
        promptEditHeight := Height - UIConfig.promptEditY - UIConfig.bottomControlsHeight
        thisGui["PromptEdit"].Move(UIConfig.promptEditX, UIConfig.promptEditY, UIConfig.promptEditWidth, promptEditHeight)

        ; Move bottom controls
        bottomY := Height - 35  ; 35 pixels from bottom
        thisGui["SystemPrompt"].Move(UIConfig.systemPromptX, bottomY + 2)
        thisGui["AskLLM"].Move(UIConfig.askLLMX, bottomY)

        ; Move PowerShell tool checkbox and icon above bottom controls
        checkBoxY := Height - 30
        thisGui["PowerShellIcon"].Move(UIConfig.llmTypeX, checkBoxY)
        thisGui["PowerShellToolBox"].Move(UIConfig.llmTypeX + 20, checkBoxY)
    }

    static ShowNotesWindow(notesContent) {
        notesGui := Gui()
        notesGui.Title := "Extracted Notes"
        notesGui.SetFont("s10", "Segoe UI")
        
        notesGui.Add("Text", "x10 y10 w580 h20", "Here are the extracted notes from your conversation:")
        
        notesEdit := notesGui.Add("Edit", "x10 y40 w580 h350 Multi ReadOnly vNotesEdit", notesContent)
        
        copyBtn := notesGui.Add("Button", "x10 y400 w150 h30", "Copy to Clipboard")
        copyBtn.OnEvent("Click", (*) => (A_Clipboard := notesContent, MsgBox("Copied to clipboard!", "Info", "T1")))
        
        closeBtn := notesGui.Add("Button", "x490 y400 w100 h30", "Close")
        closeBtn.OnEvent("Click", (*) => notesGui.Destroy())
        
        notesGui.Show("w600 h450")
    }
}
