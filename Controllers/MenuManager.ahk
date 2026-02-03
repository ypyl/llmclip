#Requires AutoHotkey 2.0

class MenuManager {
    controller := ""
    selectModelCommand := ""
    getToolsStateCommand := ""
    getCompressionStateCommand := ""
    toggleToolCommand := ""

    __New(controller, configManager, sessionManager, selectModelCommand, getToolsStateCommand, getCompressionStateCommand, toggleToolCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.selectModelCommand := selectModelCommand
        this.getToolsStateCommand := getToolsStateCommand
        this.getCompressionStateCommand := getCompressionStateCommand
        this.toggleToolCommand := toggleToolCommand
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

        isEnabled := this.getCompressionStateCommand.Execute()

        if (isEnabled) {
            this.controller.view.historyMenu.Enable("Compress")
        } else {
            this.controller.view.historyMenu.Disable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.controller.view || !this.controller.view.toolsMenu)
            return

        toolStates := this.getToolsStateCommand.Execute()
        
        ; Update PowerShell
        if (toolStates.powerShell) {
            this.controller.view.toolsMenu.Check("PowerShell")
        } else {
            this.controller.view.toolsMenu.Uncheck("PowerShell")
        }

        ; Update File System
        if (toolStates.fileSystem) {
             this.controller.view.toolsMenu.Check("File System")
        } else {
             this.controller.view.toolsMenu.Uncheck("File System")
        }

        ; Update Web Search
        if (toolStates.webSearch) {
            this.controller.view.toolsMenu.Check("Web Search")
        } else {
            this.controller.view.toolsMenu.Uncheck("Web Search")
        }

        ; Update Web Fetch
        if (toolStates.webFetch) {
            this.controller.view.toolsMenu.Check("Web Fetch")
        } else {
            this.controller.view.toolsMenu.Uncheck("Web Fetch")
        }
    }

    ToggleTool(toolName, *) {
        ; Execute toggle command
        this.toggleToolCommand.Execute(toolName)
        
        ; Update UI
        this.UpdateToolsMenuState()
    }
}