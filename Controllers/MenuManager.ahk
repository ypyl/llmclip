#Requires AutoHotkey 2.0

class MenuManager {
    controller := ""
    configManager := ""
    sessionManager := ""

    __New(controller, configManager, sessionManager) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get old model name for renaming menu
        oldModelName := this.controller.currentModelName

        ; Update session with new model index
        this.sessionManager.SetCurrentSessionLLMType(ItemPos)

        ; Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = ItemPos) {
                MyMenu.Check(modelName)
            } else {
                MyMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label to show new model name
        newModelName := "Model: " . this.configManager.llmTypes[ItemPos]
        try this.controller.MyMenuBar.Rename(oldModelName, newModelName)
        this.controller.currentModelName := newModelName

        ; Update system prompts for the new model
        systemPromptCombo := this.controller.MyGui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType())
        systemPromptCombo.Add(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            systemPromptCombo.Value := 1
            systemPromptCombo.Enabled := true
        } else {
            systemPromptCombo.Enabled := false
        }
        this.sessionManager.SetCurrentSessionSystemPrompt(1)

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }

    SelectAnswerSize(ItemName, ItemPos, MyMenu) {
        ; Update checkmarks
        for _, size in ["Small", "Default", "Long"] {
            if (size = ItemName) {
                MyMenu.Check(size)
            } else {
                MyMenu.Uncheck(size)
            }
        }

        ; Store current answer size
        this.controller.currentAnswerSize := ItemName
    }

    UpdateCompressionMenuState() {
        if (!this.controller.HistoryMenu)
            return

        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        compressionPrompt := this.configManager.GetCompressionPrompt(currentLLMIndex)

        if (compressionPrompt == "") {
            this.controller.HistoryMenu.Disable("Compress")
        } else {
            this.controller.HistoryMenu.Enable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.controller.ToolsMenu)
            return

        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        
        ; Update PowerShell
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "powerShellTool")
        if (powerShellEnabled) {
            this.controller.ToolsMenu.Check("PowerShell")
        } else {
            this.controller.ToolsMenu.Uncheck("PowerShell")
        }

        ; Update File System
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "fileSystemTool")
        if (fileSystemEnabled) {
             this.controller.ToolsMenu.Check("File System")
        } else {
             this.controller.ToolsMenu.Uncheck("File System")
        }

        ; Update Web Search
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "webSearch")
        if (webSearchEnabled) {
            this.controller.ToolsMenu.Check("Web Search")
        } else {
            this.controller.ToolsMenu.Uncheck("Web Search")
        }

        ; Update Web Fetch
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "webFetch")
        if (webFetchEnabled) {
            this.controller.ToolsMenu.Check("Web Fetch")
        } else {
            this.controller.ToolsMenu.Uncheck("Web Fetch")
        }
    }

    ToggleTool(toolName, *) {
        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        isEnabled := this.configManager.IsToolEnabled(currentLLMIndex, toolName)
        
        ; Toggle state
        this.configManager.SetToolEnabled(currentLLMIndex, toolName, !isEnabled)
        
        ; Update UI
        this.UpdateToolsMenuState()
    }
}