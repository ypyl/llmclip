#Requires AutoHotkey 2.0

class ChatManager {
    controller := ""
    appSettings := ""
    sessionManager := ""
    llmService := ""
    contextManager := ""

    __New(controller, appSettings, sessionManager, llmService, contextManager) {
        this.controller := controller
        this.appSettings := appSettings
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.contextManager := contextManager
    }

    ToggleBatchMode(*) {
        ; Toggle batch mode state
        this.controller.batchModeEnabled := !this.controller.batchModeEnabled
        
        ; Update menu checkmark
        if (this.controller.batchModeEnabled) {
            this.controller.ModeMenu.Check("Batch Mode")
        } else {
            this.controller.ModeMenu.Uncheck("Batch Mode")
        }
    }

    HandleToolConfirmation() {
        messages := this.sessionManager.GetCurrentSessionMessages()

        ; Find and execute all unexecuted tool calls
        executedAny := false
        for msg in messages {
            if (this.sessionManager.HasToolCalls(msg)) {
                toolResults := this.llmService.ExecuteToolCalls(this.sessionManager, msg)
                if (toolResults.Length > 0) {
                    for res in toolResults {
                        messages.Push(res)
                    }
                    executedAny := true
                }
            }
        }

        if (executedAny) {
            this.SendToLLM()
        } else {
            ; Should not happen if button is Confirm Tool Run, but reset just in case
            this.controller.MyGui["AskLLM"].Text := "Ask LLM"
        }
    }

    HandleCancellation() {
        if (this.llmService) {
            this.llmService.Cancel()
        }
        if (this.controller.MyGui) {
            this.controller.MyGui["AskLLM"].Text := "Ask LLM"
        }
    }

    HandleRegenerationOrEdit(promptText) {
        messages := this.sessionManager.GetCurrentSessionMessages()
        chatHistory := this.controller.MyGui["ChatHistory"]
        focused_row := chatHistory.GetNext()

        if (focused_row > 0) {
            selectedMsg := messages[focused_row]

            if (selectedMsg.Role == "user") {
                if (promptText == "") {
                    ; Regeneration case: Load message content into prompt for editing
                    this.controller.MyGui["PromptEdit"].Value := this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg)
                    return true
                } else {
                    ; Edit Mode: Build new message with text and images
                    isImageEnabled := this.appSettings.IsImageInputEnabled(this.sessionManager.GetCurrentSessionLLMType())
                    images := isImageEnabled ? this.controller.ContextViewControllerValue.GetCheckedImages() : []
                    newContent := this.sessionManager.BuildUserMessage(promptText, images)

                    ; Check if this is the first user message with context
                    messages := this.sessionManager.GetCurrentSessionMessages()
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
                        ; Keep the context (first TextContent) and add new content after it
                        contextText := selectedMsg.Contents[1]
                        newContentWithContext := [contextText]
                        for part in newContent {
                            newContentWithContext.Push(part)
                        }
                        selectedMsg.Contents := newContentWithContext
                    } else {
                        ; Replace the message contents normally
                        selectedMsg.Contents := newContent
                    }

                    ; Truncate history after this message
                    if (this.sessionManager.TruncateMessages(focused_row)) {
                        this.SendToLLM()
                        this.controller.MyGui["PromptEdit"].Value := ""
                        ; Clear selection to exit "Edit Mode"
                        chatHistory.Modify(focused_row, "-Select")
                        return true
                    }
                }
            }
        }
        return false
    }

    AskToLLM(*) {
        ; Check if we are in "Confirm Tool Run" mode (Agent Mode tool execution)
        if (this.controller.MyGui["AskLLM"].Text == "Confirm Tool Run") {
            this.HandleToolConfirmation()
            return
        }

        if (this.controller.MyGui["AskLLM"].Text == "Cancel") {
            this.HandleCancellation()
            return
        }

        promptText := this.controller.MyGui["PromptEdit"].Value

        ; Check for regeneration or edit case
        if (this.HandleRegenerationOrEdit(promptText)) {
            return
        }

        ; Check for Batch Mode
        if (this.controller.batchModeEnabled) {
            this.SendBatchToLLM(promptText)
            return
        }

        messages := this.sessionManager.GetCurrentSessionMessages()
        userMessageContent := ""
        if (promptText != "") {
            userMessageContent := promptText
        }

        isImageEnabled := this.appSettings.IsImageInputEnabled(this.sessionManager.GetCurrentSessionLLMType())

        images := isImageEnabled ? this.controller.ContextViewControllerValue.GetCheckedImages() : []
        userMessageContent := this.sessionManager.BuildUserMessage(userMessageContent, images)

        ; Allow empty user message if there's context to attach
        hasContext := this.controller.ContextViewControllerValue.HasAnyCheckedItem()
        if (userMessageContent.Length > 0 || hasContext) {
            messages.Push(ChatMessage("user", userMessageContent))
        }
        this.SendToLLM()
        this.controller.MyGui["PromptEdit"].Value := ""  ; Clear prompt field

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

        ; Create and mark the user message
        userContent := [TextContent(promptText)]
        userMsg := ChatMessage("user", userContent)
        userMsg.AdditionalProperties["isBatchMode"] := true
        
        ; Add to main history once
        messages := this.sessionManager.GetCurrentSessionMessages()
        messages.Push(userMsg)

        ; Update UI to show "Cancel"
        if (this.controller.MyGui) {
            this.controller.askButton.Text := "Cancel"
        }

        try {
            ; Get common settings
            currentLLM := this.sessionManager.GetCurrentSessionLLMType()
            powerShellEnabled := this.appSettings.IsToolEnabled(currentLLM, "powerShellTool")
            fileSystemEnabled := this.appSettings.IsToolEnabled(currentLLM, "fileSystemTool")
            webSearchEnabled := this.appSettings.IsToolEnabled(currentLLM, "webSearch")
            webFetchEnabled := this.appSettings.IsToolEnabled(currentLLM, "webFetch")

            ; Prepare base history (filtered but WITHOUT the current trigger message)
            baseHistory := this.sessionManager.GetMessagesExcludingBatch()

            ; Process each item
            for item in checkedItems {
                ; Deep clone the base history and the trigger message
                clonedMessages := []
                for msg in baseHistory {
                    clonedMessages.Push(msg.Clone())
                }
                
                ; Add a clone of the current prompt message to the history for THIS request
                activePromptClone := userMsg.Clone()
                clonedMessages.Push(activePromptClone)
                
                ; Add context specifically for THIS item to the first user message in clone
                itemLabel := this.contextManager.GetLabelFromContextItem(item)
                itemText := this.controller.ContextViewControllerValue.GetTextFromContextItem(item)
                
                ; Find first user message in clone to attach context
                firstUserMsg := ""
                for msg in clonedMessages {
                    if (msg.Role == "user") {
                        firstUserMsg := msg
                        break
                    }
                }
                
                if (firstUserMsg) {
                    ; Attach context as first element of Contents
                    firstUserMsg.Contents.InsertAt(1, TextContent("Context for this request: [" . itemLabel . "]`n" . itemText))
                    firstUserMsg.AdditionalProperties["hasContext"] := true
                }

                ; Create a temporary session manager for LLMService (hacky but works for SendToLLM)
                tempSessionManager := {
                    GetCurrentSessionMessages: (*) => clonedMessages,
                    GetCurrentSessionLLMType: (*) => this.sessionManager.GetCurrentSessionLLMType(),
                    GetMessagesExcludingBatch: (*) => clonedMessages,
                    HasUnexecutedToolCalls: (*) => false
                }

                ; Send single request
                newMessages := this.llmService.SendToLLM(tempSessionManager, this.controller.currentAnswerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled)

                ; Mark responses and add to main history
                for respMsg in newMessages {
                    respMsg.AdditionalProperties["isBatchResponse"] := true
                    respMsg.AdditionalProperties["batchContextItem"] := itemLabel
                    messages.Push(respMsg)
                }

                ; Update History View as we go
                this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
                
                ; Check for cancellation (simplified)
                if (this.controller.askButton.Text != "Cancel")
                    break
            }
        } catch as e {
            if (e.Message != "Request cancelled")
                MsgBox("Batch processing error: " . e.Message, "Error", "Iconx")
        } finally {
            if (this.controller.MyGui) {
                this.controller.askButton.Text := "Ask LLM"
                this.controller.askButton.Enabled := true
            }
            this.controller.MyGui["PromptEdit"].Value := ""
            this.controller.HistoryViewControllerValue.UpdateChatHistoryView()
        }
    }

    SendToLLM() {
        messages := this.sessionManager.GetCurrentSessionMessages()

        ; Update the system prompt content
        systemPrompt := this.appSettings.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        context := this.sessionManager.GetCurrentSessionContext()
        contextBox := this.controller.MyGui["ContextBox"]

        ; Build context message content
        additionalContext := this.controller.ContextViewControllerValue.BuildAdditionalContextMessage(context, contextBox.Value)

        ; Find first user message
        firstUserMsg := ""
        for i, msg in messages {
            if (msg.Role == "user") {
                firstUserMsg := msg
                break
            }
        }

        if (firstUserMsg) {
            ; Check if message has existing context
            if (firstUserMsg.AdditionalProperties.Has("hasContext") && firstUserMsg.AdditionalProperties["hasContext"]) {
                if (additionalContext != "") {
                    ; Update existing context (first item in Contents)
                    if (firstUserMsg.Contents.Length > 0 && (firstUserMsg.Contents[1] is TextContent)) {
                        firstUserMsg.Contents[1].Text := additionalContext
                    }
                } else {
                    ; Remove existing context
                    firstUserMsg.Contents.RemoveAt(1)
                    firstUserMsg.AdditionalProperties["hasContext"] := false
                }
            } else {
                ; No existing context
                if (additionalContext != "") {
                    ; Insert new context at the beginning
                    firstUserMsg.Contents.InsertAt(1, TextContent(additionalContext))
                    firstUserMsg.AdditionalProperties["hasContext"] := true
                }
            }
        }

        ; Disable Ask LLM button while processing
        if (this.controller.MyGui) {
            this.controller.askButton.Text := "Cancel"
        }

        try {
            ; Check tool enabled
            currentLLM := this.sessionManager.GetCurrentSessionLLMType()
            powerShellEnabled := this.appSettings.IsToolEnabled(currentLLM, "powerShellTool")
            fileSystemEnabled := this.appSettings.IsToolEnabled(currentLLM, "fileSystemTool")
            webSearchEnabled := this.appSettings.IsToolEnabled(currentLLM, "webSearch")
            webFetchEnabled := this.appSettings.IsToolEnabled(currentLLM, "webFetch")

            newMessages := this.llmService.SendToLLM(this.sessionManager, this.controller.currentAnswerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled)

            ; Check for unexecuted Tool Calls
            if (this.sessionManager.HasUnexecutedToolCalls()) {
                this.controller.MyGui["AskLLM"].Text := "Confirm Tool Run"
            } else {
                this.controller.MyGui["AskLLM"].Text := "Ask LLM"
            }

        } catch as e {
            if (e.Message == "Request cancelled") {
                ; Do nothing on cancellation
            } else {
                throw e
            }
        } finally {
            ; Re-enable Ask LLM button
            if (this.controller.MyGui) {
                if (this.controller.MyGui["AskLLM"].Text == "Cancel") {
                    this.controller.MyGui["AskLLM"].Text := "Ask LLM"
                }
                this.controller.askButton.Enabled := true
            }
        }
        this.controller.HistoryViewControllerValue.UpdateChatHistoryView()  ; Update the chat history view

        if (messages.Length > 0) {
            this.controller.RenderMarkdown(this.sessionManager.GetMessageAsString(messages[messages.Length]))
        }

        ; Uncheck images after sending
        this.controller.ContextViewControllerValue.UncheckSentImages()
    }
}
