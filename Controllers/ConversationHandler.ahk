#Requires AutoHotkey 2.0

class ConversationHandler {
    controller := ""
    appSettings := ""
    sessionManager := ""
    llmService := ""
    menuManager := ""

    __New(controller, appSettings, sessionManager, llmService, menuManager) {
        this.controller := controller
        this.appSettings := appSettings
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.menuManager := menuManager
    }

    SystemPromptChanged(*) {
        this.sessionManager.SetCurrentSessionSystemPrompt(this.controller.MyGui["SystemPrompt"].Value)

        ; Update the system prompt content
        systemPrompt := this.appSettings.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        inputTemplate := this.appSettings.GetInputTemplate(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        if (inputTemplate) {
            this.controller.MyGui["PromptEdit"].Value := inputTemplate
        }
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)
        this.controller.ContextViewControllerValue.UpdateContextView()
    }

    SessionChanged(*) {
        oldModelName := this.controller.currentModelName

        ; Switch to new session
        this.sessionManager.SwitchSession(this.controller.MyGui["SessionSelect"].Value)

        this.controller.ContextViewControllerValue.UpdateContextView()
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()

        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        newModelName := "Model: " . this.appSettings.llmTypes[currentModelIndex]

        ; Update menu checkmarks
        for index, modelName in this.appSettings.llmTypes {
            if (index = currentModelIndex) {
                this.controller.ModelMenu.Check(modelName)
            } else {
                this.controller.ModelMenu.Uncheck(modelName)
            }
        }

        ; Update menu bar label if model changed
        if (oldModelName != newModelName) {
            try this.controller.MyMenuBar.Rename(oldModelName, newModelName)
            this.controller.currentModelName := newModelName
        }

        ; Update system prompts for the selected LLM type
        systemPromptCombo := this.controller.MyGui["SystemPrompt"]
        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.appSettings.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
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

        compressionPrompt := this.appSettings.GetCompressionPrompt(this.sessionManager.GetCurrentSessionLLMType())

        if (compressionPrompt == "") {
            MsgBox("Compression prompt not configured for this provider.", "Info", "Iconi")
            return
        }

        compressionPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Disable Ask LLM button while processing
        if (this.controller.MyGui) {
            this.controller.askButton.Text := "Compressing..."
            this.controller.askButton.Enabled := false
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
            if (this.controller.MyGui) {
                this.controller.askButton.Text := "Ask LLM"
                this.controller.askButton.Enabled := true
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

        learningsPrompt := this.appSettings.GetLearningsPrompt(this.sessionManager.GetCurrentSessionLLMType())
        learningsPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Disable Ask LLM button while processing
        if (this.controller.MyGui) {
            this.controller.askButton.Text := "Extracting..."
            this.controller.askButton.Enabled := false
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
            if (this.controller.MyGui) {
                this.controller.askButton.Text := "Ask LLM"
                this.controller.askButton.Enabled := true
            }
        }
    }

    SaveConversation(*) {
        jsonStr := this.sessionManager.ExportSessionState()

        selectedFile := FileSelect("S16", "conversation.json", "Save Conversation", "JSON Files (*.json)")
        if (selectedFile) {
            if (FileExist(selectedFile)) {
                FileDelete(selectedFile)
            }
            FileAppend(jsonStr, selectedFile)
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
                for index, modelName in this.appSettings.llmTypes {
                    if (index = currentModelIndex) {
                        this.controller.ModelMenu.Check(modelName)
                    } else {
                        this.controller.ModelMenu.Uncheck(modelName)
                    }
                }

                ; Update model name label
                oldModelName := this.controller.currentModelName
                newModelName := "Model: " . this.appSettings.llmTypes[currentModelIndex]
                try this.controller.MyMenuBar.Rename(oldModelName, newModelName)
                this.controller.currentModelName := newModelName

                ; Update Session UI
                this.controller.MyGui["SessionSelect"].Value := this.sessionManager.currentSessionIndex
                this.controller.ContextViewControllerValue.UpdateContextView()

                ; Update System Prompt UI
                systemPromptCombo := this.controller.MyGui["SystemPrompt"]
                systemPromptCombo.Delete()
                systemPromptCombo.Add(this.appSettings.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))
                systemPromptCombo.Value := this.sessionManager.GetCurrentSessionSystemPrompt()

                ; Update System Prompt Content
                systemPrompt := this.appSettings.GetSystemPromptValue(
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
        this.appSettings.Reload()

        ; Refresh LLM Type dropdown
        ; Refresh Model Menu
        this.controller.ModelMenu.Delete() ; Delete all items
        for index, modelName in this.appSettings.llmTypes {
            this.controller.ModelMenu.Add(modelName, ObjBindMethod(this.menuManager, "SelectModel"))
        }

        ; Restore model checkmark
        currentModelIndex := this.sessionManager.GetCurrentSessionLLMType()
        if (currentModelIndex <= this.appSettings.llmTypes.Length) {
            this.controller.ModelMenu.Check(this.appSettings.llmTypes[currentModelIndex])
        } else {
            ; If former selection no longer exists, default to first
            this.sessionManager.SetCurrentSessionLLMType(1)
            this.controller.ModelMenu.Check(this.appSettings.llmTypes[1])
        }

        ; Update MenuBar label
        oldModelName := this.controller.currentModelName
        newModelName := "Model: " . this.appSettings.llmTypes[this.sessionManager.GetCurrentSessionLLMType()]
        try this.controller.MyMenuBar.Rename(oldModelName, newModelName)
        this.controller.currentModelName := newModelName

        ; Refresh System Prompt Combo
        systemPromptCombo := this.controller.MyGui["SystemPrompt"]
        currentSystemPrompt := systemPromptCombo.Value

        systemPromptCombo.Delete()
        systemPromptCombo.Add(this.appSettings.GetSystemPromptNames(this.sessionManager.GetCurrentSessionLLMType()))

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
