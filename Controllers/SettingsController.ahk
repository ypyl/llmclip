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
    switchSessionCommand := ""

    __New(configManager, sessionManager, selectModelCommand, changeAnswerSizeCommand, toggleToolCommand, getToolsStateCommand, getCompressionStateCommand, changeSystemPromptCommand, reloadSettingsCommand, switchSessionCommand) {
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.selectModelCommand := selectModelCommand
        this.changeAnswerSizeCommand := changeAnswerSizeCommand
        this.toggleToolCommand := toggleToolCommand
        this.getToolsStateCommand := getToolsStateCommand
        this.getCompressionStateCommand := getCompressionStateCommand
        this.changeSystemPromptCommand := changeSystemPromptCommand
        this.reloadSettingsCommand := reloadSettingsCommand
        this.switchSessionCommand := switchSessionCommand
    }

    SetViews(menuView, promptView, mainView) {
        this.menuView := menuView
        this.promptView := promptView
        this.mainView := mainView
    }

    SelectModel(ItemName, ItemPos, MyMenu) {
        ; Get current system prompt name before changing model
        oldModelIndex := this.sessionManager.GetCurrentSessionModelIndex()
        oldSystemPromptIndex := this.sessionManager.GetCurrentSessionSystemPrompt()
        oldSystemPromptNames := this.configManager.GetSystemPromptNames(oldModelIndex)
        oldSystemPromptName := ""
        if (oldSystemPromptIndex > 0 && oldSystemPromptIndex <= oldSystemPromptNames.Length) {
            oldSystemPromptName := oldSystemPromptNames[oldSystemPromptIndex]
        }

        ; Update session with new model index
        this.selectModelCommand.Execute(ItemPos)

        ; Update UI
        this.menuView.UpdateModelMenu(ItemPos, this.configManager.modelDisplayNames)

        ; Update system prompts for the new model
        this.promptView.ClearSystemPrompt()
        systemPromptNames := this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionModelIndex())
        this.promptView.AddSystemPrompts(systemPromptNames)

        if (systemPromptNames.Length > 0) {
            newIndex := 1
            if (oldSystemPromptName != "") {
                for index, name in systemPromptNames {
                    if (name == oldSystemPromptName) {
                        newIndex := index
                        break
                    }
                }
            }

            this.promptView.SetSystemPromptValue(newIndex)
            this.promptView.SetSystemPromptEnabled(true)
            this.SystemPromptChanged()
        } else {
            this.promptView.SetSystemPromptEnabled(false)
        }

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }

    SelectAnswerSize(ItemName, ItemPos, MyMenu) {
        this.menuView.UpdateAnswerSizeMenu(ItemName)
        this.changeAnswerSizeCommand.Execute(ItemName)
    }

    SelectSession(ItemName, ItemPos, MyMenu) {
        this.switchSessionCommand.Execute(ItemPos)
        
        if (this.mainView && this.mainView.controller) {
            this.mainView.controller.UpdateSessionUI()
        }
    }

    UpdateCompressionMenuState() {
        if (!this.menuView)
            return

        isEnabled := this.getCompressionStateCommand.Execute()
        this.menuView.UpdateCompressionState(isEnabled)
    }

    UpdateToolsMenuState() {
        if (!this.menuView)
            return

        toolStates := this.getToolsStateCommand.Execute()
        this.menuView.UpdateToolsMenu(toolStates)
    }

    ToggleTool(toolName, *) {
        this.toggleToolCommand.Execute(toolName)
        this.UpdateToolsMenuState()
    }

    SystemPromptChanged(*) {
        systemPromptIndex := this.promptView.GetSystemPromptValue()
        this.changeSystemPromptCommand.Execute(systemPromptIndex)

        inputTemplate := this.configManager.GetInputTemplate(
            this.sessionManager.GetCurrentSessionModelIndex(),
            systemPromptIndex
        )
        if (inputTemplate) {
            this.promptView.SetValue(inputTemplate)
        }
        
        if (this.mainView && this.mainView.contextViewController)
            this.mainView.contextViewController.UpdateContextView()

        ; Refresh the history view so the updated system prompt message is reflected
        if (this.mainView && this.mainView.historyViewController)
            this.mainView.historyViewController.UpdateChatHistoryView()

        if (this.mainView)
            this.mainView.SetSessionSelectValue(this.sessionManager.currentSessionIndex)
    }

    ReloadSettings(*) {
        this.reloadSettingsCommand.Execute()

        ; Refresh models menu
        this.menuView.RebuildModelMenu(this.configManager.modelDisplayNames, ObjBindMethod(this, "SelectModel"))

        ; Update current selection
        currentModelIndex := this.sessionManager.GetCurrentSessionModelIndex()
        if (currentModelIndex > this.configManager.models.Length) {
            currentModelIndex := 1
            this.selectModelCommand.Execute(1)
        }
        this.menuView.UpdateModelMenu(currentModelIndex, this.configManager.modelDisplayNames)

        ; Update system prompts
        currentSystemPrompt := this.promptView.GetSystemPromptValue()
        this.promptView.ClearSystemPrompt()
        this.promptView.AddSystemPrompts(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionModelIndex()))

        try {
            this.promptView.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.promptView.SetSystemPromptValue(1)
            this.changeSystemPromptCommand.Execute(1)
        }

        this.UpdateToolsMenuState()
        this.UpdateCompressionMenuState()
    }
}
