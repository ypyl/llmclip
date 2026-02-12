#Requires AutoHotkey 2.0

/**
 * Command to handle the primary "Ask" action.
 * Consolidates logic for sending, regenerating, tool confirmation, and cancellation.
 * UI-agnostic: receives state, interacts with services, returns outcome.
 */
class SubmitPromptCommand {
    sessionManager := ""
    configManager := ""
    llmService := ""
    contextManager := ""
    recordingService := ""

    __New(sessionManager, configManager, llmService, contextManager, recordingService) {
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.llmService := llmService
        this.contextManager := contextManager
        this.recordingService := recordingService
    }

    /**
     * Executes the command based on provided parameters.
     * @param params Object containing:
     *   - promptText: string
     *   - processingState: "idle" | "processing" | "tool_pending"
     *   - batchItems: array (optional)
     *   - focusedRow: number (optional)
     *   - selectedContextIndices: array (optional)
     *   - images: array (optional)
     *   - isBatchMode: bool
     *   - batchUpdateCallback: function(label, messages)
     *   - isCancelledCallback: function() -> bool
     * @returns {Object} Outcome for controller:
     *   - action: "idle" | "processing" | "tool_pending" | "load_to_prompt" | "none"
     *   - text: string (if action is load_to_prompt)
     *   - hasUnexecutedToolCalls: bool
     */
    Execute(params) {
        ; 1. Handle Cancellation
        if (params.processingState == "processing") {
            this.llmService.Cancel()
            return { action: "idle" }
        }

        ; 2. Handle Tool Confirmation
        if (params.processingState == "tool_pending") {
            if (this.ExecuteToolCalls()) {
                return this.PerformSend(params, true)
            }
            return { action: "idle" }
        }

        ; 3. Handle Regeneration or Edit
        if (params.focusedRow > 0) {
            regResult := this.HandleRegenerationOrEdit(params.focusedRow, params.promptText, params.images)
            if (regResult.status == "load_to_prompt") {
                return { action: "load_to_prompt", text: regResult.text }
            } else if (regResult.status == "sent") {
                return this.PerformSend(params, true) ; isRegeneration := true
            }
            return { action: "none" }
        }

        ; 4. Handle Batch Mode
        if (params.isBatchMode) {
            this.PerformBatchSend(params)
            return { action: "idle" }
        }

        ; 5. Normal Send Mode
        return this.PerformSend(params)
    }

    PerformSend(params, isRegeneration := false) {
        ; Logic from SendToLLMCommand
        currentContext := this.sessionManager.GetCurrentSessionContext()
        additionalContext := this.contextManager.BuildPromptContext(
            currentContext,
            params.HasOwnProp("selectedContextIndices") ? params.selectedContextIndices : []
        )

        if (!isRegeneration) {
            images := params.HasOwnProp("images") ? params.images : []
            userMessageContent := this.sessionManager.BuildUserMessage(params.promptText, images)

            hasAnyChecked := this.sessionManager.HasAnyCheckedItem()

            if (userMessageContent.Length > 0 || hasAnyChecked) {
                this.sessionManager.GetCurrentSessionMessages().Push(ChatMessage("user", userMessageContent))
            }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()

        ; Update system prompt
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        ; Handle context attachment
        if (messages.Length > 0 && messages[messages.Length].Role == "user") {
            lastUserMsg := messages[messages.Length]
            if (additionalContext != "") {
                lastUserMsg.Contents.InsertAt(1, TextContent(additionalContext))
                lastUserMsg.AdditionalProperties["hasContext"] := true
            }
        }

        ; Tool status
        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")
        answerSize := params.HasOwnProp("answerSize") ? params.answerSize : "Default"

        try {
            newMessages := this.llmService.SendToLLM(
                this.sessionManager,
                answerSize,
                powerShellEnabled,
                webSearchEnabled,
                webFetchEnabled,
                fileSystemEnabled
            )

            hasUnexecuted := this.sessionManager.HasUnexecutedToolCalls()
            return {
                action: hasUnexecuted ? "tool_pending" : "idle",
                hasUnexecutedToolCalls: hasUnexecuted
            }
        } catch as e {
            if (e.Message == "Request cancelled") {
                return { action: "idle" }
            }
            throw e
        }
    }

    PerformBatchSend(params) {
        ; Logic from SendBatchToLLMCommand
        userContent := [TextContent(params.promptText)]
        userMsg := ChatMessage("user", userContent)
        userMsg.AdditionalProperties["isBatchMode"] := true

        mainMessages := this.sessionManager.GetCurrentSessionMessages()
        mainMessages.Push(userMsg)

        currentLLM := this.sessionManager.GetCurrentSessionLLMType()
        powerShellEnabled := this.configManager.IsToolEnabled(currentLLM, "powerShellTool")
        fileSystemEnabled := this.configManager.IsToolEnabled(currentLLM, "fileSystemTool")
        webSearchEnabled := this.configManager.IsToolEnabled(currentLLM, "webSearch")
        webFetchEnabled := this.configManager.IsToolEnabled(currentLLM, "webFetch")

        baseHistory := this.sessionManager.GetMessagesExcludingBatch()

        for item in params.batchItems {
            if (params.isCancelledCallback())
                break

            clonedMessages := []
            for msg in baseHistory {
                clonedMessages.Push(msg.Clone())
            }

            activePromptClone := userMsg.Clone()
            clonedMessages.Push(activePromptClone)

            itemLabel := this.contextManager.GetLabelFromContextItem(item)
            itemText := this.contextManager.GetTextFromContextItem(item)

            firstUserMsg := ""
            for msg in clonedMessages {
                if (msg.Role == "user") {
                    firstUserMsg := msg
                    break
                }
            }

            if (firstUserMsg) {
                firstUserMsg.Contents.InsertAt(1, TextContent("Context for this request: [" . itemLabel . "]`n" . itemText))
                firstUserMsg.AdditionalProperties["hasContext"] := true
            }

            tempSession := {
                GetCurrentSessionMessages: (*) => clonedMessages,
                GetCurrentSessionLLMType: (*) => this.sessionManager.GetCurrentSessionLLMType(),
                GetMessagesExcludingBatch: (*) => clonedMessages,
                HasUnexecutedToolCalls: (*) => false
            }

            answerSize := params.HasOwnProp("answerSize") ? params.answerSize : "Default"
            newMessages := this.llmService.SendToLLM(tempSession, answerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled)

            for respMsg in newMessages {
                respMsg.AdditionalProperties["isBatchResponse"] := true
                respMsg.AdditionalProperties["batchContextItem"] := itemLabel
                mainMessages.Push(respMsg)
            }

            if (params.HasOwnProp("batchUpdateCallback")) {
                params.batchUpdateCallback(itemLabel, newMessages)
            }
        }
    }

    ExecuteToolCalls() {
        ; Logic from ConfirmToolCommand
        messages := this.sessionManager.GetCurrentSessionMessages()
        executedAny := false

        i := 1
        while (i <= messages.Length) {
            msg := messages[i]
            if (this.sessionManager.HasToolCalls(msg)) {
                toolResults := this.llmService.ExecuteToolCalls(this.sessionManager, msg)
                if (toolResults.Length > 0) {
                    for res in toolResults {
                        messages.Push(res)
                    }
                    executedAny := true
                }
            }
            i++
        }
        return executedAny
    }

    HandleRegenerationOrEdit(focusedRow, promptText, images) {
        ; Logic from RegenerateMessageCommand
        if (focusedRow <= 0) {
            return { status: "none" }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()
        selectedMsg := messages[focusedRow]

        if (selectedMsg.Role != "user") {
            return { status: "none" }
        }

        if (promptText == "") {
            return {
                status: "load_to_prompt",
                text: this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg)
            }
        }

        newContent := this.sessionManager.BuildUserMessage(promptText, images)

        isFirstUserMsg := false
        for i, msg in messages {
            if (msg.Role == "user") {
                isFirstUserMsg := (msg == selectedMsg)
                break
            }
        }

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

        if (this.sessionManager.TruncateMessages(focusedRow)) {
            return { status: "sent" }
        }

        return { status: "none" }
    }
}
