class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 5
    sessionNames := ["Session 1", "Session 2", "Session 3", "Session 4", "Session 5"]
    sessionMessages := []
    sessionContexts := []
    sessionLLMTypes := []
    sessionSystemPrompts := []

    __New(appSettings) {
        this.appSettings := appSettings

        ; Initialize session arrays
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([{
                role: "system",
                content: this.appSettings.GetSystemPromptValue(this.appSettings.selectedLLMTypeIndex, 1)
            }])
            this.sessionContexts.Push([])
            this.sessionLLMTypes.Push(this.appSettings.selectedLLMTypeIndex)
            this.sessionSystemPrompts.Push(1)
        }
    }

    GetMessageAsString(message) {
        if (message.HasOwnProp("content") && message.content) {
            return message.content
        }
        if (message.HasOwnProp("tool_calls") && message.tool_calls.Length > 0) {
            toolCall := message.tool_calls[1]  ; Get only first tool call
            return toolCall.function.name "(" toolCall.function.arguments ")"
        }
        return ""
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

    ResetCurrentSession() {
        this.ClearCurrentMessages()
        this.ClearCurrentContext()
    }

    ClearCurrentMessages() {
        this.sessionMessages[this.currentSessionIndex] := [{
            role: "system",
            content: this.appSettings.GetSystemPromptValue(this.GetCurrentSessionLLMType(), this.GetCurrentSessionSystemPrompt())
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
