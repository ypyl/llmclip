#Requires AutoHotkey 2.0

class ChatManager {
    controller := ""
    configManager := ""
    sessionManager := ""
    llmService := ""
    contextManager := ""
    
    ; Commands
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    confirmToolCommand := ""
    regenerateMessageCommand := ""

    __New(controller, configManager, sessionManager, llmService, contextManager, sendToLLMCommand, sendBatchToLLMCommand, confirmToolCommand, regenerateMessageCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.contextManager := contextManager
        
        this.sendToLLMCommand := sendToLLMCommand
        this.sendBatchToLLMCommand := sendBatchToLLMCommand
        this.confirmToolCommand := confirmToolCommand
        this.regenerateMessageCommand := regenerateMessageCommand
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state
        this.controller.batchModeEnabled := !this.controller.batchModeEnabled
        
        ; Update menu checkmark
        this.controller.view.UpdateBatchModeMenu(this.controller.batchModeEnabled)
    }

    HandleToolConfirmation() {
        if (this.confirmToolCommand.Execute()) {
            this.controller.historyViewController.UpdateChatHistoryView()
            if (this.sessionManager.GetCurrentSessionMessages().Length > 0) {
                lastMsg := this.sessionManager.GetCurrentSessionMessages()[-1]
                this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(lastMsg))
            }
        }
        this.controller.view.SetAskButtonText("Ask LLM")
    }

    HandleCancellation() {
        if (this.llmService) {
            this.llmService.Cancel()
        }
        this.controller.view.SetAskButtonText("Ask LLM")
    }

    HandleRegenerationOrEdit(promptText) {
        focusedRow := this.controller.view.GetSelectedHistoryIndex()
        
        result := this.regenerateMessageCommand.Execute(
            focusedRow, 
            promptText, 
            () => this.controller.contextViewController.GetCheckedImages()
        )

        if (result.status == "load_to_prompt") {
            this.controller.view.SetPromptValue(result.text)
            return true
        } else if (result.status == "sent") {
            this.SendToLLM()
            this.controller.view.ClearPrompt()
            this.controller.view.DeselectHistoryItem(focusedRow)
            return true
        }

        return false
    }

    AskToLLM(*) {
        ; 1. Check current button state
        btnText := this.controller.view.GetAskButtonText()
        if (btnText == "Confirm Tool Run") {
            this.HandleToolConfirmation()
            return
        }
        if (btnText == "Cancel") {
            this.HandleCancellation()
            return
        }

        promptText := this.controller.view.GetPromptValue()

        ; 2. Check for regeneration or edit case
        if (this.HandleRegenerationOrEdit(promptText)) {
            return
        }

        ; 3. Check for Batch Mode
        if (this.controller.batchModeEnabled) {
            this.SendBatchToLLM(promptText)
            return
        }

        ; 4. Normal Send Mode
        isImageEnabled := this.configManager.IsImageInputEnabled(this.sessionManager.GetCurrentSessionLLMType())
        images := isImageEnabled ? this.controller.contextViewController.GetCheckedImages() : []
        userMessageContent := this.sessionManager.BuildUserMessage(promptText, images)

        hasContext := this.controller.contextViewController.HasAnyCheckedItem()
        if (userMessageContent.Length > 0 || hasContext) {
            this.sessionManager.GetCurrentSessionMessages().Push(ChatMessage("user", userMessageContent))
        }

        this.SendToLLM()
        
        this.controller.view.ClearPrompt()
        if (this.controller.recordingService.isRecording) {
            this.controller.stopRecordingCommand.Execute()
            this.controller.UpdateUiBasesOnRecordingStatus()
        }
    }

    SendBatchToLLM(promptText) {
        checkedItems := this.controller.contextViewController.GetAllCheckedContextItems()
        if (checkedItems.Length == 0) {
            MsgBox("Please check at least one item in the context list for batch mode.", "No Items Selected", "Iconi")
            return
        }

        ; Update UI to show "Cancel"
        if (this.controller.view.gui) {
            this.controller.view.SetAskButtonText("Cancel")
        }

        ; Prepare context providers (logic-only data)
        contextProviders := []
        for item in checkedItems {
            contextProviders.Push({
                item: item,
                text: this.controller.contextViewController.GetTextFromContextItem(item)
            })
        }

        try {
            this.sendBatchToLLMCommand.Execute(
                promptText, 
                contextProviders, 
                (label, messages) => this.controller.historyViewController.UpdateChatHistoryView(),
                () => (this.controller.view.askButton.Text != "Cancel")
            )
        } catch as e {
            if (e.Message != "Request cancelled")
                MsgBox("Batch processing error: " . e.Message, "Error", "Iconx")
        } finally {
            if (this.controller.view.gui) {
                this.controller.view.SetAskButtonText("Ask LLM")
                this.controller.view.SetAskButtonEnabled(true)
            }
            this.controller.view.ClearPrompt()
            this.controller.historyViewController.UpdateChatHistoryView()
        }
    }

    SendToLLM() {
        ; Capture GUI dependencies
        context := this.sessionManager.GetCurrentSessionContext()
        contextBoxValue := this.controller.view.GetContextBoxValue()
        additionalContext := this.controller.contextViewController.BuildAdditionalContextMessage(context, contextBoxValue)

        ; Update UI State
        if (this.controller.view.gui) {
            this.controller.view.SetAskButtonText("Cancel")
        }

        try {
            this.sendToLLMCommand.Execute(additionalContext)
            
            ; Check for unexecuted Tool Calls to update button text
            if (this.sessionManager.HasUnexecutedToolCalls()) {
                this.controller.view.SetAskButtonText("Confirm Tool Run")
            } else {
                this.controller.view.SetAskButtonText("Ask LLM")
            }
        } catch as e {
            if (e.Message != "Request cancelled")
                throw e
        } finally {
            ; Re-enable/Reset Ask LLM button
            if (this.controller.view.guiShown) {
                if (this.controller.view.GetAskButtonText() == "Cancel") {
                    this.controller.view.SetAskButtonText("Ask LLM")
                }
                this.controller.view.SetAskButtonEnabled(true)
            }
        }

        ; Update UI views
        this.controller.historyViewController.UpdateChatHistoryView()
        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messages.Length > 0) {
            this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(messages[messages.Length]))
        }

        ; Uncheck images after sending
        this.controller.contextViewController.UncheckSentImages()
    }
}
