#Requires AutoHotkey 2.0

class ChatController {
    controller := ""
    view := ""
    
    ; Commands
    submitPromptCommand := ""
    renderMarkdownCommand := ""
    renderLastMessageCommand := ""
    uncheckImagesCommand := ""

    sessionManager := ""
    batchModeEnabled := false
    processingState := "idle" ; idle, processing, tool_pending

    __New(controller, view, sessionManager, submitPromptCommand, renderMarkdownCommand, renderLastMessageCommand, uncheckImagesCommand) {
        this.controller := controller
        this.view := view
        this.sessionManager := sessionManager
        
        this.submitPromptCommand := submitPromptCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.renderLastMessageCommand := renderLastMessageCommand
        this.uncheckImagesCommand := uncheckImagesCommand
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state
        this.batchModeEnabled := !this.batchModeEnabled
        
        ; Update menu checkmark
        this.view.UpdateBatchModeMenu(this.batchModeEnabled)
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

    AskToLLM(*) {
        ; 1. Gather UI state
        currentState := this.processingState
        promptText := this.view.GetPromptValue()
        focusedRow := this.view.GetSelectedHistoryIndex()
        isBatchMode := this.batchModeEnabled
        
        isImageEnabled := this.controller.IsImageInputEnabled[this.controller.CurrentLLMTypeIndex]
        images := isImageEnabled ? this.sessionManager.GetCheckedImages() : []

        selectedIndices := []
        if (selectedIndex := this.view.GetContextBoxValue()) {
            selectedIndices.Push(selectedIndex)
        }

        batchItems := isBatchMode ? this.sessionManager.GetCheckedContextItems() : []
        
        if (isBatchMode && batchItems.Length == 0) {
            this.view.ShowMessage("Please check at least one item in the context list for batch mode.", "No Items Selected")
            return
        }

        ; 2. Update UI state before execution
        if (this.view.guiShown && this.processingState == "idle") {
            this.SetProcessingState("processing")
        }

        try {
            ; 3. Execute Command with collected UI data
            result := this.submitPromptCommand.Execute({
                promptText: promptText,
                processingState: currentState,
                focusedRow: focusedRow,
                selectedContextIndices: selectedIndices,
                images: images,
                isBatchMode: isBatchMode,
                batchItems: batchItems,
                batchUpdateCallback: (label, messages) => this.controller.historyViewController.UpdateChatHistoryView(),
                isCancelledCallback: () => (this.processingState == "processing")
            })

            ; 4. Handle Result and update UI State
            if (result.action == "load_to_prompt") {
                this.view.SetPromptValue(result.text)
                this.SetProcessingState("idle")
                return
            }

            if (result.action == "idle") {
                this.SetProcessingState("idle")
            } else if (result.action == "tool_pending") {
                this.SetProcessingState("tool_pending")
            }

            ; 5. UI Cleanup
            if (result.action != "none") {
                this.view.ClearPrompt()
                if (focusedRow > 0) {
                    this.view.DeselectHistoryItem(focusedRow)
                }
                
                if (this.controller.recordingService.isRecording) {
                    this.controller.stopRecordingCommand.Execute()
                    this.controller.UpdateUiBasesOnRecordingStatus()
                }
            }
        } catch as e {
            this.SetProcessingState("idle")
            if (e.Message != "Request cancelled") {
                this.view.ShowError("Error: " . e.Message)
            }
        } finally {
            ; 6. Refresh UI components
            this.controller.historyViewController.UpdateChatHistoryView()
            this.renderLastMessageCommand.Execute()

            if (this.uncheckImagesCommand.Execute()) {
                this.controller.contextViewController.UpdateContextView()
            }
        }
    }

    OnPromptInput() {
        if (GetKeyState("Enter") && !GetKeyState("Shift")) {
            ; Get the current text
            text := this.view.GetPromptValue()
            if (SubStr(text, -1) == "`n") {
                ; Remove the trailing newline
                this.view.SetPromptValue(SubStr(text, 1, -1))
                ; Send the prompt
                this.AskToLLM()
            }
        }
    }

    AppendToPrompt(text) {
        currentText := this.view.GetPromptValue()
        if (currentText != "") {
            currentText .= "`n"
        }
        this.view.SetPromptValue(currentText . "> " . text . "`n")
    }
}
