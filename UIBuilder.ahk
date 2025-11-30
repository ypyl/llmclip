; UI Builder - Helper functions for creating UI sections
#Include UIConfig.ahk

class UIBuilder {
    static CreateMenuBar(gui) {
        FileMenu := Menu()
        FileMenu.Add("Save Conversation", SaveConversation)
        FileMenu.Add("Load Conversation", LoadConversation)
        FileMenu.Add()  ; Separator
        FileMenu.Add("Reload Settings", ReloadSettings)
        FileMenu.Add()  ; Separator
        FileMenu.Add("Exit", ExitApplication)
        MyMenuBar := MenuBar()
        MyMenuBar.Add("&File", FileMenu)
        gui.MenuBar := MyMenuBar
    }

    static CreateTopControls(gui, sessionManagerValue, trayManagerValue) {
        ; Add session selector
        sessionCombo := gui.Add("DropDownList", "x10 y10 w70 vSessionSelect", sessionManagerValue.sessionNames)
        sessionCombo.Value := sessionManagerValue.currentSessionIndex
        sessionCombo.OnEvent("Change", SessionChanged)

        ; Add record button
        recordButtonTitle := trayManagerValue.isRecording ? "Stop" : "Record"
        recordButton := gui.Add("Button", "x90 y10 w90", recordButtonTitle)
        recordButton.OnEvent("Click", ToggleRecording)

        ; Add reset button
        resetButton := gui.Add("Button", "x300 y10 w90", "Reset All")
        resetButton.OnEvent("Click", ResetAll)
    }

    static CreateContextSection(gui) {
        ; Add context list with reduced height
        labels := GetLabelsForContextItems()
        contextBox := gui.Add("ListBox", "vContextBox x10 y40 w380 h150 VScroll HScroll Multi", labels)
        contextBox.OnEvent("Change", ContextBoxSelect)

        ; Context buttons
        deleteButton := gui.Add("Button", "x10 y190 w120", "Delete Selected")
        deleteButton.OnEvent("Click", DeleteSelected)

        clearSelectionButton := gui.Add("Button", "x140 y190 w120", "Reset Selection")
        clearSelectionButton.OnEvent("Click", ResetSelection)

        clearAllButton := gui.Add("Button", "x270 y190 w120", "Clear Context")
        clearAllButton.OnEvent("Click", ClearAllContext)
    }

    static CreateChatHistorySection(gui) {
        ; Add ListView for chat history
        chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        chatHistory.ModifyCol(1, 30)  ; Role column width
        chatHistory.ModifyCol(2, 250) ; Text column width
        chatHistory.ModifyCol(3, 50)  ; Time column width
        chatHistory.ModifyCol(4, 50)  ; Tokens column width
        chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

        ; Chat history buttons
        deleteMessageButton := gui.Add("Button", "x10 y375 w120", "Delete Selected")
        deleteMessageButton.OnEvent("Click", DeleteSelectedMessage)

        chatMessageButton := gui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Copy")
        chatMessageButton.OnEvent("Click", CopySelectedMessage)

        clearHistoryButton := gui.Add("Button", "x270 y375 w120", "Clear History")
        clearHistoryButton.OnEvent("Click", ClearChatHistory)
    }

    static CreatePromptSection(gui, sessionManagerValue, appSettingsValue) {

        ; Prompt edit control
        promptEdit := gui.Add("Edit", "vPromptEdit x" UIConfig.promptEditX " y" UIConfig.promptEditY " w" UIConfig.promptEditWidth " h" UIConfig.promptEditHeight " Multi WantReturn", "")
        promptEdit.OnEvent("Change", PromptChange)

        ; PowerShell tool checkbox and icon
        powerShellEnabled := appSettingsValue.IsToolEnabled(sessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")

        powerShellToolBox := gui.Add("CheckBox", "x" UIConfig.llmTypeX " y" (UIConfig.llmTypeY - 20) " w40 vPowerShellToolBox", "ps1")
        powerShellIcon := gui.Add("Picture", "x" (UIConfig.llmTypeX + 40) " y" (UIConfig.llmTypeY - 20) " w16 h16 Icon1 vPowerShellIcon", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
        powerShellToolBox.Value := powerShellEnabled ? 1 : 0

        ; Answer size slider (0=Small, 1=Default, 2=Long)
        answerSizeBox := gui.Add("Slider", "x" (UIConfig.llmTypeX + 290) " y" (UIConfig.llmTypeY - 5) " w80 vAnswerSizeBox Range0-2 TickInterval1 NoTicks", 1)
    }

    static CreateBottomControls(gui, sessionManagerValue, appSettingsValue) {
        ; Add LLM type selector
        llmTypeCombo := gui.Add("DropDownList", "x" UIConfig.llmTypeX " y" UIConfig.llmTypeY " w" UIConfig.llmTypeWidth " vLLMType", appSettingsValue.llmTypes)
        llmTypeCombo.Value := sessionManagerValue.GetCurrentSessionLLMType()
        llmTypeCombo.OnEvent("Change", LLMTypeChanged)

        ; Add system prompt selector
        systemPromptCombo := gui.Add("DropDownList", "x" UIConfig.systemPromptX " y" UIConfig.systemPromptY " w" UIConfig.systemPromptWidth " vSystemPrompt", appSettingsValue.GetSystemPromptNames(sessionManagerValue.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := sessionManagerValue.GetCurrentSessionSystemPrompt()
        systemPromptCombo.OnEvent("Change", SystemPromptChanged)

        ; Add Ask LLM button
        askButton2 := gui.Add("Button", "x" UIConfig.askLLMX " y" UIConfig.askLLMY " w" UIConfig.askLLMWidth " vAskLLM", "Ask LLM")
        askButton2.OnEvent("Click", AskToLLM)

        return askButton2
    }

    static CreateResponseArea(gui) {
        responseCtr := gui.Add("Edit", "vResponseCtr x" UIConfig.responseCtrX " y" UIConfig.responseCtrY " w" UIConfig.responseCtrWidth " h" UIConfig.responseCtrHeight " -VScroll", "")
        return responseCtr
    }
}
