#Requires AutoHotkey 2.0

class MenuController {
    selectModelCommand := ""
    getToolsStateCommand := ""
    getCompressionStateCommand := ""
    view := ""
    currentModelName := ""
    currentAnswerSize := "Default"


    __New(view, configManager, sessionManager, selectModelCommand, getToolsStateCommand, getCompressionStateCommand, toggleToolCommand) {
        this.view := view
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.selectModelCommand := selectModelCommand
        this.getToolsStateCommand := getToolsStateCommand
        this.getCompressionStateCommand := getCompressionStateCommand
        this.toggleToolCommand := toggleToolCommand
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get old model name for renaming menu
        oldModelName := this.currentModelName

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
        this.view.menuBar.Rename(oldModelName, newModelName)
        this.currentModelName := newModelName

        ; Update system prompts for the new model
        this.view.ClearSystemPrompt()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType())
        this.view.AddSystemPromptItems(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            this.view.SetSystemPromptValue(1)
            this.view.SetSystemPromptEnabled(true)
        } else {
            this.view.SetSystemPromptEnabled(false)
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
        this.currentAnswerSize := ItemName
    }

    UpdateCompressionMenuState() {
        if (!this.view || !this.view.historyMenu)
            return

        isEnabled := this.getCompressionStateCommand.Execute()

        if (isEnabled) {
            this.view.historyMenu.Enable("Compress")
        } else {
            this.view.historyMenu.Disable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.view || !this.view.toolsMenu)
            return

        toolStates := this.getToolsStateCommand.Execute()
        
        ; Update PowerShell
        if (toolStates.powerShell) {
            this.view.toolsMenu.Check("PowerShell")
        } else {
            this.view.toolsMenu.Uncheck("PowerShell")
        }

        ; Update File System
        if (toolStates.fileSystem) {
             this.view.toolsMenu.Check("File System")
        } else {
             this.view.toolsMenu.Uncheck("File System")
        }

        ; Update Web Search
        if (toolStates.webSearch) {
            this.view.toolsMenu.Check("Web Search")
        } else {
            this.view.toolsMenu.Uncheck("Web Search")
        }

        ; Update Web Fetch
        if (toolStates.webFetch) {
            this.view.toolsMenu.Check("Web Fetch")
        } else {
            this.view.toolsMenu.Uncheck("Web Fetch")
        }
    }

    ToggleTool(toolName, *) {
        ; Execute toggle command
        this.toggleToolCommand.Execute(toolName)
        
        ; Update UI
        this.UpdateToolsMenuState()
    }
}