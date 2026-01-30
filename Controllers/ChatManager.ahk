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

    __New(controller, configManager, sessionManager, llmService, contextManager, sendToLLMCommand, sendBatchToLLMCommand, confirmToolCommand) {
        this.controller := controller
        this.configManager := configManager
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.contextManager := contextManager
        
        this.sendToLLMCommand := sendToLLMCommand
        this.sendBatchToLLMCommand := sendBatchToLLMCommand
        this.confirmToolCommand := confirmToolCommand
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state
        this.controller.batchModeEnabled := !this.controller.batchModeEnabled
        
        ; Update menu checkmark
        if (this.controller.batchModeEnabled) {
            this.controller.view.modeMenu.Check("Batch Mode")
        } else {
            this.controller.view.modeMenu.Uncheck("Batch Mode")
        }
    }

    HandleToolConfirmation() {
        if (this.confirmToolCommand.Execute()) {
            this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
            if (this.sessionManager.GetCurrentSessionMessages().Length > 0) {
                lastMsg := this.sessionManager.GetCurrentSessionMessages()[-1]
                this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(lastMsg))
            }
        }
        this.controller.view.gui["AskLLM"].Text := "Ask LLM"
    }

    HandleCancellation() {
        if (this.llmService) {
            this.llmService.Cancel()
        }
        if (this.controller.view.gui) {
            this.controller.view.gui["AskLLM"].Text := "Ask LLM"
        }
    }

    HandleRegenerationOrEdit(promptText) {
        messages := this.sessionManager.GetCurrentSessionMessages()
        chatHistory := this.controller.view.gui["ChatHistory"]
        focused_row := chatHistory.GetNext()

        if (focused_row > 0) {
            selectedMsg := messages[focused_row]

            if (selectedMsg.Role == "user") {
                if (promptText == "") {
                    ; Regeneration case: Load message content into prompt for editing
                    this.controller.view.gui["PromptEdit"].Value := this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg)
                    return true
                } else {
                    ; Edit Mode Logic (kept in controller for now as it manipulates history directly)
                    isImageEnabled := this.configManager.IsImageInputEnabled(this.sessionManager.GetCurrentSessionLLMType())
                    images := isImageEnabled ? this.controller.ContextViewControllerValue.GetCheckedImages() : []
                    newContent := this.sessionManager.BuildUserMessage(promptText, images)

                    ; Check if this is the first user message with context
                    isFirstUserMsg := false
                    for i, msg in messages {
                        if (msg.Role == "user") {
                            isFirstUserMsg := (msg == selectedMsg)
                            break
                        }
                    }

                    ; If first user message with context, preserve the context
                    if (isFirstUserMsg && selectedMsg.AdditionalProperties.Has("hasContext")
                        && selectedMsg.AdditionalProperties["hasContext"]
                        && selectedMsg.Contents.Length > 0 && (selectedMsg.Contents[1] is TextContent)) {
                        contextText := selectedMsg.Contents[1]
                        newContentWithContext := [contextText]
                        for part in newContent {
                            newContentWithContext.Push(part)
                        }
                        selectedMsg.Contents := newContentWithContext
                    } else {
                        selectedMsg.Contents := newContent
                    }

                    ; Truncate history after this message
                    if (this.sessionManager.TruncateMessages(focused_row)) {
                        this.SendToLLM()
                        this.controller.view.gui["PromptEdit"].Value := ""
                        chatHistory.Modify(focused_row, "-Select")
                        return true
                    }
                }
            }
        }
        return false
    }

    AskToLLM(*) {
        ; 1. Check current button state
        btnText := this.controller.view.gui["AskLLM"].Text
        if (btnText == "Confirm Tool Run") {
            this.HandleToolConfirmation()
            return
        }
        if (btnText == "Cancel") {
            this.HandleCancellation()
            return
        }

        promptText := this.controller.view.gui["PromptEdit"].Value

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
        images := isImageEnabled ? this.controller.ContextViewControllerValue.GetCheckedImages() : []
        userMessageContent := this.sessionManager.BuildUserMessage(promptText, images)

        hasContext := this.controller.ContextViewControllerValue.HasAnyCheckedItem()
        if (userMessageContent.Length > 0 || hasContext) {
            this.sessionManager.GetCurrentSessionMessages().Push(ChatMessage("user", userMessageContent))
        }

        this.SendToLLM()
        
        this.controller.view.gui["PromptEdit"].Value := ""  ; Clear prompt field
        if (this.controller.TrayManagerValue.isRecording) {
            this.controller.TrayManagerValue.StopRecording(this.sessionManager)
        }
    }

    SendBatchToLLM(promptText) {
        checkedItems := this.controller.ContextViewControllerValue.GetAllCheckedContextItems()
        if (checkedItems.Length == 0) {
            MsgBox("Please check at least one item in the context list for batch mode.", "No Items Selected", "Iconi")
            return
        }

        ; Update UI to show "Cancel"
        if (this.controller.view.gui) {
            this.controller.view.askButton.Text := "Cancel"
        }

        ; Prepare context providers (logic-only data)
        contextProviders := []
        for item in checkedItems {
            contextProviders.Push({
                item: item,
                text: this.controller.ContextViewControllerValue.GetTextFromContextItem(item)
            })
        }

        try {
            this.sendBatchToLLMCommand.Execute(
                promptText, 
                contextProviders, 
                (label, messages) => this.controller.HistoryViewControllerValue.UpdateChatHistoryView(),
                () => (this.controller.view.askButton.Text != "Cancel")
            )
        } catch as e {
            if (e.Message != "Request cancelled")
                MsgBox("Batch processing error: " . e.Message, "Error", "Iconx")
        } finally {
            if (this.controller.view.gui) {
                this.controller.view.askButton.Text := "Ask LLM"
                this.controller.view.askButton.Enabled := true
            }
            this.controller.view.gui["PromptEdit"].Value := ""
            this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
        }
    }

    SendToLLM() {
        ; Capture GUI dependencies
        context := this.sessionManager.GetCurrentSessionContext()
        contextBoxValue := this.controller.view.gui["ContextBox"].Value
        additionalContext := this.controller.ContextViewControllerValue.BuildAdditionalContextMessage(context, contextBoxValue)

        ; Update UI State
        if (this.controller.view.gui) {
            this.controller.view.askButton.Text := "Cancel"
        }

        try {
            this.sendToLLMCommand.Execute(additionalContext)
            
            ; Check for unexecuted Tool Calls to update button text
            if (this.sessionManager.HasUnexecutedToolCalls()) {
                this.controller.view.gui["AskLLM"].Text := "Confirm Tool Run"
            } else {
                this.controller.view.gui["AskLLM"].Text := "Ask LLM"
            }
        } catch as e {
            if (e.Message != "Request cancelled")
                throw e
        } finally {
            ; Re-enable/Reset Ask LLM button
            if (this.controller.view.gui) {
                if (this.controller.view.gui["AskLLM"].Text == "Cancel") {
                    this.controller.view.gui["AskLLM"].Text := "Ask LLM"
                }
                this.controller.view.askButton.Enabled := true
            }
        }

        ; Update UI views
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messages.Length > 0) {
            this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(messages[messages.Length]))
        }

        ; Uncheck images after sending
        this.controller.ContextViewControllerValue.UncheckSentImages()
    }
}
