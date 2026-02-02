#Requires AutoHotkey 2.0

class MenuManager {
    controller := ""
    configManager := ""
    sessionManager := ""
    selectModelCommand := ""

    __New(controller, configManager, sessionManager, selectModelCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.selectModelCommand := selectModelCommand
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get old model name for renaming menu
        oldModelName := this.controller.currentModelName

        ; Update session with new model index
        this.selectModelCommand.Execute(ItemPos)

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
        this.controller.view.menuBar.Rename(oldModelName, newModelName)
        this.controller.currentModelName := newModelName

        ; Update system prompts for the new model
        this.controller.view.ClearSystemPrompt()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType())
        this.controller.view.AddSystemPromptItems(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            this.controller.view.SetSystemPromptValue(1)
            this.controller.view.SetSystemPromptEnabled(true)
        } else {
            this.controller.view.SetSystemPromptEnabled(false)
        }

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
        if (!this.controller.view || !this.controller.view.historyMenu)
            return

        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        compressionPrompt := this.configManager.GetCompressionPrompt(currentLLMIndex)

        if (compressionPrompt == "") {
            this.controller.view.historyMenu.Disable("Compress")
        } else {
            this.controller.view.historyMenu.Enable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.controller.view || !this.controller.view.toolsMenu)
            return

        currentLLMIndex := this.sessionManager.GetCurrentSessionLLMType()
        
        ; Update PowerShell
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "powerShellTool")
        if (powerShellEnabled) {
            this.controller.view.toolsMenu.Check("PowerShell")
        } else {
            this.controller.view.toolsMenu.Uncheck("PowerShell")
        }

        ; Update File System
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "fileSystemTool")
        if (fileSystemEnabled) {
             this.controller.view.toolsMenu.Check("File System")
        } else {
             this.controller.view.toolsMenu.Uncheck("File System")
        }

        ; Update Web Search
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "webSearch")
        if (webSearchEnabled) {
            this.controller.view.toolsMenu.Check("Web Search")
        } else {
            this.controller.view.toolsMenu.Uncheck("Web Search")
        }

        ; Update Web Fetch
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLMIndex, "webFetch")
        if (webFetchEnabled) {
            this.controller.view.toolsMenu.Check("Web Fetch")
        } else {
            this.controller.view.toolsMenu.Uncheck("Web Fetch")
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