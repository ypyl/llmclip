#Include FileUtils.ahk

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

        ; Initialize session arrays
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([{
                role: "system",
                content: this.defaultSystemPrompt
            }])
            this.sessionContexts.Push([])
            this.sessionLLMTypes.Push(this.defaultLLMType)
            this.sessionSystemPrompts.Push(1)
        }
    }

    GetMessageAsString(message) {
        if (message.HasOwnProp("audio")) {
            return this.FormatAudioMessage(message)
        }
        if (message.HasOwnProp("content") && message.content) {
            if (IsObject(message.content)) {
                return this.FormatMultipartMessage(message.content)
            } else {
                return this.FormatTextMessage(message)
            }
        }
        if (message.HasOwnProp("tool_calls") && message.tool_calls.Length > 0) {
            return this.FormatToolCallMessage(message)
        }
        return ""
    }

    FormatAudioMessage(message) {
        audioBase64 := FileUtils.GetFileAsBase64(message.audio.link)
        return '<audio controls><source src="data:audio/wav;base64,' audioBase64 '" type="audio/wav"></audio>'
    }

    FormatMultipartMessage(content) {
        text_content := ""
        has_image := false
        for part in content {
            if (part.type = "text") {
                text_content .= part.text
            } else if (part.type = "image_url") {
                has_image := true
            }
        }
        if (has_image) {
            return text_content . " [Image]"
        }
        return text_content
    }

    FormatTextMessage(message) {
        result := message.content
        ; Add thinking field if present (for Ollama thinking models)
        if (message.HasOwnProp("thinking") && message.thinking != "") {
            result := "``````thinking`n" . message.thinking . "`n``````" . "`n`n" . result
        }
        return result
    }

    FormatToolCallMessage(message) {
        toolCall := message.tool_calls[1]  ; Get only first tool call
        return toolCall.function.name "(" toolCall.function.arguments ")"
    }

    GetCurrentSessionMessages() {
        return this.sessionMessages[this.currentSessionIndex]
    }

    GetCurrentSessionMessagesAsStrings() {
        messages := []
        for message in this.GetCurrentSessionMessages() {
            roleEmoji := message.role == "system" ? "⚙️" :
                message.role == "user" ? "👤" :
                message.role == "assistant" ? "🤖" :
                message.role == "tool" ? "🛠️" : message.role

            obj := { role: roleEmoji, content: this.GetMessageAsString(message) }
            if (message.HasOwnProp("duration")) {
                obj.duration := message.duration
            }
            if (message.HasOwnProp("tokens")) {
                obj.tokens := message.tokens
            }
            messages.Push(obj)
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
        if (this.sessionMessages[this.currentSessionIndex].Length > 0 &&
            this.sessionMessages[this.currentSessionIndex][1].role == "system") {
            this.sessionMessages[this.currentSessionIndex][1].content := systemPromptContent
        }
    }

    ResetCurrentSession() {
        this.ClearCurrentMessages()
        this.ClearCurrentContext()
    }

    ClearCurrentMessages() {
        this.sessionMessages[this.currentSessionIndex] := [{
            role: "system",
            content: this.defaultSystemPrompt
        }]
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
            this.sessionMessages[this.currentSessionIndex][index].content := newContent
            return true
        }
        return false
    }

    GetMessageText(message) {
        if (message.HasOwnProp("content")) {
            content := message.content
            if (IsObject(content)) {
                text_content := ""
                for part in content {
                    if (part.type = "text") {
                        text_content .= part.text
                    }
                }
                return text_content
            } else {
                return content
            }
        }
        return ""
    }

    DeleteMessage(index) {
        if (index > 1 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            this.sessionMessages[this.currentSessionIndex].RemoveAt(index)
            return true
        }
        return false
    }

    ExportSessionState() {
        return {
            messages: this.sessionMessages[this.currentSessionIndex],
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
        
        ; Convert Maps to Objects for compatibility with rest of codebase
        this.sessionMessages[this.currentSessionIndex] := this.ConvertMapToObject(messages)
        this.sessionContexts[this.currentSessionIndex] := this.ConvertMapToObject(context)
        this.sessionLLMTypes[this.currentSessionIndex] := llmType
        this.sessionSystemPrompts[this.currentSessionIndex] := systemPrompt
        
        return true
    }
}
