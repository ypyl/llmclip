
#Include LLMClient.ahk
#Include PowerShellTool.ahk
#Include FileSystemTool.ahk
#Include WebSearchTool.ahk
#Include WebFetchTool.ahk
#Include MarkdownNewTool.ahk
#Include ..\SessionManager.ahk

class LLMService {
    configManager := ""
    llmClientInstance := ""
    isCancelledForTools := false
    currentTool := ""  ; Track currently executing tool instance for cancellation

    __New(configManager) {
        this.configManager := configManager
    }

    ConfigureToolSettings(powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled := false) {
        enabledTools := []
        if (powerShellEnabled)
            enabledTools.Push(PowerShellTool.TOOL_NAME)

        if (fileSystemEnabled)
             enabledTools.Push(FileSystemTool.TOOL_NAME)

        ; Enable web search if API key is present
        if (webSearchEnabled && this.configManager.ollamaApiKey != "") {
            enabledTools.Push(WebSearchTool.TOOL_NAME)
        }
        ; Enable web fetch unconditionally if enabled
        if (webFetchEnabled) {
            enabledTools.Push(WebFetchTool.TOOL_NAME)
        }
        ; Enable markdown new if enabled
        if (markdownNewEnabled) {
            enabledTools.Push(MarkdownNewTool.TOOL_NAME)
        }

        return enabledTools
    }

    ExecuteToolCalls(sessionManager, msg, sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := sessionManager.currentSessionIndex

        tool_calls := sessionManager.GetToolCalls(msg)
        results := []

        for tool_call in tool_calls {
            ; Check if cancellation was requested
            if (this.isCancelledForTools) {
                break
            }

            if (!sessionManager.IsToolCallExecutedInSession(sessionIndex, tool_call.id)) {
                ; Measure tool execution time
                startTime := A_TickCount
                result := ""

                if (tool_call.Name ==  PowerShellTool.TOOL_NAME) {
                     tool := PowerShellTool()
                     this.currentTool := tool
                     result := tool.ExecuteToolCall(tool_call)
                } else if (tool_call.Name == FileSystemTool.TOOL_NAME) {
                     tool := FileSystemTool()
                     this.currentTool := tool
                     result := tool.ExecuteToolCall(tool_call)
                } else if (tool_call.Name == WebSearchTool.TOOL_NAME) {
                     tool := WebSearchTool()
                     this.currentTool := tool
                     result := tool.ExecuteToolCall(tool_call, this.configManager.ollamaApiKey)
                } else if (tool_call.Name == WebFetchTool.TOOL_NAME) {
                     tool := WebFetchTool()
                     this.currentTool := tool
                     result := tool.ExecuteToolCall(tool_call, this.configManager.ollamaApiKey)
                } else if (tool_call.Name == MarkdownNewTool.TOOL_NAME) {
                     tool := MarkdownNewTool()
                     this.currentTool := tool
                     result := tool.ExecuteToolCall(tool_call)
                }

                this.currentTool := ""  ; Clear current tool reference

                if (result) {
                    duration := (A_TickCount - startTime) / 1000
                    result.AdditionalProperties["duration"] := duration
                    results.Push(result)
                }
            }
        }

        ; Clear cancellation flag after execution completes (success or cancellation)
        this.isCancelledForTools := false
        return results
    }

    SendToLLM(sessionManager, answerSize, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled := false, sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := sessionManager.currentSessionIndex

        ; Use filtered messages to exclude previous batch processing
        messages := sessionManager.GetMessagesExcludingBatchForSession(sessionIndex)

        ; Append Date and Time to the system message
        if (messages.Length > 0 && messages[1].Role == "system") {
            systemMsg := messages[1]
            originalText := systemMsg.GetText()
            currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            systemMsg.Contents := [TextContent(originalText . "`n`nCurrent Date and Time: " . currentTime)]
        }

        try {
            ; Create LLM client if it doesn't exist yet
            settings := this.configManager.GetSelectedSettings(sessionManager.GetSessionLLMType(sessionIndex))

            ; Update tools property based on checkbox values
            settings["tools"] := this.ConfigureToolSettings(powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled)

            ; Add a user message to instruct the model on answer length based on menu selection
            answerSizeMsg := ""
            if (answerSize = "Small") {
                answerSizeMsg := "Please answer as concisely as possible (short answer)."
            } else if (answerSize = "Long") {
                answerSizeMsg := "Please provide a long, detailed answer."
            }
            ; If currentAnswerSize = "Default", no message is added (default behavior)
            if (answerSizeMsg != "") {
                messages.Push(ChatMessage("user", [TextContent(answerSizeMsg)]))
            }

            this.llmClientInstance := LLMClient(settings)

            ; The LLM client now returns fully-formed messages
            startTime := A_TickCount
            newMessages := this.llmClientInstance.Call(messages)
            duration := (A_TickCount - startTime) / 1000

            ; Remove the answer size instruction message after receiving the answer
            if (answerSizeMsg != "") {
                messages.RemoveAt(messages.Length)
            }

            ; Attach metadata to new messages
            for newMessage in newMessages {
                newMessage.AdditionalProperties["duration"] := duration
            }

            return newMessages

        } catch as e {
            if (e.Message == "Request cancelled") {
                ; Do nothing on cancellation
                return []
            } else {
                throw e
            }
        }
    }

    CompressHistory(sessionManager, sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := sessionManager.currentSessionIndex

        messages := sessionManager.GetSessionMessages(sessionIndex)

        ; Check if there are enough messages to compress (at least 3: system + 2 others)
        if (messages.Length < 3) {
            throw Error("Not enough messages to compress. Need at least 2 messages besides the system message.")
        }

        ; Format the conversation history for compression
        conversationText := sessionManager.FormatMessagesForCompressionForSession(sessionIndex)

        if (conversationText == "") {
            throw Error("No conversation history to compress.")
        }

        ; Build compression prompt
        compressionPrompt := this.configManager.GetCompressionPrompt(sessionManager.GetSessionLLMType(sessionIndex))

        if (compressionPrompt == "") {
            throw Error("Compression prompt not configured for this provider.")
        }

        compressionPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Create a temporary message array with just system message and compression request
        tempMessages := [
            messages[1],  ; Keep system message
            ChatMessage("user", [TextContent(compressionPrompt)])
        ]

        try {
            ; Create LLM client
            settings := this.configManager.GetSelectedSettings(sessionManager.GetSessionLLMType(sessionIndex))
            settings["tools"] := []  ; No tools for compression

            this.llmClientInstance := LLMClient(settings)

            ; Call LLM with compression prompt
            startTime := A_TickCount
            newMessages := this.llmClientInstance.Call(tempMessages)
            duration := (A_TickCount - startTime) / 1000

            if (newMessages.Length > 0) {
                compressedMsg := newMessages[1]
                compressedMsg.AdditionalProperties["duration"] := duration

                return compressedMsg
            }
            return ""

        } catch as e {
            throw e
        }
    }

    ExtractLearnings(sessionManager, sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := sessionManager.currentSessionIndex

        messages := sessionManager.GetSessionMessages(sessionIndex)

        ; Check if there are enough messages (at least 2: system + 1 user/assistant)
        if (messages.Length < 2) {
             throw Error("Not enough conversation history to extract notes.")
        }

        ; Format the conversation history
        conversationText := sessionManager.FormatMessagesForCompressionForSession(sessionIndex)

        if (conversationText == "") {
             throw Error("No conversation history to extract from.")
        }

        ; Get learnings prompt
        learningsPrompt := this.configManager.GetLearningsPrompt(sessionManager.GetSessionLLMType(sessionIndex))
        learningsPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Create temporary messages for the extraction request
        tempMessages := [
            messages[1],  ; Keep system message
            ChatMessage("user", [TextContent(learningsPrompt)])
        ]

        try {
            ; Create LLM client
            settings := this.configManager.GetSelectedSettings(sessionManager.GetSessionLLMType(sessionIndex))
            settings["tools"] := []  ; No tools for extraction

            this.llmClientInstance := LLMClient(settings)

            ; Call LLM
            newMessages := this.llmClientInstance.Call(tempMessages)

            if (newMessages.Length > 0) {
                return newMessages[1]
            }
            return ""

        } catch as e {
            throw e
        }
    }

    Cancel() {
        if (this.llmClientInstance) {
            this.llmClientInstance.Cancel()
        }
    }

    CancelTools() {
        this.isCancelledForTools := true
        if (this.currentTool != "") {
            this.currentTool.Cancel()
        }
    }

    ResetToolsCancellation() {
        this.isCancelledForTools := false
    }
}
