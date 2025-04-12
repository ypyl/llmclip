class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 3
    sessionNames := ["Session 1", "Session 2", "Session 3"]
    sessionMessages := []
    sessionContexts := []

    __New(appSettings) {
        this.appSettings := appSettings

        ; Initialize session arrays
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([{
                role: "system",
                content: this.appSettings.GetSystemPromptValue()
            }])
            this.sessionContexts.Push([])
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
            messages.Push({ role: message.role, content: this.GetMessageAsString(message) } )
        }
        return messages
    }

    GetCurrentSessionContext() {
        return this.sessionContexts[this.currentSessionIndex]
    }

    SetCurrentSessionContext(newContext) {
        this.sessionContexts[this.currentSessionIndex] := newContext
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
            content: this.appSettings.GetSystemPromptValue()
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
