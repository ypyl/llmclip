#Requires AutoHotkey 2.0

class ChatController {
    controller := ""
    view := ""
    
    ; Commands
    sendToLLMCommand := ""
    sendBatchToLLMCommand := ""
    confirmToolCommand := ""
    regenerateMessageCommand := ""
    renderMarkdownCommand := ""
    cancelGenerationCommand := ""
    renderLastMessageCommand := ""

    ; Internal State
    processingState := "idle" ; idle, processing, tool_pending

    __New(controller, view, sendToLLMCommand, sendBatchToLLMCommand, confirmToolCommand, regenerateMessageCommand, renderMarkdownCommand, cancelGenerationCommand, renderLastMessageCommand) {
        this.controller := controller
        this.view := view
        
        this.sendToLLMCommand := sendToLLMCommand
        this.sendBatchToLLMCommand := sendBatchToLLMCommand
        this.confirmToolCommand := confirmToolCommand
        this.regenerateMessageCommand := regenerateMessageCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.cancelGenerationCommand := cancelGenerationCommand
        this.renderLastMessageCommand := renderLastMessageCommand
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
            this.renderLastMessageCommand.Execute()
        }
        this.SetProcessingState("idle")
    }

    HandleCancellation() {
        this.cancelGenerationCommand.Execute()
        this.SetProcessingState("idle")
    }

    SetProcessingState(state) {
        this.processingState := state
        
        if (state == "idle") {
            this.view.SetAskButtonText("Ask LLM")
            this.view.SetAskButtonEnabled(true)
        } else if (state == "processing") {
            this.view.SetAskButtonText("Cancel")
            this.view.SetAskButtonEnabled(true)
        } else if (state == "tool_pending") {
            this.view.SetAskButtonText("Confirm Tool Run")
            this.view.SetAskButtonEnabled(true)
        }
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
            this.SendToLLM("", true)
            this.view.ClearPrompt()
            this.view.DeselectHistoryItem(focusedRow)
            return true
        }

        return false
    }

    AskToLLM(*) {
        ; 1. Check current state
        if (this.processingState == "tool_pending") {
            this.HandleToolConfirmation()
            return
        }
        if (this.processingState == "processing") {
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
        this.SendToLLM(promptText)
        
        this.view.ClearPrompt()
        if (this.controller.recordingService.isRecording) {
            this.controller.stopRecordingCommand.Execute()
            this.controller.UpdateUiBasesOnRecordingStatus()
        }
    }

    SendBatchToLLM(promptText) {
        checkedItems := this.controller.contextViewController.GetAllCheckedContextItems()
        if (checkedItems.Length == 0) {
            this.view.ShowMessage("Please check at least one item in the context list for batch mode.", "No Items Selected")
            return
        }

        ; Update UI to show "Cancel"
        if (this.view.guiShown) {
            this.SetProcessingState("processing")
        }

        try {
            this.sendBatchToLLMCommand.Execute(
                promptText, 
                checkedItems, 
                (label, messages) => this.controller.historyViewController.UpdateChatHistoryView(),
                () => (this.processingState == "processing")
            )
        } catch as e {
            if (e.Message != "Request cancelled")
                this.view.ShowError("Batch processing error: " . e.Message)
        } finally {
            this.SetProcessingState("idle")
            this.view.ClearPrompt()
            this.controller.historyViewController.UpdateChatHistoryView()
        }
    }

    SendToLLM(promptText := "", isRegeneration := false) {
        ; 1. Collect GUI state (images and selection)
        isImageEnabled := this.controller.IsImageInputEnabled[this.controller.CurrentLLMTypeIndex]
        images := isImageEnabled ? this.controller.contextViewController.GetCheckedImages() : []
        
        selectedIndices := []
        if (selectedIndex := this.view.GetContextBoxValue()) {
            selectedIndices.Push(selectedIndex)
        }

        ; 2. Update UI State before execution
        if (this.view.guiShown) {
            this.SetProcessingState("processing")
        }

        try {
            ; 3. Execute Command with collected UI data
            result := this.sendToLLMCommand.Execute(
                promptText, 
                images, 
                selectedIndices,
                isRegeneration
            )
            
            ; 4. Check for unexecuted Tool Calls to update button text
            if (result.hasUnexecutedToolCalls) {
                this.SetProcessingState("tool_pending")
            } else {
                this.SetProcessingState("idle")
            }
        } catch as e {
            if (e.Message != "Request cancelled") {
                this.SetProcessingState("idle")
                throw e
            }
            this.SetProcessingState("idle")
        }

        ; 5. Refresh UI components
        this.controller.historyViewController.UpdateChatHistoryView()
        this.renderLastMessageCommand.Execute()

        ; 6. UI-specific cleanup
        this.controller.contextViewController.UncheckSentImages()
    }
}
