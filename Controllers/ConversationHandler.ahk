#Requires AutoHotkey 2.0

class ConversationHandler {
    controller := ""
    configManager := ""
    sessionManager := ""
    llmService := ""
    saveConversationCommand := ""
    loadConversationCommand := ""
    compressHistoryCommand := ""
    extractLearningsCommand := ""
    resetAllCommand := ""

    __New(controller, configManager, sessionManager, llmService, menuManager, saveConversationCommand, loadConversationCommand, compressHistoryCommand, extractLearningsCommand, resetAllCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.menuManager := menuManager
        this.saveConversationCommand := saveConversationCommand
        this.loadConversationCommand := loadConversationCommand
        this.compressHistoryCommand := compressHistoryCommand
        this.extractLearningsCommand := extractLearningsCommand
        this.resetAllCommand := resetAllCommand
    }

    SystemPromptChanged(*) {
        this.sessionManager.SetCurrentSessionSystemPrompt(this.controller.view.GetSystemPromptValue())

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
            this.controller.view.SetPromptValue(inputTemplate)
        }
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
        this.controller.contextViewController.UpdateContextView()
    }

    SessionChanged(*) {
        oldModelName := this.controller.currentModelName

        ; Switch to new session
        this.sessionManager.SwitchSession(this.controller.view.GetSessionSelectValue())

        this.controller.contextViewController.UpdateContextView()
        this.controller.historyViewController.UpdateChatHistoryView()

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]

        ; Update menu checkmarks
        for index, modelName in this.configManager.llmTypes {
            if (index = currentModelIndex) {
                this.controller.view.modelMenu.Check(modelName)
            } else {
                this.controller.view.modelMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label if model changed
        if (oldModelName != newModelName) {
            try this.controller.view.menuBar.Rename(oldModelName, newModelName)
            this.controller.currentModelName := newModelName
        }

        ; Update system prompts for the selected LLM type
        this.controller.view.ClearSystemPrompt()
        this.controller.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
        this.controller.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

        ; Clear response field
        this.controller.RenderMarkdown("")

        this.menuManager.UpdateCompressionMenuState()
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
        if (this.controller.view.guiShown) {
            this.controller.view.SetAskButtonText("Compressing...")
            this.controller.view.SetAskButtonEnabled(false)
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
            if (this.controller.view.guiShown) {
                this.controller.view.SetAskButtonText("Ask LLM")
                this.controller.view.SetAskButtonEnabled(true)
            }
        }
    }

    ExtractLearnings(*) {
        ; Disable Ask LLM button while processing
        if (this.controller.view.guiShown) {
            this.controller.view.SetAskButtonText("Extracting...")
            this.controller.view.SetAskButtonEnabled(false)
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
            if (this.controller.view.guiShown) {
                this.controller.view.SetAskButtonText("Ask LLM")
                this.controller.view.SetAskButtonEnabled(true)
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
                        this.controller.view.modelMenu.Check(modelName)
                    } else {
                        this.controller.view.modelMenu.Uncheck(modelName)
                    }
                }

                ; Update model name label
                oldModelName := this.controller.currentModelName
                newModelName := "Model: " . this.configManager.llmTypes[currentModelIndex]
                try this.controller.view.menuBar.Rename(oldModelName, newModelName)
                this.controller.currentModelName := newModelName

                ; Update Session UI
                this.controller.view.SetSessionSelectValue(this.sessionManager.currentSessionIndex)
                this.controller.contextViewController.UpdateContextView()

                ; Update System Prompt UI
                this.controller.view.ClearSystemPrompt()
                this.controller.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
                this.controller.view.SetSystemPromptValue(this.sessionManager.GetCurrentSessionSystemPrompt())

                ; Update System Prompt Content
                systemPrompt := this.configManager.GetSystemPromptValue(
                    this.sessionManager.GetCurrentSessionLLMType(),
                    this.sessionManager.GetCurrentSessionSystemPrompt()
                )
                this.sessionManager.UpdateSystemPromptContent(systemPrompt)

                ; Update History View
                this.controller.historyViewController.UpdateChatHistoryView()
                
                ; Update Tools Menu
                this.menuManager.UpdateToolsMenuState()

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
        this.controller.view.modelMenu.Delete() ; Delete all items
        for index, modelName in this.configManager.llmTypes {
            this.controller.view.modelMenu.Add(modelName, ObjBindMethod(this.menuManager, "SelectModel"))
        }

        ; Restore model checkmark
        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.configManager.llmTypes.Length) {
            this.controller.view.modelMenu.Check(this.configManager.llmTypes[currentModelIndex])
        } else {
            ; If former selection no longer exists, default to first
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.controller.view.modelMenu.Check(this.configManager.llmTypes[1])
        }

        ; Update MenuBar label
        oldModelName := this.controller.currentModelName
        newModelName := "Model: " . this.configManager.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.controller.view.menuBar.Rename(oldModelName, newModelName)
        this.controller.currentModelName := newModelName

        ; Refresh System Prompt Combo
        currentSystemPrompt := this.controller.view.GetSystemPromptValue()

        this.controller.view.ClearSystemPrompt()
        this.controller.view.AddSystemPromptItems(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        ; Try to preserve current selection, otherwise default to first
        try {
            this.controller.view.SetSystemPromptValue(currentSystemPrompt)
        } catch {
            this.controller.view.SetSystemPromptValue(1)
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.menuManager.UpdateToolsMenuState()
        this.menuManager.UpdateCompressionMenuState()
    }
}
