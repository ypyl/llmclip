#Include FileUtils.ahk
#Include LLM\Types.ahk

class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 5
    sessionNames := ["Session 1", "Session 2", "Session 3", "Session 4", "Session 5"]
    sessionMessages := []
    sessionContexts := []
    sessionLLMTypes := []
    sessionSystemPrompts := []

    ; Store default values to be used when no settings are provided
    defaultSystemPrompt := "You are a helpful assistant. Be concise and direct in your responses."
    defaultLLMType := 1

    __New(defaultLLMType := 1, defaultSystemPrompt := "") {
        this.defaultLLMType := defaultLLMType
        if (defaultSystemPrompt)
            this.defaultSystemPrompt := defaultSystemPrompt

        ; Initialize session arrays with ChatMessage instances
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([
                ChatMessage("system", this.defaultSystemPrompt)
            ])
            this.sessionContexts.Push([])
            this.sessionLLMTypes.Push(this.defaultLLMType)
            this.sessionSystemPrompts.Push(1)
        }
    }

    GetMessageAsString(message) {
        ; Check for audio content
        audioData := message.GetAudio()
        if (audioData != "") {
            return this.FormatAudioMessage(audioData)
        }
        
        ; Check for tool calls
        for part in message.Contents {
            if (part is FunctionCallContent) {
                return this.FormatToolCallMessage(part)
            }
        }
        
        ; Get text content and check for thinking
        text := message.GetText()
        if (message.AdditionalProperties.Has("thinking") && message.AdditionalProperties["thinking"] != "") {
            text := "``````thinking`n" . message.AdditionalProperties["thinking"] . "`n``````" . "`n`n" . text
        }
        
        ; Check if has images
        hasImage := false
        for part in message.Contents {
            if (part is ImageContent) {
                hasImage := true
                break
            }
        }
        
        return hasImage ? text . " [Image]" : text
    }

    FormatAudioMessage(audioLink) {
        audioBase64 := FileUtils.GetFileAsBase64(audioLink)
        return '<audio controls><source src="data:audio/wav;base64,' audioBase64 '" type="audio/wav"></audio>'
    }



    FormatToolCallMessage(toolCall) {
        return toolCall.Name "(" JSON.Stringify(toolCall.Arguments) ")"
    }

    GetCurrentSessionMessages() {
        return this.sessionMessages[this.currentSessionIndex]
    }

    GetCurrentSessionMessagesAsStrings() {
        messages := []
        for message in this.GetCurrentSessionMessages() {
            roleEmoji := message.Role == "system" ? "⚙️" :
                message.Role == "user" ? "👤" :
                message.Role == "assistant" ? "🤖" :
                message.Role == "tool" ? "🛠️" : message.Role

            result := { role: roleEmoji, content: this.GetMessageAsString(message) }

            ; Add additional properties from ChatMessage
            if (message.AdditionalProperties.Has("duration")) {
                result.duration := message.AdditionalProperties["duration"]
            }
            if (message.AdditionalProperties.Has("tokens")) {
                result.tokens := message.AdditionalProperties["tokens"]
            }
            messages.Push(result)
        }
        return messages
    }

    GetCurrentSessionContext() {
        return this.sessionContexts[this.currentSessionIndex]
    }

    SetCurrentSessionContext(newContext) {
        this.sessionContexts[this.currentSessionIndex] := newContext
    }

    GetCurrentSessionLLMType() {
        return this.sessionLLMTypes[this.currentSessionIndex]
    }

    GetCurrentSessionSystemPrompt() {
        return this.sessionSystemPrompts[this.currentSessionIndex]
    }

    SetCurrentSessionLLMType(index) {
        this.sessionLLMTypes[this.currentSessionIndex] := index
    }

    SetCurrentSessionSystemPrompt(index) {
        this.sessionSystemPrompts[this.currentSessionIndex] := index
    }

    SwitchSession(newIndex) {
        if (newIndex > 0 && newIndex <= this.MAX_SESSIONS) {
            this.currentSessionIndex := newIndex
            return true
        }
        return false
    }

    UpdateSystemPromptContent(systemPromptContent) {
        if (this.sessionMessages[this.currentSessionIndex].Length > 0) {
            firstMsg := this.sessionMessages[this.currentSessionIndex][1]
            if (firstMsg.Role == "system") {
                ; Update the text content
                firstMsg.Contents := [TextContent(systemPromptContent)]
            }
        }
    }

    ResetCurrentSession() {
        this.ClearCurrentMessages()
        this.ClearCurrentContext()
    }

    ClearCurrentMessages() {
        this.sessionMessages[this.currentSessionIndex] := [
            ChatMessage("system", this.defaultSystemPrompt)
        ]
    }

    ClearCurrentContext() {
        this.sessionContexts[this.currentSessionIndex] := []
    }

    HasToolResponse(message) {
        if (!message.HasOwnProp("tool_calls") || message.tool_calls.Length = 0)
            return false

        messages := this.GetCurrentSessionMessages()
        for toolCall in message.tool_calls {
            for msg in messages {
                if (msg.HasOwnProp("role") && msg.role = "tool" &&
                    msg.HasOwnProp("tool_call_id") && msg.tool_call_id = toolCall.id) {
                    return true
                }
            }
        }
        return false
    }

    GetToolCalls(msg) {
        if (msg.HasOwnProp("tool_calls")) {
            return msg.tool_calls
        }

        return []
    }

    HasToolCalls(message) {
        return message.HasOwnProp("tool_calls") && message.tool_calls.Length > 0
    }

    HasUnexecutedToolCalls() {
        messages := this.GetCurrentSessionMessages()
        for msg in messages {
            if (this.HasToolCalls(msg)) {
                for toolCall in msg.tool_calls {
                    if (!this.IsToolCallExecuted(toolCall.id)) {
                        return true
                    }
                }
            }
        }
        return false
    }

    IsToolCallExecuted(toolCallId) {
        messages := this.GetCurrentSessionMessages()
        for m in messages {
            if (m.HasOwnProp("role") && m.role == "tool" && m.HasOwnProp("tool_call_id") && m.tool_call_id == toolCallId) {
                return true
            }
        }
        return false
    }

    TruncateMessages(index) {
        if (index > 0 && index < this.sessionMessages[this.currentSessionIndex].Length) {
            ; Remove all messages after the specified index
            ; We loop from the end down to index + 1
            loopCount := this.sessionMessages[this.currentSessionIndex].Length - index
            Loop loopCount {
                this.sessionMessages[this.currentSessionIndex].Pop()
            }
            return true
        }
        return false
    }

    UpdateMessage(index, newContent) {
        if (index > 0 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            msg := this.sessionMessages[this.currentSessionIndex][index]
            msg.Contents := [TextContent(newContent)]
            return true
        }
        return false
    }

    GetMessageText(message) {
        return message.GetText()
    }

    DeleteMessage(index) {
        if (index > 1 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            this.sessionMessages[this.currentSessionIndex].RemoveAt(index)
            return true
        }
        return false
    }

    ExportSessionState() {
        ; Convert ChatMessage instances to plain objects for JSON serialization
        messages := []
        for msg in this.sessionMessages[this.currentSessionIndex] {
            messages.Push(msg.ToObject())
        }

        return {
            messages: messages,
            context: this.sessionContexts[this.currentSessionIndex],
            llmType: this.sessionLLMTypes[this.currentSessionIndex],
            systemPrompt: this.sessionSystemPrompts[this.currentSessionIndex]
        }
    }

    ; Helper method to convert Map objects (from JSON parser) to regular objects
    ConvertMapToObject(value) {
        if (Type(value) = "Map") {
            obj := {}
            for key, val in value {
                obj.%key% := this.ConvertMapToObject(val)
            }
            return obj
        } else if (Type(value) = "Array") {
            arr := []
            for item in value {
                arr.Push(this.ConvertMapToObject(item))
            }
            return arr
        } else {
            return value
        }
    }

    ImportSessionState(state) {
        ; Check if state is a Map (from JSON parser) or an Object
        isMap := Type(state) = "Map"

        ; Validate required properties exist
        hasMessages := isMap ? state.Has("messages") : state.HasOwnProp("messages")
        hasContext := isMap ? state.Has("context") : state.HasOwnProp("context")
        hasLLMType := isMap ? state.Has("llmType") : state.HasOwnProp("llmType")
        hasSystemPrompt := isMap ? state.Has("systemPrompt") : state.HasOwnProp("systemPrompt")

        if (!hasMessages || !hasContext || !hasLLMType || !hasSystemPrompt) {
            throw Error("Invalid session state file")
        }

        ; Get values and convert Maps to Objects if needed
        messages := isMap ? state["messages"] : state.messages
        context := isMap ? state["context"] : state.context
        llmType := isMap ? state["llmType"] : state.llmType
        systemPrompt := isMap ? state["systemPrompt"] : state.systemPrompt

        ; Convert messages to ChatMessage instances
        chatMessages := []
        for msg in messages {
            plainObj := this.ConvertMapToObject(msg)
            chatMessages.Push(ChatMessage.FromObject(plainObj))
        }

        this.sessionMessages[this.currentSessionIndex] := chatMessages
        this.sessionContexts[this.currentSessionIndex] := this.ConvertMapToObject(context)
        this.sessionLLMTypes[this.currentSessionIndex] := llmType
        this.sessionSystemPrompts[this.currentSessionIndex] := systemPrompt

        return true
    }
}
