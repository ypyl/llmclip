
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
    tools := Map()

    __New(configManager, toolsMap, llmClient) {
        this.configManager := configManager
        this.tools := toolsMap
        this.llmClientInstance := llmClient
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

                if (this.tools.Has(tool_call.Name)) {
                    tool := this.tools[tool_call.Name]
                    this.currentTool := tool
                    
                    if (tool_call.Name == WebSearchTool.TOOL_NAME || tool_call.Name == WebFetchTool.TOOL_NAME) {
                        result := tool.ExecuteToolCall(tool_call, this.configManager.ollamaApiKey)
                    } else {
                        result := tool.ExecuteToolCall(tool_call)
                    }
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

    SendToLLM(messages, modelIndex, powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled := false, promptName := "", sessionIndex := 0) {
        ; Append Date and Time to the system message
        if (messages.Length > 0 && messages[1].Role == "system") {
            systemMsg := messages[1]
            originalText := systemMsg.GetText()
            currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            suffix := "`n`nCurrent Date and Time: " . currentTime
            if (promptName != "") {
                suffix .= "`nCurrent prompt: `"" . promptName . "`""
            }
            systemMsg.Contents := [TextContent(originalText . suffix)]
        }

        try {
            ; Create LLM client if it doesn't exist yet
            settings := this.configManager.GetSelectedSettings(modelIndex)
            settings["tools"] := this.ConfigureToolSettings(powerShellEnabled, webSearchEnabled, webFetchEnabled, fileSystemEnabled, markdownNewEnabled)

            ; Expand tool names to definition objects using toolsMap
            resolvedTools := []
            for t in settings["tools"] {
                if this.tools.Has(t)
                    resolvedTools.Push(this.tools[t].GetOpenAiToolDefinition())
            }
            settings["tools"] := resolvedTools

            ; Thread session index for traceability
            settings["session_index"] := sessionIndex

            ; Use LLM client with settings
            startTime := A_TickCount
            newMessages := this.llmClientInstance.Call(messages, settings)
            duration := (A_TickCount - startTime) / 1000

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
