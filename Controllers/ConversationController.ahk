#Requires AutoHotkey 2.0

class ConversationController {
    controller := ""
    configManager := ""
    sessionManager := ""
    llmService := ""
    saveConversationCommand := ""
    loadConversationCommand := ""
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    view := ""

    __New(controller, view, configManager, sessionManager, llmService, menuController, saveConversationCommand, loadConversationCommand, compressHistoryCommand, extractLearningsCommand, resetAllCommand) {
        this.controller := controller
        this.view := view
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.menuController := menuController
        this.saveConversationCommand := saveConversationCommand
        this.loadConversationCommand := loadConversationCommand
        this.compressHistoryCommand := compressHistoryCommand
        this.extractLearningsCommand := extractLearningsCommand
        this.resetAllCommand := resetAllCommand
    }

    SystemPromptChanged(*) {
        this.sessionManager.SetCurrentSessionSystemPrompt(this.view.GetSystemPromptValue())

        ; Update the system prompt content
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        inputTemplate := this.configManager.GetInputTemplate(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        if (inputTemplate) {
            this.view.SetPromptValue(inputTemplate)
        }
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
        this.controller.contextViewController.UpdateContextView()
    }

    SessionChanged(*) {
        oldModelName := this.menuController.currentModelName

        ; Switch to new session
        this.sessionManager.SwitchSession(this.view.GetSessionSelectValue())

        this.controller.contextViewController.UpdateContextView()
        this.controller.historyViewController.UpdateChatHistoryView()

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]

        ; Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = currentModelIndex) {
                this.view.modelMenu.Check(modelName)
            } else {
                this.view.modelMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label if model changed
        if (oldModelName != newModelName) {
            try this.view.menuBar.Rename(oldModelName, newModelName)
            this.menuController.currentModelName := newModelName
        }

        ; Update system prompts for the selected LLM type
        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
        this.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

        ; Clear response field
        this.controller.RenderMarkdown("")

        this.menuController.UpdateCompressionMenuState()
    }

    ResetAll(*) {
        ; Reset current session
        this.resetAllCommand.Execute()

        ; Update UI
        this.controller.historyViewController.UpdateChatHistoryView()
        this.controller.contextViewController.UpdateContextView()

        ; Clear response and prompt
        this.controller.RenderMarkdown("")
    }

    CompressHistory(*) {
        ; Disable Ask LLM button while processing
        if (this.view.guiShown) {
            this.view.SetAskButtonText("Compressing...")
            this.view.SetAskButtonEnabled(false)
        }

        try {
            compressedMsg := this.compressHistoryCommand.Execute()

            if (compressedMsg != "") {
                 ; Update UI
                 this.controller.historyViewController.UpdateChatHistoryView()
                 this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(compressedMsg))
            }

        } catch as e {
            MsgBox("Compression failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.view.guiShown) {
                this.view.SetAskButtonText("Ask LLM")
                this.view.SetAskButtonEnabled(true)
            }
        }
    }

    ExtractLearnings(*) {
        ; Disable Ask LLM button while processing
        if (this.view.guiShown) {
            this.view.SetAskButtonText("Extracting...")
            this.view.SetAskButtonEnabled(false)
        }

        try {
            extractedNotes := this.extractLearningsCommand.Execute()

            if (extractedNotes != "") {
                this.controller.notesController.ShowNotes(extractedNotes)
            }

        } catch as e {
            MsgBox("Extraction failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.view.guiShown) {
                this.view.SetAskButtonText("Ask LLM")
                this.view.SetAskButtonEnabled(true)
            }
        }
    }

    SaveConversation(*) {
        selectedFile := FileSelect("S16", "conversation.json", "Save Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.saveConversationCommand.Execute(selectedFile)
            } catch as e {
                 MsgBox("Failed to save conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

    LoadConversation(*) {
        selectedFile := FileSelect("3", , "Load Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            try {
                this.loadConversationCommand.Execute(selectedFile)

                ; Update LLM Type
                currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
                for index, modelName in this.configManager.llmTypes {
                    if (index = currentModelIndex) {
                        this.view.modelMenu.Check(modelName)
                    } else {
                        this.view.modelMenu.Uncheck(modelName)
                    }
                }

                ; Update model name label
                oldModelName := this.menuController.currentModelName
                newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]
                try this.view.menuBar.Rename(oldModelName, newModelName)
                this.menuController.currentModelName := newModelName

                ; Update Session UI
                this.view.SetSessionSelectValue(this.sessionManager.currentSessionIndex)
                this.controller.contextViewController.UpdateContextView()

                ; Update System Prompt UI
                this.view.ClearSystemPrompt()
                this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
                this.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

                ; Update System Prompt Content
                systemPrompt := this.configManager.GetSystemPromptValue(
                    this.sessionManager.GetCurrentSessionLLMType(),
                    this.sessionManager.GetCurrentSessionSystemPrompt()
                )
                this.sessionManager.UpdateSystemPromptContent(systemPrompt)

                ; Update History View
                this.controller.historyViewController.UpdateChatHistoryView()
                
                ; Update Tools Menu
                this.menuController.UpdateToolsMenuState()

                ; Clear Response Area
                this.controller.RenderMarkdown("")

            } catch as e {
                MsgBox("Failed to load conversation: " . e.Message, "Error", "Iconx")
            }
        }
    }

    ReloadSettings(*) {
        ; Reload settings from disk
        this.configManager.Reload()

        ; Refresh LLM Type dropdown
        ; Refresh Model Menu
        this.view.modelMenu.Delete() ; Delete all items
        for index, modelName in this.configManager.llmTypes {
            this.view.modelMenu.Add(modelName, ObjBindMethod(this.menuController, "SelectModel"))
        }

        ; Restore model checkmark
        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.configManager.llmTypes.Length) {
            this.view.modelMenu.Check(this.configManager.llmTypes[currentModelIndex])
        } else {
            ; If former selection no longer exists, default to first
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.view.modelMenu.Check(this.configManager.llmTypes[1])
        }

        ; Update MenuBar label
        oldModelName := this.menuController.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.view.menuBar.Rename(oldModelName, newModelName)
        this.menuController.currentModelName := newModelName

        ; Refresh System Prompt Combo
        currentSystemPrompt := this.view.GetSystemPromptValue()

        this.view.ClearSystemPrompt()
        this.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        ; Try to preserve current selection, otherwise default to first
        try {
            this.view.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.view.SetSystemPromptValue(1)
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.menuController.UpdateToolsMenuState()
        this.menuController.UpdateCompressionMenuState()
    }
}
