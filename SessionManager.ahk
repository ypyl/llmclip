#Include Base64.ahk

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
            audioBase64 := this.GetAudioFileAsBase64(message.audio.link)
            return '<audio controls><source src="data:audio/wav;base64,' audioBase64 '" type="audio/wav"></audio>'
        }
        if (message.HasOwnProp("content") && message.content) {
            return message.content
        }
        if (message.HasOwnProp("tool_calls") && message.tool_calls.Length > 0) {
            toolCall := message.tool_calls[1]  ; Get only first tool call
            return toolCall.function.name "(" toolCall.function.arguments ")"
        }
        return ""
    }

    GetAudioFileAsBase64(filePath) {
        try {
            if (FileExist(filePath)) {
                fileObj := FileOpen(filePath, "r")
                if (fileObj) {
                    fileSize := fileObj.Length
                    fileBuffer := Buffer(fileSize)
                    fileObj.RawRead(fileBuffer, fileSize)
                    fileObj.Close()

                    return Base64.Encode(fileBuffer)
                }
            }
            return ""
        } catch Error as e {
            return ""
        }
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
            messages.Push({ role: roleEmoji, content: this.GetMessageAsString(message) })
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

    DeleteMessage(index) {
        if (index > 1 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            this.sessionMessages[this.currentSessionIndex].RemoveAt(index)
            return true
        }
        return false
    }
}
