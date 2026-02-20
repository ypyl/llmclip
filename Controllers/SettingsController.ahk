#Requires AutoHotkey 2.0

class SettingsController {
    menuView := ""
    promptView := ""
    mainView := ""
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

    SetViews(menuView, promptView, mainView) {
        this.menuView := menuView
        this.promptView := promptView
        this.mainView := mainView
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
        rootController := this.mainView.controller
        oldModelName := rootController.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[ItemPos]
        if (oldModelName != newModelName) {
            try this.menuView.RenameMenu(oldModelName, newModelName)
            rootController.currentModelName := newModelName
        }

        ; Update system prompts for the new model
        this.promptView.ClearSystemPrompt()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType())
        this.promptView.AddSystemPrompts(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            this.promptView.SetSystemPromptValue(1)
            this.promptView.SetSystemPromptEnabled(true)
        } else {
            this.promptView.SetSystemPromptEnabled(false)
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
        if (!this.menuView || !this.menuView.historyMenu)
            return

        isEnabled := this.getCompressionStateCommand.Execute()
        if (isEnabled) {
            this.menuView.historyMenu.Enable("Compress")
        } else {
            this.menuView.historyMenu.Disable("Compress")
        }
    }

    UpdateToolsMenuState() {
        if (!this.menuView || !this.menuView.toolsMenu)
            return

        toolStates := this.getToolsStateCommand.Execute()

        this.menuView.toolsMenu.Uncheck("PowerShell")
        this.menuView.toolsMenu.Uncheck("File System")
        this.menuView.toolsMenu.Uncheck("Web Search")
        this.menuView.toolsMenu.Uncheck("Web Fetch")
        this.menuView.toolsMenu.Uncheck("Markdown New")

        if (toolStates.powerShell)
            this.menuView.toolsMenu.Check("PowerShell")
        if (toolStates.fileSystem)
             this.menuView.toolsMenu.Check("File System")
        if (toolStates.webSearch)
            this.menuView.toolsMenu.Check("Web Search")
        if (toolStates.webFetch)
            this.menuView.toolsMenu.Check("Web Fetch")
        if (toolStates.markdownNew)
            this.menuView.toolsMenu.Check("Markdown New")
    }

    ToggleTool(toolName, *) {
        this.toggleToolCommand.Execute(toolName)
        this.UpdateToolsMenuState()
    }

    SystemPromptChanged(*) {
        systemPromptIndex := this.promptView.GetSystemPromptValue()
        this.changeSystemPromptCommand.Execute(systemPromptIndex)

        inputTemplate := this.configManager.GetInputTemplate(
            this.sessionManager.GetCurrentSessionLLMType(),
            systemPromptIndex
        )
        if (inputTemplate) {
            this.promptView.SetValue(inputTemplate)
        }
        
        if (this.mainView && this.mainView.contextViewController)
            this.mainView.contextViewController.UpdateContextView()
    }

    ReloadSettings(*) {
        this.reloadSettingsCommand.Execute()

        this.menuView.modelMenu.Delete()
        for index, modelName in this.configManager.llmTypes {
            this.menuView.modelMenu.Add(modelName, ObjBindMethod(this, "SelectModel"))
        }

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.configManager.llmTypes.Length) {
            this.menuView.CheckModel(this.configManager.llmTypes[currentModelIndex])
        } else {
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.menuView.CheckModel(this.configManager.llmTypes[1])
        }

        rootController := this.mainView.controller
        oldModelName := rootController.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.menuView.RenameMenu(oldModelName, newModelName)
        rootController.currentModelName := newModelName

        currentSystemPrompt := this.promptView.GetSystemPromptValue()
        this.promptView.ClearSystemPrompt()
        this.promptView.AddSystemPrompts(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        try {
            this.promptView.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.promptView.SetSystemPromptValue(1)
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }
}
