#Requires AutoHotkey 2.0
#Include LLMClient.ahk
#Include PowerShellTool.ahk
#Include SessionManager.ahk

class LLMService {
    appSettings := ""
    llmClientInstance := ""

    __New(appSettings) {
        this.appSettings := appSettings
    }

    ConfigureToolSettings(powerShellEnabled) {
        enabledTools := []
        if (powerShellEnabled)
            enabledTools.Push("powerShellTool")
        return enabledTools
    }

    ExecuteToolCalls(sessionManager, msg) {
        tool_calls := sessionManager.GetToolCalls(msg)
        results := []

        for tool_call in tool_calls {
            if (!sessionManager.IsToolCallExecuted(tool_call.id)) {
                ; Measure tool execution time
                startTime := A_TickCount
                if result := PowerShellTool.ExecuteToolCall(tool_call) {
                    duration := (A_TickCount - startTime) / 1000
                    result.duration := duration
                    results.Push(result)
                }
            }
        }
        return results
    }

    SendToLLM(sessionManager, answerSize, powerShellEnabled) {
        messages := sessionManager.GetCurrentSessionMessages()
        
        try {
            ; Create LLM client if it doesn't exist yet
            settings := this.appSettings.GetSelectedSettings(sessionManager.GetCurrentSessionLLMType())

            ; Update tools property based on checkbox values
            settings["tools"] := this.ConfigureToolSettings(powerShellEnabled)
            
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

            ; Simply add the new messages to the session
            for newMessage in newMessages {
                newMessage.AdditionalProperties["duration"] := duration
                messages.Push(newMessage)
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

    CompressHistory(sessionManager) {
        messages := sessionManager.GetCurrentSessionMessages()
        
        ; Check if there are enough messages to compress (at least 3: system + 2 others)
        if (messages.Length < 3) {
            throw Error("Not enough messages to compress. Need at least 2 messages besides the system message.")
        }

        ; Format the conversation history for compression
        conversationText := sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
            throw Error("No conversation history to compress.")
        }

        ; Build compression prompt
        compressionPrompt := this.appSettings.GetCompressionPrompt(sessionManager.GetCurrentSessionLLMType())

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
            settings := this.appSettings.GetSelectedSettings(sessionManager.GetCurrentSessionLLMType())
            settings["tools"] := []  ; No tools for compression

            this.llmClientInstance := LLMClient(settings)

            ; Call LLM with compression prompt
            startTime := A_TickCount
            newMessages := this.llmClientInstance.Call(tempMessages)
            duration := (A_TickCount - startTime) / 1000

            if (newMessages.Length > 0) {
                compressedMsg := newMessages[1]
                compressedMsg.AdditionalProperties["duration"] := duration
                
                ; Replace session messages
                currentSystemMsg := messages[1]
                sessionManager.ClearCurrentMessages()
                sessionManager.sessionMessages[sessionManager.currentSessionIndex].Push(currentSystemMsg)
                sessionManager.sessionMessages[sessionManager.currentSessionIndex].Push(compressedMsg)
                
                return compressedMsg
            }
            return ""

        } catch as e {
            throw e
        }
    }

    ExtractLearnings(sessionManager) {
        messages := sessionManager.GetCurrentSessionMessages()

        ; Check if there are enough messages (at least 2: system + 1 user/assistant)
        if (messages.Length < 2) {
             throw Error("Not enough conversation history to extract notes.")
        }

        ; Format the conversation history
        conversationText := sessionManager.FormatMessagesForCompression()

        if (conversationText == "") {
             throw Error("No conversation history to extract from.")
        }

        ; Get learnings prompt
        learningsPrompt := this.appSettings.GetLearningsPrompt(sessionManager.GetCurrentSessionLLMType())
        learningsPrompt .= "`n`nCONVERSATION:`n" conversationText

        ; Create temporary messages for the extraction request
        tempMessages := [
            messages[1],  ; Keep system message
            ChatMessage("user", [TextContent(learningsPrompt)])
        ]

        try {
            ; Create LLM client
            settings := this.appSettings.GetSelectedSettings(sessionManager.GetCurrentSessionLLMType())
            settings["tools"] := []  ; No tools for extraction

            this.llmClientInstance := LLMClient(settings)

            ; Call LLM
            newMessages := this.llmClientInstance.Call(tempMessages)

            if (newMessages.Length > 0) {
                return sessionManager.GetMessageAsString(newMessages[1])
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
}
