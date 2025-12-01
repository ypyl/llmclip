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

        MyMenuBar := MenuBar()
        MyMenuBar.Add("&File", FileMenu)
        MyMenuBar.Add(currentModelName, ModelMenu)  ; Use model name instead of "&Model"
        gui.MenuBar := MyMenuBar
        
        return {menuBar: MyMenuBar, modelMenu: ModelMenu}  ; Return both
    }

    static CreateTopControls(gui, sessionManagerValue, trayManagerValue, controller) {
        ; Add session selector
        sessionCombo := gui.Add("DropDownList", "x10 y10 w70 vSessionSelect", sessionManagerValue.sessionNames)
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

    static CreateContextSection(gui, controller) {
        ; Add context list with reduced height
        labels := controller.GetLabelsForContextItems()
        contextBox := gui.Add("ListBox", "vContextBox x10 y40 w380 h150 VScroll HScroll Multi", labels)
        contextBox.OnEvent("Change", ObjBindMethod(controller, "ContextBoxSelect"))

        ; Context buttons
        deleteButton := gui.Add("Button", "x10 y190 w120", "Delete Selected")
        deleteButton.OnEvent("Click", ObjBindMethod(controller, "DeleteSelected"))

        clearSelectionButton := gui.Add("Button", "x140 y190 w120", "Reset Selection")
        clearSelectionButton.OnEvent("Click", ObjBindMethod(controller, "ResetSelection"))

        clearAllButton := gui.Add("Button", "x270 y190 w120", "Clear Context")
        clearAllButton.OnEvent("Click", ObjBindMethod(controller, "ClearAllContext"))
    }

    static CreateChatHistorySection(gui, controller) {
        ; Add ListView for chat history
        chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        chatHistory.ModifyCol(1, 30)  ; Role column width
        chatHistory.ModifyCol(2, 250) ; Text column width
        chatHistory.ModifyCol(3, 50)  ; Time column width
        chatHistory.ModifyCol(4, 50)  ; Tokens column width
        chatHistory.OnEvent("ItemSelect", ObjBindMethod(controller, "ChatHistorySelect"))

        ; Chat history buttons
        deleteMessageButton := gui.Add("Button", "x10 y375 w120", "Delete Selected")
        deleteMessageButton.OnEvent("Click", ObjBindMethod(controller, "DeleteSelectedMessage"))

        chatMessageButton := gui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Copy")
        chatMessageButton.OnEvent("Click", ObjBindMethod(controller, "CopySelectedMessage"))

        clearHistoryButton := gui.Add("Button", "x270 y375 w120", "Clear History")
        clearHistoryButton.OnEvent("Click", ObjBindMethod(controller, "ClearChatHistory"))
    }

    static CreatePromptSection(gui, sessionManagerValue, appSettingsValue, controller) {

        ; Prompt edit control
        promptEdit := gui.Add("Edit", "vPromptEdit x" UIConfig.promptEditX " y" UIConfig.promptEditY " w" UIConfig.promptEditWidth " h" UIConfig.promptEditHeight " Multi WantReturn", "")
        promptEdit.OnEvent("Change", ObjBindMethod(controller, "PromptChange"))

        ; PowerShell tool checkbox and icon
        powerShellEnabled := appSettingsValue.IsToolEnabled(sessionManagerValue.GetCurrentSessionLLMType(), "powerShellTool")

        powerShellToolBox := gui.Add("CheckBox", "x" UIConfig.llmTypeX " y" (UIConfig.llmTypeY - 20) " w40 vPowerShellToolBox", "ps1")
        powerShellIcon := gui.Add("Picture", "x" (UIConfig.llmTypeX + 40) " y" (UIConfig.llmTypeY - 20) " w16 h16 Icon1 vPowerShellIcon", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
        powerShellToolBox.Value := powerShellEnabled ? 1 : 0

        ; Answer size slider (0=Small, 1=Default, 2=Long)
        answerSizeBox := gui.Add("Slider", "x" (UIConfig.llmTypeX + 290) " y" (UIConfig.llmTypeY - 5) " w80 vAnswerSizeBox Range0-2 TickInterval1 NoTicks", 1)
    }

    static CreateBottomControls(gui, sessionManagerValue, appSettingsValue, controller) {
        ; Add LLM type selector - REMOVED
        ; llmTypeCombo := gui.Add("DropDownList", "x" UIConfig.llmTypeX " y" UIConfig.llmTypeY " w" UIConfig.llmTypeWidth " vLLMType", appSettingsValue.llmTypes)
        ; llmTypeCombo.Value := sessionManagerValue.GetCurrentSessionLLMType()
        ; llmTypeCombo.OnEvent("Change", ObjBindMethod(controller, "LLMTypeChanged"))

        ; Add system prompt selector
        systemPromptCombo := gui.Add("DropDownList", "x" UIConfig.systemPromptX " y" UIConfig.systemPromptY " w" UIConfig.systemPromptWidth " vSystemPrompt", appSettingsValue.GetSystemPromptNames(sessionManagerValue.GetCurrentSessionLLMType()))
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
}
