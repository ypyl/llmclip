#Requires AutoHotkey 2.0

class ChatController {
    controller := ""
    configManager := ""
    sessionManager := ""
    llmService := ""
    contextManager := ""
    
    view := ""
    
    ; Commands
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    confirmToolCommand := ""
    regenerateMessageCommand := ""
    messagePresentationService := ""

    __New(controller, view, configManager, sessionManager, llmService, contextManager, messagePresentationService, sendToLLMCommand, sendBatchToLLMCommand, confirmToolCommand, regenerateMessageCommand) {
        this.controller := controller
        this.view := view
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.contextManager := contextManager
        this.messagePresentationService := messagePresentationService
        
        this.sendToLLMCommand := sendToLLMCommand
        this.sendBatchToLLMCommand := sendBatchToLLMCommand
        this.confirmToolCommand := confirmToolCommand
        this.regenerateMessageCommand := regenerateMessageCommand
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state
        this.controller.batchModeEnabled := !this.controller.batchModeEnabled
        
        ; Update menu checkmark
        this.view.UpdateBatchModeMenu(this.controller.batchModeEnabled)
    }

    HandleToolConfirmation() {
        if (this.confirmToolCommand.Execute()) {
            this.controller.historyViewController.UpdateChatHistoryView()
            if (this.sessionManager.GetCurrentSessionMessages().Length > 0) {
                lastMsg := this.sessionManager.GetCurrentSessionMessages()[-1]
                this.controller.RenderMarkdown(this.messagePresentationService.GetMessageAsString(lastMsg))
            }
        }
        this.view.SetAskButtonText("Ask LLM")
    }

    HandleCancellation() {
        if (this.llmService) {
            this.llmService.Cancel()
        }
        this.view.SetAskButtonText("Ask LLM")
    }

    HandleRegenerationOrEdit(promptText) {
        focusedRow := this.view.GetSelectedHistoryIndex()
        
        result := this.regenerateMessageCommand.Execute(
            focusedRow, 
            promptText, 
            () => this.controller.contextViewController.GetCheckedImages()
        )

        if (result.status == "load_to_prompt") {
            this.view.SetPromptValue(result.text)
            return true
        } else if (result.status == "sent") {
            this.SendToLLM()
            this.view.ClearPrompt()
            this.view.DeselectHistoryItem(focusedRow)
            return true
        }

        return false
    }

    AskToLLM(*) {
        ; 1. Check current button state
        btnText := this.view.GetAskButtonText()
        if (btnText == "Confirm Tool Run") {
            this.HandleToolConfirmation()
            return
        }
        if (btnText == "Cancel") {
            this.HandleCancellation()
            return
        }

        promptText := this.view.GetPromptValue()

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
        
        this.view.ClearPrompt()
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
        if (this.view.gui) {
            this.view.SetAskButtonText("Cancel")
        }

        ; Prepare context providers (logic-only data)
        contextProviders := []
        for item in checkedItems {
            contextProviders.Push({
                item: item,
                text: this.contextManager.GetTextFromContextItem(item, (url) => this.controller.webViewManager.LoadArticle(url))
            })
        }

        try {
            this.sendBatchToLLMCommand.Execute(
                promptText, 
                contextProviders, 
                (label, messages) => this.controller.historyViewController.UpdateChatHistoryView(),
                () => (this.view.askButton.Text != "Cancel")
            )
        } catch as e {
            if (e.Message != "Request cancelled")
                MsgBox("Batch processing error: " . e.Message, "Error", "Iconx")
        } finally {
            if (this.view.gui) {
                this.view.SetAskButtonText("Ask LLM")
                this.view.SetAskButtonEnabled(true)
            }
            this.view.ClearPrompt()
            this.controller.historyViewController.UpdateChatHistoryView()
        }
    }

    SendToLLM() {
        ; Capture GUI dependencies
        context := this.sessionManager.GetCurrentSessionContext()
        
        checkedIndices := []
        loop context.Length {
            if (this.view.IsContextItemChecked(A_Index)) {
                checkedIndices.Push(A_Index)
            }
        }
        
        selectedIndices := []
        if (selectedIndex := this.view.GetContextBoxValue()) {
            selectedIndices.Push(selectedIndex)
        }

        additionalContext := this.contextManager.BuildPromptContext(
            context, 
            checkedIndices, 
            selectedIndices,
            (url) => this.controller.webViewManager.LoadArticle(url)
        )

        ; Update UI State
        if (this.view.gui) {
            this.view.SetAskButtonText("Cancel")
        }

        try {
            this.sendToLLMCommand.Execute(additionalContext)
            
            ; Check for unexecuted Tool Calls to update button text
            if (this.sessionManager.HasUnexecutedToolCalls()) {
                this.view.SetAskButtonText("Confirm Tool Run")
            } else {
                this.view.SetAskButtonText("Ask LLM")
            }
        } catch as e {
            if (e.Message != "Request cancelled")
                throw e
        } finally {
            ; Re-enable/Reset Ask LLM button
            if (this.view.guiShown) {
                if (this.view.GetAskButtonText() == "Cancel") {
                    this.view.SetAskButtonText("Ask LLM")
                }
                this.view.SetAskButtonEnabled(true)
            }
        }

        ; Update UI views
        this.controller.historyViewController.UpdateChatHistoryView()
        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messages.Length > 0) {
            this.controller.RenderMarkdown(this.messagePresentationService.GetMessageAsString(messages[messages.Length]))
        }

        ; Uncheck images after sending
        this.controller.contextViewController.UncheckSentImages()
    }
}
