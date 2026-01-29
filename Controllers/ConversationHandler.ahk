#Requires AutoHotkey 2.0

class ConversationHandler {
    controller := ""
    configManager := ""
    sessionManager := ""
    llmService := ""
    saveConversationCommand := ""

    __New(controller, configManager, sessionManager, llmService, menuManager, saveConversationCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.menuManager := menuManager
        this.saveConversationCommand := saveConversationCommand
    }

    SystemPromptChanged(*) {
        this.sessionManager.SetCurrentSessionSystemPrompt(this.controller.view.gui["SystemPrompt"].Value)

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
            this.controller.view.gui["PromptEdit"].Value := inputTemplate
        }
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
        this.controller.ContextViewControllerValue.UpdateContextView()
    }

    SessionChanged(*) {
        oldModelName := this.controller.currentModelName

        ; Switch to new session
        this.sessionManager.SwitchSession(this.controller.view.gui["SessionSelect"].Value)

        this.controller.ContextViewControllerValue.UpdateContextView()
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()

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
        systemPromptCombo := this.controller.view.gui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
        systemPromptCombo.Value := this.sessionManager.GetCurrentSessionSystemPrompt()

        ; Clear response field
        this.controller.RenderMarkdown("")

        this.menuManager.UpdateCompressionMenuState()
    }

    ResetAll(*) {
        ; Reset current session
        this.sessionManager.ResetCurrentSession()

        ; Update UI
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
        this.controller.ContextViewControllerValue.UpdateContextView()

        ; Clear response and prompt
        this.controller.RenderMarkdown("")
    }

    CompressHistory(*) {
        messages := this.sessionManager.GetCurrentSessionMessages()

        if (messages.Length < 3) {
            MsgBox("Not enough messages to compress. Need at least 2 messages besides the system message.", "Info", "Iconi")
            return
        }

        conversationText := this.sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
            MsgBox("No conversation history to compress.", "Info", "Iconi")
            return
        }

        compressionPrompt := this.configManager.GetCompressionPrompt(this.sessionManager.GetCurrentSessionLLMType())

        if (compressionPrompt == "") {
            MsgBox("Compression prompt not configured for this provider.", "Info", "Iconi")
            return
        }

        compressionPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Disable Ask LLM button while processing
        if (this.controller.view.gui) {
            this.controller.view.askButton.Text := "Compressing..."
            this.controller.view.askButton.Enabled := false
        }

        try {
            compressedMsg := this.llmService.CompressHistory(this.sessionManager)

            if (compressedMsg != "") {
                 ; Update UI
                 this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
                 this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(compressedMsg))
            }

        } catch as e {
            MsgBox("Compression failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.controller.view.gui) {
                this.controller.view.askButton.Text := "Ask LLM"
                this.controller.view.askButton.Enabled := true
            }
        }
    }

    ExtractLearnings(*) {
        messages := this.sessionManager.GetCurrentSessionMessages()

        if (messages.Length < 2) {
            MsgBox("Not enough conversation history to extract notes.", "Info", "Iconi")
            return
        }

        conversationText := this.sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
            MsgBox("No conversation history to extract from.", "Info", "Iconi")
            return
        }

        learningsPrompt := this.configManager.GetLearningsPrompt(this.sessionManager.GetCurrentSessionLLMType())
        learningsPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Disable Ask LLM button while processing
        if (this.controller.view.gui) {
            this.controller.view.askButton.Text := "Extracting..."
            this.controller.view.askButton.Enabled := false
        }

        try {
            extractedNotes := this.llmService.ExtractLearnings(this.sessionManager)

            if (extractedNotes != "") {
                UIBuilder.ShowNotesWindow(extractedNotes)
            }

        } catch as e {
            MsgBox("Extraction failed: " . e.Message, "Error", "Iconx")
        } finally {
            ; Re-enable Ask LLM button
            if (this.controller.view.gui) {
                this.controller.view.askButton.Text := "Ask LLM"
                this.controller.view.askButton.Enabled := true
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
                fileContent := FileRead(selectedFile)
                state := JSON.Load(fileContent)

                this.sessionManager.ImportSessionState(state)

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
                this.controller.view.gui["SessionSelect"].Value := this.sessionManager.currentSessionIndex
                this.controller.ContextViewControllerValue.UpdateContextView()

                ; Update System Prompt UI
                systemPromptCombo := this.controller.view.gui["SystemPrompt"]
                systemPromptCombo.Delete()
                systemPromptCombo.Add(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
                systemPromptCombo.Value := this.sessionManager.GetCurrentSessionSystemPrompt()

                ; Update System Prompt Content
                systemPrompt := this.configManager.GetSystemPromptValue(
                    this.sessionManager.GetCurrentSessionLLMType(),
                    this.sessionManager.GetCurrentSessionSystemPrompt()
                )
                this.sessionManager.UpdateSystemPromptContent(systemPrompt)

                ; Update History View
                this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
                
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
        systemPromptCombo := this.controller.view.gui["SystemPrompt"]
        currentSystemPrompt := systemPromptCombo.Value

        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.configManager.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

        ; Try to preserve current selection, otherwise default to first
        try {
            systemPromptCombo.Value := currentSystemPrompt
        } catch {
            systemPromptCombo.Value := 1
            this.sessionManager.SetCurrentSessionSystemPrompt(1)
        }

        this.menuManager.UpdateToolsMenuState()
        this.menuManager.UpdateCompressionMenuState()
    }
}
