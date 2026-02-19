#Requires AutoHotkey 2.0

class SettingsController {
    view := ""
    configManager := ""
    sessionManager := ""
    
    ; Commands
    selectModelCommand := ""
    changeAnswerSizeCommand := ""
    toggleToolCommand := ""
    getToolsStateCommand := ""
    getCompressionStateCommand := ""
    changeSystemPromptCommand := ""
    reloadSettingsCommand := ""

    __New(configManager, sessionManager, selectModelCommand, changeAnswerSizeCommand, toggleToolCommand, getToolsStateCommand, getCompressionStateCommand, changeSystemPromptCommand, reloadSettingsCommand) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.selectModelCommand := selectModelCommand
        this.changeAnswerSizeCommand := changeAnswerSizeCommand
        this.toggleToolCommand := toggleToolCommand
        this.getToolsStateCommand := getToolsStateCommand
        this.getCompressionStateCommand := getCompressionStateCommand
        this.changeSystemPromptCommand := changeSystemPromptCommand
        this.reloadSettingsCommand := reloadSettingsCommand
    }

    SetView(view) {
        this.view := view
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
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

        ; Update menu bar label
        rootController := this.view.controller
        oldModelName := rootController.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[ItemPos]
        if (oldModelName != newModelName) {
            try this.view.menuBar.Rename(oldModelName, newModelName)
            rootController.currentModelName := newModelName
        }

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
        for _, size in ["Small", "Default", "Long"] {
            if (size = ItemName) {
                MyMenu.Check(size)
            } else {
                MyMenu.Uncheck(size)
            }
        }
        this.changeAnswerSizeCommand.Execute(ItemName)
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

        this.view.toolsMenu.Uncheck("PowerShell")
        this.view.toolsMenu.Uncheck("File System")
        this.view.toolsMenu.Uncheck("Web Search")
        this.view.toolsMenu.Uncheck("Web Fetch")
        this.view.toolsMenu.Uncheck("Markdown New")

        if (toolStates.powerShell)
            this.view.toolsMenu.Check("PowerShell")
        if (toolStates.fileSystem)
             this.view.toolsMenu.Check("File System")
        if (toolStates.webSearch)
            this.view.toolsMenu.Check("Web Search")
        if (toolStates.webFetch)
            this.view.toolsMenu.Check("Web Fetch")
        if (toolStates.markdownNew)
            this.view.toolsMenu.Check("Markdown New")
    }

    ToggleTool(toolName, *) {
        this.toggleToolCommand.Execute(toolName)
        this.UpdateToolsMenuState()
    }

    SystemPromptChanged(*) {
        systemPromptIndex := this.view.GetSystemPromptValue()
        this.changeSystemPromptCommand.Execute(systemPromptIndex)

        inputTemplate := this.configManager.GetInputTemplate(
            this.sessionManager.GetCurrentSessionLLMType(),
            systemPromptIndex
        )
        if (inputTemplate) {
            this.view.SetPromptValue(inputTemplate)
        }
        
        if (this.view.contextViewController)
            this.view.contextViewController.UpdateContextView()
    }

    ReloadSettings(*) {
        this.reloadSettingsCommand.Execute()

        this.view.modelMenu.Delete()
        for index, modelName in this.configManager.llmTypes {
            this.view.modelMenu.Add(modelName, ObjBindMethod(this, "SelectModel"))
        }

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.configManager.llmTypes.Length) {
            this.view.modelMenu.Check(this.configManager.llmTypes[currentModelIndex])
        } else {
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.view.modelMenu.Check(this.configManager.llmTypes[1])
        }

        rootController := this.view.controller
        oldModelName := rootController.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.view.menuBar.Rename(oldModelName, newModelName)
        rootController.currentModelName := newModelName

        currentSystemPrompt := this.view.GetSystemPromptValue()
        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        try {
            this.view.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.view.SetSystemPromptValue(1)
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }
}
